# Version 1.4 — successful Windows logons (Security Event ID 4624).
# -LogonType accepts friendly names (RDP, Console, SMB, Service, ...) or numbers 0-13.
# XPath filtering (EventID + timediff + LogonType) happens inside the event log service,
# so -MaxEvents limits already-filtered results.
<#
.SYNOPSIS
    Displays successful Windows logon events (Security Event ID 4624).
.DESCRIPTION
    Reads the local Windows Security log, parses event XML by field name,
    and shows who signed in, from where, and how (console, RDP, SMB, service, ...).
    Requires permission to read the Security event log.
.PARAMETER Hours
    Look back this many hours unless -All is specified. Default: 24.
.PARAMETER MaxEvents
    Maximum number of matching events to retrieve. Default: 500 for time-limited searches.
    When -All is used, no event count limit is applied unless -MaxEvents is explicitly supplied.
.PARAMETER All
    Search all retained Event ID 4624 entries in the Security log, regardless of age.
    The Security log may not retain older events.
.PARAMETER LogonType
    Filter by one or more logon types. Accepts friendly names or numeric values:
      System, Interactive (alias Console), Network (alias SMB), Batch (alias ScheduledTask),
      Service, Unlock, NetworkCleartext, NewCredentials (alias RunAs),
      RDP (aliases RemoteInteractive, RemoteDesktop),
      CachedInteractive, CachedRemoteInteractive, CachedUnlock.
    Numeric values 0-13 are also accepted for backward compatibility.
    Applied at the event log query level via XPath, before -MaxEvents is enforced.
.PARAMETER CsvPath
    Optional CSV export path. The CSV includes all collected fields.
.PARAMETER PassThru
    Return PowerShell objects instead of formatting them as a table.
.EXAMPLE
    .\Get-SuccessfulLogons.ps1
.EXAMPLE
    .\Get-SuccessfulLogons.ps1 -LogonType RDP
.EXAMPLE
    .\Get-SuccessfulLogons.ps1 -LogonType Console,RDP,Unlock -Hours 48
.EXAMPLE
    .\Get-SuccessfulLogons.ps1 -LogonType RDP -Hours 168 -MaxEvents 10
.EXAMPLE
    .\Get-SuccessfulLogons.ps1 -LogonType RDP -All
.EXAMPLE
    .\Get-SuccessfulLogons.ps1 -Hours 24 -CsvPath .\successful-logons.csv
.EXAMPLE
    .\Get-SuccessfulLogons.ps1 -PassThru | Where-Object SourceIP -eq '10.0.0.5'
.NOTES
    Logon Type 3 means network logon (SMB/NTLM); it is not by itself an RDP attempt.
    IP address and workstation may be absent in some events.
    Machine account logons typically end with '$'.
    Logon Type 5 (Service) and 4 (Batch) are usually not human interactive sessions.
    Event ID 4624 with LogonType 10 only records the moment a NEW RDP session is created.
    Reconnects and disconnects to an existing session are NOT logged here —
    use Get-RdpSessionHistory.ps1 (LocalSessionManager events 21/23/24/25) for that.
    For additional RDP reconnect/disconnect evidence, see Security events 4778 and 4779.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 8760)]
    [int]$Hours = 24,

    [ValidateRange(1, 50000)]
    [int]$MaxEvents = 500,

    [switch]$All,

    [ValidateSet(
        'System',
        'Interactive',
        'Console',
        'Network',
        'SMB',
        'Batch',
        'ScheduledTask',
        'Service',
        'Unlock',
        'NetworkCleartext',
        'NewCredentials',
        'RunAs',
        'RDP',
        'RemoteInteractive',
        'RemoteDesktop',
        'CachedInteractive',
        'CachedRemoteInteractive',
        'CachedUnlock',
        '0','1','2','3','4','5','6','7','8','9','10','11','12','13'
    )]
    [string[]]$LogonType,

    [string]$CsvPath,

    [switch]$PassThru
)

# Short human-readable names used in the table and in the LogonType output property.
$logonTypeNames = @{
    0  = 'System'
    2  = 'Console'
    3  = 'SMB/NTLM'
    4  = 'Scheduled'
    5  = 'Service'
    7  = 'Unlock'
    8  = 'Cleartext'
    9  = 'RunAs'
    10 = 'RDP'
    11 = 'Cached'
    12 = 'CachedRDP'
    13 = 'CachedUnlock'
}

# Alias map: user-supplied names -> numeric LogonType.
$logonTypeAliases = @{
    'System'                 = 0
    'Interactive'            = 2
    'Console'                = 2
    'Network'                = 3
    'SMB'                    = 3
    'Batch'                  = 4
    'ScheduledTask'          = 4
    'Service'                = 5
    'Unlock'                 = 7
    'NetworkCleartext'       = 8
    'NewCredentials'         = 9
    'RunAs'                  = 9
    'RDP'                    = 10
    'RemoteInteractive'      = 10
    'RemoteDesktop'          = 10
    'CachedInteractive'      = 11
    'CachedRemoteInteractive'= 12
    'CachedUnlock'           = 13
}

if ($All -and $PSBoundParameters.ContainsKey('Hours')) {
    throw 'Specify either -All or -Hours, not both.'
}

# Translate -LogonType values (names or numbers) into unique numeric types.
$numericLogonTypes = @()
if ($PSBoundParameters.ContainsKey('LogonType')) {
    $resolved = foreach ($raw in $LogonType) {
        $trimmed = $raw.Trim()

        if ($logonTypeAliases.ContainsKey($trimmed)) {
            $logonTypeAliases[$trimmed]
            continue
        }

        $parsed = 0
        if ([int]::TryParse($trimmed, [ref]$parsed) -and $parsed -ge 0 -and $parsed -le 13) {
            $parsed
            continue
        }

        throw "Unknown -LogonType value '$raw'. Use a name (e.g., RDP, Console, SMB) or a number 0-13."
    }

    $numericLogonTypes = @($resolved | Sort-Object -Unique)
    Write-Verbose "Resolved LogonType filter to: $($numericLogonTypes -join ', ')"
}

# === Build XPath filter ===
# System[...] and EventData[...] must be siblings inside *[...].
$systemConditions = @('EventID=4624')

if (-not $All) {
    $milliseconds = [long]$Hours * 3600000
    $systemConditions += "TimeCreated[timediff(@SystemTime) <= $milliseconds]"
}

$systemFilter = $systemConditions -join ' and '

$logonTypeFilter = ''
if ($numericLogonTypes.Count -gt 0) {
    $conditions = foreach ($lt in $numericLogonTypes) {
        "Data[@Name='LogonType']='$lt'"
    }
    $logonTypeFilter = ' and EventData[(' + ($conditions -join ' or ') + ')]'
}

$filterXPath = "*[System[$systemFilter]$logonTypeFilter]"
Write-Verbose "XPath: $filterXPath"

$getEventParams = @{
    LogName     = 'Security'
    FilterXPath = $filterXPath
    ErrorAction = 'Stop'
}

if (-not $All -or $PSBoundParameters.ContainsKey('MaxEvents')) {
    $getEventParams.MaxEvents = $MaxEvents
}

if ($All -and -not $PSBoundParameters.ContainsKey('MaxEvents')) {
    Write-Warning 'Searching the entire retained Security log without -MaxEvents. This may take a while and consume significant memory.'
}

try {
    $events = @(Get-WinEvent @getEventParams)
}
catch {
    if ($_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*') {
        if ($All) {
            Write-Warning 'No matching Event ID 4624 entries found in the retained Security log.'
        }
        else {
            $filterDesc = if ($numericLogonTypes.Count -gt 0) {
                " for LogonType $($numericLogonTypes -join ',')"
            } else { '' }
            Write-Warning "No matching Event ID 4624 entries found in the last $Hours hours$filterDesc."
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

            [int]$lt = 0
            $hasLogonType = [int]::TryParse([string]$data['LogonType'], [ref]$lt)

            [PSCustomObject]@{
                Time               = $event.TimeCreated
                LogName            = 'Security'
                EventId            = 4624
                User               = $data['TargetUserName']
                UserSID            = $data['TargetUserSid']
                SourceIP           = $data['IpAddress']
                LogonTypeId        = if ($hasLogonType) { $lt } else { $null }
                LogonType          = if ($hasLogonType -and $logonTypeNames.ContainsKey($lt)) {
                    $logonTypeNames[$lt]
                }
                else {
                    "Unknown ($($data['LogonType']))"
                }
                Workstation        = $data['WorkstationName']
                AccountDomain      = $data['TargetDomainName']
                AuthPackage        = $data['AuthenticationPackageName']
                LogonProcess       = $data['LogonProcessName']
                ImpersonationLevel = $data['ImpersonationLevel']
                ElevatedToken      = $data['ElevatedToken']
                SubjectUser        = $data['SubjectUserName']
                SubjectDomain      = $data['SubjectDomainName']
                TargetLogonId      = $data['TargetLogonId']
                RecordID           = $event.RecordId
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
    $results | Format-Table Time, User, SourceIP, LogonType, Workstation -AutoSize
}