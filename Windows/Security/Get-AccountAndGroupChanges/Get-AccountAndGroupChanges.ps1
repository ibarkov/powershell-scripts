<#
.SYNOPSIS
    Audits Windows user account changes and security group membership changes.
.DESCRIPTION
    Reads selected events from the local Security log. Reports accounts that
    were created, enabled, disabled, deleted or modified, and members added
    to or removed from security-enabled local, global or universal groups.

    For group events, TargetUserName identifies the GROUP, while MemberSid
    identifies the member. MemberName can be an LDAP distinguished name or '-'.
    Member SIDs are translated to DOMAIN\account when Windows can resolve them.
    
    If a SID cannot be resolved (e.g., deleted account or no domain connectivity),
    the script falls back to WMI for local accounts.

    Local account/group changes are recorded on the computer that owns them.
    Domain changes are recorded on domain controllers; investigate all relevant
    controllers for domain-wide coverage.
.PARAMETER Hours
    Hours to search (1-8760). Default: 24. Cannot be combined with -All.
.PARAMETER All
    Search all retained matching Security events, without a time limit.
.PARAMETER MaxEvents
    Number of selected events to return (1-50000). Default: 500 for timed
    searches. With -All, applies only when supplied explicitly. When -User
    is present, it is applied after the account/member filter.
.PARAMETER User
    Filter the AFFECTED user or group member, not the account making the change.
    Supports case-insensitive wildcards, short usernames, DOMAIN\username,
    member SID, raw MemberName (including LDAP DN substring matches).
    Note: on high-volume logs, filtering by user may take time as the script
    reads all events in the selected time range.
.PARAMETER CsvPath
    Export the selected records to a UTF-8 CSV file.
.PARAMETER PassThru
    Return PowerShell objects rather than a formatted table and summary.
.PARAMETER NoSummary
    Suppress the summary in formatted table mode.
.EXAMPLE
    .\Get-AccountAndGroupChanges.ps1 -Hours 168
.EXAMPLE
    .\Get-AccountAndGroupChanges.ps1 -User 'CONTOSO\jdoe' -All -MaxEvents 50
.EXAMPLE
    .\Get-AccountAndGroupChanges.ps1 -All -MaxEvents 100 -CsvPath .\changes.csv
.EXAMPLE
    .\Get-AccountAndGroupChanges.ps1 -PassThru | Where-Object TargetGroup -eq 'Administrators'
.NOTES
    Requires Audit User Account Management (Success) and Audit Security
    Group Management (Success). The script is read-only.
	Version:   1.0
    Author:    Igor Barkov
    Copyright: (c) 2026 Igor Barkov
    License:   MIT
    GitHub:    https://github.com/ibarkov/powershell-scripts
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
    throw 'Specify either -All or -Hours, not both.'
}

# User-account management and security-enabled group membership events.
$actions = @{
    4720 = 'UserCreated'
    4722 = 'UserEnabled'
    4725 = 'UserDisabled'
    4726 = 'UserDeleted'
    4738 = 'UserModified'
    4728 = 'MemberAddedGlobal'
    4729 = 'MemberRemovedGlobal'
    4732 = 'MemberAddedLocal'
    4733 = 'MemberRemovedLocal'
    4756 = 'MemberAddedUniversal'
    4757 = 'MemberRemovedUniversal'
}

$groupEventIds = @(4728, 4729, 4732, 4733, 4756, 4757)
$userFilter = -not [string]::IsNullOrWhiteSpace($User)
$limitResults = (-not $All) -or $PSBoundParameters.ContainsKey('MaxEvents')

if ($All -and -not $limitResults) {
    Write-Warning 'Reading all retained matching events without a count limit. This may take time and memory.'
}
if ($userFilter -and $limitResults) {
    Write-Verbose 'Filtering by user, so -MaxEvents will be applied after matching users are found.'
}

$filter = @{
    LogName = 'Security'
    Id      = @($actions.Keys)
}

if (-not $All) {
    $filter.StartTime = (Get-Date).AddHours(-$Hours)
}

$queryArgs = @{
    FilterHashtable = $filter
    ErrorAction     = 'Stop'
}

# Do not limit raw events before applying the -User filter.
if ($limitResults -and -not $userFilter) {
    $queryArgs.MaxEvents = $MaxEvents
}

# Function to resolve SID safely (Domain, then WMI fallback for local accounts).
function Resolve-AccountSid {
    param([string]$Sid)

    if ([string]::IsNullOrWhiteSpace($Sid) -or $Sid -eq '-') {
        return ''
    }

    if (-not $script:sidCache.ContainsKey($Sid)) {
        $resolved = ''
        
        # 1. Try Active Directory / standard translation
        try {
            $sidObject = [System.Security.Principal.SecurityIdentifier]::new($Sid)
            $resolved = $sidObject.Translate([System.Security.Principal.NTAccount]).Value
        }
        catch {
            # 2. Fallback: Try to find a local account via WMI
            try {
                # Note: This requires the CimCmdlets module (available since PS 3.0)
                $wmiUser = Get-CimInstance -ClassName Win32_UserAccount -Filter "SID='$Sid'" -ErrorAction Stop
                if ($wmiUser) {
                    $resolved = "$($wmiUser.Domain)\$($wmiUser.Name)"
                }
            }
            catch {
                # Ignore WMI errors (e.g., SID is a group, not a user, or WMI unavailable)
            }
        }
        
        $script:sidCache[$Sid] = $resolved
    }

    return [string]$script:sidCache[$Sid]
}

$script:sidCache = @{}
$results = New-Object 'System.Collections.Generic.List[object]'

try {
    # Get-WinEvent returns newest events first by default.
    foreach ($eventRecord in (Get-WinEvent @queryArgs)) {
        try {
            [xml]$eventXml = $eventRecord.ToXml()
            $data = @{}

            foreach ($node in $eventXml.Event.EventData.Data) {
                $fieldName = $node.GetAttribute('Name')
                if (-not [string]::IsNullOrWhiteSpace($fieldName)) {
                    $data[$fieldName] = $node.InnerText
                }
            }

            $isGroupEvent = [int]$eventRecord.Id -in $groupEventIds
            $targetName = [string]$data['TargetUserName']
            $targetDomain = [string]$data['TargetDomainName']
            $targetSid = [string]$data['TargetSid']
            $memberNameRaw = [string]$data['MemberName']
            $memberSid = [string]$data['MemberSid']

            $targetGroup = ''
            $groupDomain = ''
            $groupSid = ''
            $member = ''
            $affected = $targetName
            $affectedDomain = $targetDomain
            $affectedSid = $targetSid

            if ($isGroupEvent) {
                # In group events, TargetUserName is the group, NOT the member.
                $targetGroup = $targetName
                $groupDomain = $targetDomain
                $groupSid = $targetSid
                $affectedDomain = ''
                $affectedSid = $memberSid

                $resolved = Resolve-AccountSid -Sid $memberSid
                if ($resolved) {
                    $member = $resolved
                    $separator = $resolved.IndexOf('\')
                    if ($separator -ge 0) {
                        $affectedDomain = $resolved.Substring(0, $separator)
                        $affected = $resolved.Substring($separator + 1)
                    }
                    else {
                        $affected = $resolved
                    }
                }
                elseif ($memberNameRaw -and $memberNameRaw -ne '-') {
                    # Keep the raw DN instead of guessing a SAM account name.
                    $member = $memberNameRaw
                    $affected = $memberNameRaw
                }
                else {
                    $member = $memberSid
                    $affected = $memberSid
                }
            }

            $changedByName = [string]$data['SubjectUserName']
            $changedByDomain = [string]$data['SubjectDomainName']
            $changedBy = if ($changedByDomain) {
                '{0}\{1}' -f $changedByDomain, $changedByName
            }
            else {
                $changedByName
            }

            $fullAffected = if ($affectedDomain) {
                '{0}\{1}' -f $affectedDomain, $affected
            }
            else {
                $affected
            }

            # Enhanced user filtering: short name, full name, raw DN substring, or SID.
            if ($userFilter -and -not (
                $affected -like $User -or
                $fullAffected -like $User -or
                ($memberNameRaw -and $memberNameRaw -like "*$User*") -or
                $affectedSid -like $User
            )) {
                continue
            }

            $results.Add([pscustomobject][ordered]@{
                Time             = $eventRecord.TimeCreated
                Action           = $actions[[int]$eventRecord.Id]
                User             = $affected
                Domain           = $affectedDomain
                UserSID          = $affectedSid
                TargetGroup      = $targetGroup
                GroupDomain      = $groupDomain
                GroupSID         = $groupSid
                Member           = $member
                MemberNameRaw    = $memberNameRaw
                MemberSID        = $memberSid
                ChangedBy        = $changedBy
                ChangedBySID     = [string]$data['SubjectUserSid']
                SubjectLogonId   = [string]$data['SubjectLogonId']
                Server           = $eventRecord.MachineName
                EventID          = [int]$eventRecord.Id
                LogName          = $eventRecord.LogName
                RecordID         = $eventRecord.RecordId
            })

            if ($limitResults -and $results.Count -ge $MaxEvents) {
                break
            }
        }
        catch {
            Write-Warning ('Could not parse Security record {0}: {1}' -f `
                $eventRecord.RecordId, $_.Exception.Message)
        }
    }
}
catch {
    if ($_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*') {
        Write-Host 'No matching account or group changes were found in the Security log.'
        return
    }

    Write-Error ('Unable to read the local Security event log: {0}' -f $_.Exception.Message)
    return
}

if ($results.Count -eq 0) {
    Write-Host 'No account or group changes matched the selected filters.'
    return
}

# Sort descending (newest first) for logical incident review.
$sortedResults = @($results | Sort-Object Time, RecordID -Descending)

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    try {
        $sortedResults | Export-Csv -LiteralPath $CsvPath `
            -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Verbose ('Exported {0} event(s) to {1}' -f $sortedResults.Count, $CsvPath)
    }
    catch {
        Write-Error ('CSV export failed: {0}' -f $_.Exception.Message)
        return
    }
}

if ($PassThru) {
    $sortedResults
}
else {
    $sortedResults |
        Format-Table Time, Action, TargetGroup, User, ChangedBy -AutoSize |
        Out-Host

    if (-not $NoSummary) {
        Write-Host ''
        Write-Host ("Summary: {0} event(s), {1} .. {2}" -f `
            $sortedResults.Count, `
            $sortedResults[-1].Time.ToString('yyyy-MM-dd HH:mm:ss'), `
            $sortedResults[0].Time.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
        
        $sortedResults |
            Group-Object Action |
            Sort-Object Name |
            Select-Object @{Name='Action'; Expression={$_.Name}}, Count |
            Format-Table -AutoSize |
            Out-String -Width 160 |
            Write-Host
    }
}