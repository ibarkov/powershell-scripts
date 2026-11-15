
<#
.SYNOPSIS
    Lists Windows account lockout events (Security Event ID 4740).
.DESCRIPTION
    Reads Event ID 4740 from the local Security event log and reports the
    account that was locked, the recorded caller computer, and the computer
    that logged the event. In standard 4740 XML, the caller computer name
    is recorded in TargetDomainName, not CallerComputerName.

    The locked account's domain is not a separate 4740 XML field. The script
    tries to resolve TargetSid to DOMAIN\username; unresolved domains remain
    empty. This does not require the ActiveDirectory PowerShell module.

    For domain account lockouts, run this script on an appropriate domain
    controller (and check other domain controllers when investigating).
    For local accounts, run it on the computer that owns the local account.

    The script is read-only and does not unlock accounts or change policies.

.PARAMETER Hours
    Number of hours to search (1-8760). Default: 24. Cannot be combined
    explicitly with -All.

.PARAMETER All
    Search all retained Security Event ID 4740 records, without a time limit.

.PARAMETER MaxEvents
    Maximum matching events (1-50000). Default: 500 for time-limited searches.
    With -All, applies only if supplied explicitly.

.PARAMETER User
    Filter by the LOCKED account (TargetUserName), not SubjectUserName.
    Accepts short usernames or DOMAIN\username with case-insensitive wildcards.
    DOMAIN\username matching requires TargetSid account-name resolution.
    Filtering is performed after events have been retrieved.

.PARAMETER NoSummary
    Suppress the caller computer summary in formatted table mode.
    The summary is always suppressed with -PassThru.

.PARAMETER CsvPath
    Export the selected result records to a UTF-8 CSV file.

.PARAMETER PassThru
    Emit structured PowerShell objects instead of a formatted table.

.EXAMPLE
    .\Get-AccountLockoutEvents.ps1
    Lists the most recent 500 account lockouts from the last 24 hours.

.EXAMPLE
    .\Get-AccountLockoutEvents.ps1 -Hours 168 -User 'CONTOSO\jdoe'
    Shows account lockouts for a domain user during the last seven days.

.EXAMPLE
    .\Get-AccountLockoutEvents.ps1 -All -MaxEvents 1000 -CsvPath .\lockouts.csv
    Exports up to 1000 of the most recent retained lockout records.

.EXAMPLE
    .\Get-AccountLockoutEvents.ps1 -PassThru |
        Where-Object CallerComputer -eq 'CLIENT01'
    Filters structured results by the caller computer recorded in Event 4740.

.EXAMPLE
    .\Get-AccountLockoutEvents.ps1 -Hours 168 -NoSummary
    Shows lockout events without the caller computer summary.

.NOTES
    Developed for Windows PowerShell 5.1. Requires permission to read the local
    Security log and Audit User Account Management (Success) for Event ID 4740.
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 8760)]
    [int]$Hours = 24,

    [switch]$All,

    [ValidateRange(1, 50000)]
    [int]$MaxEvents = 500,

    [ValidateNotNullOrEmpty()]
    [string]$User,

    [string]$CsvPath,

    [switch]$PassThru,

    [switch]$NoSummary
)

if ($All -and $PSBoundParameters.ContainsKey('Hours')) {
    throw 'The -All and -Hours parameters cannot be used together.'
}

# -All is unlimited unless -MaxEvents is explicitly specified.
$limitResults = (-not $All) -or $PSBoundParameters.ContainsKey('MaxEvents')
$userFilter = -not [string]::IsNullOrWhiteSpace($User)

if ($All -and -not $limitResults) {
    Write-Warning 'Searching all retained Event ID 4740 records without a count limit. This may take time or use significant memory.'
}

$filter = @{
    LogName = 'Security'
    Id      = 4740
}

if (-not $All) {
    $filter.StartTime = (Get-Date).AddHours(-$Hours)
}

$queryArgs = @{
    FilterHashtable = $filter
    ErrorAction     = 'Stop'
}

# With -User, limit AFTER matching that username, not before it.
if ($limitResults -and -not $userFilter) {
    $queryArgs.MaxEvents = $MaxEvents
}

try {
    $events = @(Get-WinEvent @queryArgs)
}
catch {
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
        Write-Host 'No matching account lockout events (Security Event ID 4740) were found.'
        return
    }

    Write-Error ("Failed to read the local Security event log: {0}" -f $_.Exception.Message)
    return
}

$results = New-Object 'System.Collections.Generic.List[object]'

# Cache SID translations to avoid repeated lookups for the same locked account.
$accountResolutionCache = @{}

# Get-WinEvent returns newest events first unless -Oldest is specified.
foreach ($eventRecord in $events) {
    try {
        [xml]$eventXml = $eventRecord.ToXml()
        $fields = @{}

        foreach ($dataNode in $eventXml.Event.EventData.Data) {
            $fieldName = $dataNode.GetAttribute('Name')

            if (-not [string]::IsNullOrWhiteSpace($fieldName)) {
                $fields[$fieldName] = $dataNode.InnerText
            }
        }
    }
    catch {
        Write-Warning ("Could not parse Security record ID {0}: {1}" -f $eventRecord.RecordId, $_.Exception.Message)
        continue
    }

    $accountName = [string]$fields['TargetUserName']
    $targetSid = [string]$fields['TargetSid']

    # IMPORTANT:
    # Standard Security Event 4740 uses TargetDomainName for the
    # "Caller Computer Name" value.
    # It is NOT the locked account's domain.
    #
    # Some nonstandard event payloads may provide CallerComputerName instead.

    $callerComputer = [string]$fields['TargetDomainName']

    if ($fields.ContainsKey('CallerComputerName') -and
        -not [string]::IsNullOrWhiteSpace([string]$fields['CallerComputerName'])) {
        $callerComputer = [string]$fields['CallerComputerName']
    }

    # Event 4740 does not contain a dedicated domain for the locked user.
    # Try resolving the target SID to DOMAIN\username, if available.

    $accountDomain = ''

    if (-not [string]::IsNullOrWhiteSpace($targetSid)) {
        if (-not $accountResolutionCache.ContainsKey($targetSid)) {
            $resolvedName = ''

            try {
                $sidObject = [System.Security.Principal.SecurityIdentifier]::new($targetSid)

                $resolvedName = $sidObject.Translate(
                    [System.Security.Principal.NTAccount]
                ).Value
            }
            catch {
                # Remote, trust, or local SID resolution might not be available.
            }

            $accountResolutionCache[$targetSid] = $resolvedName
        }

        $resolvedName = [string]$accountResolutionCache[$targetSid]

        if ($resolvedName -match '^([^\\]+)\\(.+)$') {
            $accountDomain = $Matches[1]
        }
    }

    $fullAccount = if ([string]::IsNullOrWhiteSpace($accountDomain)) {
        $accountName
    }
    else {
        '{0}\{1}' -f $accountDomain, $accountName
    }

    # Filter by the account that was locked, not by the subject account.

    if ($userFilter -and
        -not ($accountName -like $User -or $fullAccount -like $User)) {
        continue
    }

    $results.Add([pscustomobject][ordered]@{
        Time            = $eventRecord.TimeCreated
        User            = $accountName
        Domain          = $accountDomain
        CallerComputer  = $callerComputer
        UserSID         = $targetSid
        SubjectUser     = [string]$fields['SubjectUserName']
        SubjectDomain   = [string]$fields['SubjectDomainName']
        SubjectSID      = [string]$fields['SubjectUserSid']
        SubjectLogonId  = [string]$fields['SubjectLogonId']
        Server          = $eventRecord.MachineName
        EventID         = $eventRecord.Id
        LogName         = $eventRecord.LogName
        RecordID        = $eventRecord.RecordId
    })

    if ($limitResults -and $results.Count -ge $MaxEvents) {
        break
    }
}

if ($results.Count -eq 0) {
    Write-Host 'No account lockout events matched the selected filters.'
    return
}

# For lockout investigations, display newest events first.
# Sorting also makes the order deterministic for exports.

$sortedResults = @(
    $results | Sort-Object -Property Time, RecordID -Descending
)

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    try {
        $sortedResults |
            Export-Csv -LiteralPath $CsvPath `
                       -NoTypeInformation `
                       -Encoding UTF8 `
                       -ErrorAction Stop

        Write-Verbose ("Exported {0} event(s) to {1}" -f $sortedResults.Count, $CsvPath)
    }
    catch {
        Write-Error ("CSV export failed: {0}" -f $_.Exception.Message)
        return
    }
}

if ($PassThru) {
    $sortedResults
}
else {
    $sortedResults |
        Format-Table Time, User, Domain, CallerComputer, Server -AutoSize |
        Out-Host

    if (-not $NoSummary) {
        # Count event records in the selected result set, not distinct users,
        # failed passwords, or verified originating devices.

        Write-Host ''

        Write-Host (
            'Lockouts by caller computer ({0} selected event(s)):' -f
            $sortedResults.Count
        )

        $summary = $sortedResults |
            Group-Object -Property CallerComputer |
            Sort-Object -Property Count -Descending |
            ForEach-Object {
                [pscustomobject]@{
                    CallerComputer = if ([string]::IsNullOrWhiteSpace($_.Name)) {
                        '(not recorded)'
                    }
                    else {
                        $_.Name
                    }

                    Count = $_.Count
                }
            }

        $summary |
            Format-Table CallerComputer, Count -AutoSize |
            Out-String -Width 200 |
            Write-Host
    }
}
