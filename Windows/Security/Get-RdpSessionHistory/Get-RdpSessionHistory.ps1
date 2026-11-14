# Version 1.2 — Windows RDP/session lifecycle history.
# Reads LocalSessionManager Event IDs 21, 23, 24, 25.
<#
.SYNOPSIS
    Shows Windows session logon, reconnect, disconnect, and logoff history.
.DESCRIPTION
    Reads Microsoft-Windows-TerminalServices-LocalSessionManager/Operational.
    Extracts session metadata primarily from UserData/EventXML, with a fallback
    for EventData, and never substitutes the server name for a client name.
    LOCAL source addresses are preserved as LOCAL (not converted to 127.0.0.1).
    Some events also describe local console sessions; they are not all proof of RDP.
.PARAMETER Hours
    How many hours to search. Default: 24. Cannot be combined with -All.
.PARAMETER MaxEvents
    Maximum number of matching events. Default: 500 for time-limited searches.
    With -All, no limit unless -MaxEvents is explicitly specified.
.PARAMETER All
    Search all entries still retained in the event log.
.PARAMETER User
    Filter by user name, short name, or DOMAIN\User (wildcards supported).
.PARAMETER Action
    Filter by Logon, Reconnect, Disconnect, or Logoff.
.PARAMETER CsvPath
    Optional path for CSV export.
.PARAMETER PassThru
    Return objects rather than display a table and summary.
.PARAMETER NoSummary
    Suppress the summary when displaying the table.
.EXAMPLE
    .\Get-RdpSessionHistory.ps1 -All
.EXAMPLE
    .\Get-RdpSessionHistory.ps1 -User Administrator -Hours 72
.EXAMPLE
    .\Get-RdpSessionHistory.ps1 -Action Reconnect -All -CsvPath .\rdp.csv
.NOTES
    Event IDs: 21 Logon, 23 Logoff, 24 Disconnect, 25 Reconnect.
    Logs may have been rotated or cleared; events are not a complete historical
    record of all network connections.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 8760)]
    [int]$Hours = 24,

    [ValidateRange(1, 50000)]
    [int]$MaxEvents = 500,

    [switch]$All,

    [string]$User,

    [ValidateSet('Logon', 'Reconnect', 'Disconnect', 'Logoff')]
    [string[]]$Action,

    [string]$CsvPath,

    [switch]$PassThru,

    [switch]$NoSummary
)

$logName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
$actionByEventId = @{ 21 = 'Logon'; 23 = 'Logoff'; 24 = 'Disconnect'; 25 = 'Reconnect' }
$eventIdByAction = @{ Logon = 21; Logoff = 23; Disconnect = 24; Reconnect = 25 }

if ($All -and $PSBoundParameters.ContainsKey('Hours')) {
    throw 'Specify either -All or -Hours, not both.'
}

function Get-FirstValue {
    param(
        [hashtable]$Data,
        [string[]]$Names
    )
    foreach ($name in $Names) {
        if ($Data.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace($Data[$name])) {
            return [string]$Data[$name]
        }
    }
    return $null
}

function Get-SessionEventFields {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$EventRecord)

    [xml]$xml = $EventRecord.ToXml()
    $fields = @{}

    # Primary source for this provider: UserData/EventXML/User|SessionID|Address.
    # Local-name XPath is namespace-independent (works with Event_NS too).
    $userDataNodes = $xml.SelectNodes(
        "/*[local-name()='Event']/*[local-name()='UserData']/*/*"
    )
    foreach ($node in $userDataNodes) {
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            $fields[$node.LocalName] = [string]$node.InnerText
        }
    }

    # Fallback: named or positional EventData for other event versions.
    $eventDataNodes = $xml.SelectNodes(
        "/*[local-name()='Event']/*[local-name()='EventData']/*[local-name()='Data']"
    )
    $position = 0
    foreach ($node in $eventDataNodes) {
        $position++
        $name = $node.GetAttribute('Name')
        if (-not $name) { $name = "Param$position" }
        if (-not $fields.ContainsKey($name)) {
            $fields[$name] = [string]$node.InnerText
        }
    }

    return $fields
}

$eventIds = @(21, 23, 24, 25)
if ($PSBoundParameters.ContainsKey('Action')) {
    $eventIds = @($Action | ForEach-Object { $eventIdByAction[$_] } | Sort-Object -Unique)
}

$filter = @{ LogName = $logName; Id = $eventIds }
if (-not $All) {
    $filter.StartTime = (Get-Date).AddHours(-$Hours)
}

$getEventParams = @{ FilterHashtable = $filter; ErrorAction = 'Stop' }
$limitResults = (-not $All -or $PSBoundParameters.ContainsKey('MaxEvents'))

# -User is applied after XML parsing, so don't trim other users' events first.
$hasUserFilter = -not [string]::IsNullOrWhiteSpace($User)
if ($limitResults -and -not $hasUserFilter) {
    $getEventParams.MaxEvents = $MaxEvents
}

if ($All -and -not $PSBoundParameters.ContainsKey('MaxEvents')) {
    Write-Warning 'Reading all retained matching events; this may take time and memory.'
}
if ($hasUserFilter) {
    Write-Verbose 'Filtering by user after loading events so -MaxEvents will count only matching users.'
}

try {
    $events = @(Get-WinEvent @getEventParams)
}
catch {
    if ($_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*') {
        Write-Warning 'No matching session events found in the selected period.'
        return
    }
    Write-Error "Could not read '$logName': $($_.Exception.Message)"
    return
}

$results = @(
    foreach ($event in $events) {
        try {
            $data = Get-SessionEventFields -EventRecord $event

            $fullUser = Get-FirstValue -Data $data -Names @('User', 'Username', 'TargetUserName', 'Param1')
            $domain = $null
            $shortUser = $fullUser
            if ($fullUser -and $fullUser.Contains('\')) {
                $separator = $fullUser.IndexOf('\')
                $domain = $fullUser.Substring(0, $separator)
                $shortUser = $fullUser.Substring($separator + 1)
            }

            $address = Get-FirstValue -Data $data -Names @('Address', 'IpAddress', 'Param3')
            $sourceIP = if ($address -and $address -ne 'LOCAL') { $address } else { $null }
            $rawSessionId = Get-FirstValue -Data $data -Names @('SessionID', 'SessionId', 'Param2')
            [int]$sessionId = 0
            $hasSessionId = [int]::TryParse([string]$rawSessionId, [ref]$sessionId)

            [PSCustomObject]@{
                Time          = $event.TimeCreated
                User          = $shortUser
                Domain        = $domain
                SourceAddress = $address
                SourceIP      = $sourceIP
                SessionID     = if ($hasSessionId) { $sessionId } else { $null }
                Action        = $actionByEventId[[int]$event.Id]
                Server        = $event.MachineName
                Workstation   = Get-FirstValue -Data $data -Names @('WorkstationName', 'Workstation')
                EventID       = [int]$event.Id
                LogName       = $logName
                RecordID      = $event.RecordId
            }
        }
        catch {
            Write-Warning "Failed to parse event RecordID $($event.RecordId): $($_.Exception.Message)"
        }
    }
)

if ($hasUserFilter) {
    $results = @($results | Where-Object {
        $shortMatch = $_.User -like $User
        $fullMatch = if ($_.Domain) { "$($_.Domain)\$($_.User)" -like $User } else { $false }
        $shortMatch -or $fullMatch
    })
}

if ($results.Count -eq 0) {
    Write-Warning 'No events matched the selected filters, or event fields could not be parsed.'
    return
}

# Get-WinEvent retrieves newest first. Limit after the user filter if needed.
if ($hasUserFilter -and $limitResults) {
    $results = @($results | Sort-Object Time -Descending | Select-Object -First $MaxEvents)
}
$results = @($results | Sort-Object Time, RecordID)

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
    $results | Format-Table Time, User, SourceAddress, SessionID, Action -AutoSize

    if (-not $NoSummary) {
        Write-Host ''
        Write-Host ("Summary: {0} event(s), {1} .. {2}" -f `
            $results.Count, `
            $results[0].Time.ToString('yyyy-MM-dd HH:mm:ss'), `
            $results[-1].Time.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
        $summary = $results | Group-Object Action | Sort-Object Name |
            Select-Object @{Name='Action'; Expression={$_.Name}}, Count
        $summary | Format-Table -AutoSize | Out-String | Write-Host
    }
}
