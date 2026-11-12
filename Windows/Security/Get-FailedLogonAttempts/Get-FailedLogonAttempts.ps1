# Version 1.1 — supports -All (all retained 4625 events).
<#
.SYNOPSIS
    Displays failed Windows logon attempts (Security Event ID 4625).
.DESCRIPTION
    Reads the local Windows Security log, parses event XML by field name,
    and shows who attempted to sign in, from where, and why the attempt failed.
    Requires permission to read the Security event log and failure auditing.
.PARAMETER Hours
    Look back this many hours unless -All is specified. Default: 24.
.PARAMETER MaxEvents
    Maximum number of matching events to retrieve. Default: 500 for time-limited searches.
    When -All is used, no event count limit is applied unless -MaxEvents is explicitly supplied.
.PARAMETER All
    Search all retained Event ID 4625 entries in the Security log, regardless of age.
    The Security log may not retain older events.
.PARAMETER CsvPath
    Optional CSV export path. The CSV includes all collected fields.
.PARAMETER PassThru
    Return PowerShell objects instead of formatting them as a table.
.EXAMPLE
    .\Get-FailedLogonAttempts.ps1
.EXAMPLE
    .\Get-FailedLogonAttempts.ps1 -All
.EXAMPLE
    .\Get-FailedLogonAttempts.ps1 -All -MaxEvents 1000
.EXAMPLE
    .\Get-FailedLogonAttempts.ps1 -Hours 48 -MaxEvents 1000
.EXAMPLE
    .\Get-FailedLogonAttempts.ps1 -Hours 24 -CsvPath .\failed-logons.csv
.EXAMPLE
    .\Get-FailedLogonAttempts.ps1 -PassThru | Where-Object SourceIP -eq '172.16.254.166'
.NOTES
    Logon Type 3 means network logon; it does not by itself prove an RDP attempt.
    IP address and workstation may be absent in some events.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 8760)]
    [int]$Hours = 24,

    [ValidateRange(1, 50000)]
    [int]$MaxEvents = 500,

    [switch]$All,

    [string]$CsvPath,

    [switch]$PassThru
)

$logonTypes = @{
    0  = 'System'
    2  = 'Interactive (console)'
    3  = 'Network (e.g., SMB/NTLM)'
    4  = 'Batch (scheduled task)'
    5  = 'Service'
    7  = 'Unlock'
    8  = 'NetworkCleartext'
    9  = 'NewCredentials (RunAs /netonly)'
    10 = 'RemoteInteractive (RDP session)'
    11 = 'CachedInteractive'
    12 = 'CachedRemoteInteractive'
    13 = 'CachedUnlock'
}

$statusText = @{
    '0xc000006d' = 'Bad username or authentication information'
    '0xc000006e' = 'Account restriction'
    '0xc0000234' = 'Account locked out'
    '0xc0000064' = 'User does not exist'
    '0xc000006a' = 'Wrong password'
    '0xc0000072' = 'Account disabled'
    '0xc000006f' = 'Outside logon hours'
    '0xc0000070' = 'Unauthorized workstation'
    '0xc0000193' = 'Account expired'
    '0xc0000071' = 'Password expired'
    '0xc0000133' = 'Clock out of sync'
    '0xc0000224' = 'Password change required'
    '0xc000015b' = 'Logon type not granted'
    '0xc000005e' = 'No logon servers available'
    '0xc000018c' = 'Domain trust failed'
}

function Get-FailureReason {
    param([string]$Code)

    if ([string]::IsNullOrWhiteSpace($Code)) {
        return 'Not provided'
    }

    $key = $Code.Trim().ToLowerInvariant()
    if ($statusText.ContainsKey($key)) {
        return $statusText[$key]
    }

    return "Unknown ($Code)"
}

if ($All -and $PSBoundParameters.ContainsKey('Hours')) {
    throw 'Specify either -All or -Hours, not both.'
}

$filter = @{
    LogName = 'Security'
    Id      = 4625
}

if (-not $All) {
    $filter.StartTime = (Get-Date).AddHours(-$Hours)
}

$getEventParams = @{
    FilterHashtable = $filter
    ErrorAction     = 'Stop'
}

# -All searches the whole retained log by default. An explicit -MaxEvents still works.
if (-not $All -or $PSBoundParameters.ContainsKey('MaxEvents')) {
    $getEventParams.MaxEvents = $MaxEvents
}

try {
    $events = @(Get-WinEvent @getEventParams)
}
catch {
    if ($_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*') {
        if ($All) {
            Write-Warning 'No Event ID 4625 entries found in the retained Security log.'
        }
        else {
            Write-Warning "No Event ID 4625 entries found in the last $Hours hours."
        }
        return
    }

    Write-Error "Unable to read the Security event log: $($_.Exception.Message)"
    return
}

$results = @(
    foreach ($event in $events) {
        try {
            $xml = [xml]$event.ToXml()
            $data = @{}

            foreach ($node in $xml.Event.EventData.Data) {
                if ($node.Name) {
                    $data[$node.Name] = [string]$node.'#text'
                }
            }

            [int]$logonType = 0
            $hasLogonType = [int]::TryParse([string]$data['LogonType'], [ref]$logonType)

            $subStatus = [string]$data['SubStatus']
            $status = [string]$data['Status']
            $reasonCode = if ($subStatus -and $subStatus -ne '0x0') {
                $subStatus
            }
            else {
                $status
            }

            [PSCustomObject]@{
                Time          = $event.TimeCreated
                User          = $data['TargetUserName']
                SourceIP      = $data['IpAddress']
                LogonType     = if ($hasLogonType) { $logonType } else { $null }
                Reason        = Get-FailureReason -Code $reasonCode
                Workstation   = $data['WorkstationName']
                AccountDomain = $data['TargetDomainName']
                LogonTypeText = if ($hasLogonType -and $logonTypes.ContainsKey($logonType)) {
                    $logonTypes[$logonType]
                }
                else {
                    "Unknown ($($data['LogonType']))"
                }
                AuthPackage   = $data['AuthenticationPackageName']
                Status        = $status
                SubStatus     = $subStatus
                ReasonCode    = $reasonCode
                RecordID      = $event.RecordId
            }
        }
        catch {
            Write-Warning "Could not parse event RecordID $($event.RecordId): $($_.Exception.Message)"
        }
    }
)

if ($results.Count -eq 0) {
    Write-Warning 'Matching events were found, but none could be parsed.'
    return
}

if ($CsvPath) {
    try {
        $results | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Exported $($results.Count) events to $CsvPath"
    }
    catch {
        Write-Error "CSV export failed: $($_.Exception.Message)"
        return
    }
}

if ($PassThru) {
    $results
}
else {
    $results | Format-Table Time, User, SourceIP, LogonType, Reason, Workstation -AutoSize
}
