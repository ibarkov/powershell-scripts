<#
.SYNOPSIS
    Resolves which process is using a TCP or UDP port.
.DESCRIPTION
    Shows the process ID (PID), name, executable path, command line, and owner
    for a specific port. If no port is specified, lists all listening/established ports.
    Supports filtering by process name, connection state, remote address, and loopback exclusion.

    Note: -RemoteAddress filter applies to TCP connections only.
    UDP endpoints do not have connection states (Listen/Established); they are
    reported with State = 'N/A'.
.PARAMETER Port
    One or more LOCAL ports to check (e.g., 80, 443, 3389). If omitted, shows all ports.
.PARAMETER Protocol
    TCP, UDP, or Both. Default: TCP.
.PARAMETER ProcessName
    Filter by process name (supports wildcards, e.g., 'java*', 'tomcat8').
.PARAMETER State
    Filter by TCP connection state. Default: Active.
    - Active: Listen + Established (most common view).
    - All: All TCP states.
    - Specific states: Listen, Established, TimeWait, CloseWait.
    Note: For UDP, only Active and All are allowed (both return all endpoints).
.PARAMETER RemoteAddress
    Filter by remote IP address (TCP only).
.PARAMETER NoLoopback
    Exclude loopback addresses (127.0.0.1, ::1) from the output.
.PARAMETER PassThru
    Return PowerShell objects instead of formatting them as a table.
.PARAMETER CsvPath
    Export the selected result records to a UTF-8 CSV file.
    WARNING: CommandLine may contain sensitive data (passwords, tokens).
.EXAMPLE
    .\Get-PortUsage.ps1 -Port 3389
.EXAMPLE
    .\Get-PortUsage.ps1 -ProcessName tomcat8
.EXAMPLE
    .\Get-PortUsage.ps1 -State TimeWait -NoLoopback
.EXAMPLE
    .\Get-PortUsage.ps1 -Protocol Both -State Established
.NOTES
    Version:   1.3
    Requires PowerShell 5.1+ (uses Get-NetTCPConnection).
    For command line and owner details, run as Administrator.
    Note: 0.0.0.0 and :: mean binding to all local addresses; they do not
    prove that the port is reachable from the Internet (check the firewall).
    Author:    Igor Barkov
    Copyright: (c) 2026 Igor Barkov
    License:   MIT
    GitHub:    https://github.com/ibarkov/powershell-scripts
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int[]]$Port,

    [ValidateSet('TCP', 'UDP', 'Both')]
    [string]$Protocol = 'TCP',

    [string]$ProcessName,

    [ValidateSet('Active', 'All', 'Listen', 'Established', 'TimeWait', 'CloseWait')]
    [string]$State = 'Active',

    [string]$RemoteAddress,

    [switch]$NoLoopback,

    [switch]$PassThru,

    [string]$CsvPath
)

# --- Validation of parameter combinations ---
if ($Protocol -eq 'UDP' -and $State -notin @('Active', 'All')) {
    Write-Error "The -State parameter ($State) is not applicable for UDP. Use -State Active, -State All, or omit it."
    return
}

if ($Protocol -eq 'UDP' -and $RemoteAddress) {
    Write-Error "The -RemoteAddress parameter is not supported for UDP."
    return
}

$portFilter = $Port -and $Port.Count -gt 0

# --- 1. Get Port-to-PID mapping ---
$connections = @()

try {
    if ($Protocol -eq 'TCP' -or $Protocol -eq 'Both') {
        $tcpParams = @{ ErrorAction = 'Stop' }
        if ($portFilter -and $Port.Count -eq 1) {
            $tcpParams.LocalPort = $Port[0]
        }

        try {
            $tcp = @(Get-NetTCPConnection @tcpParams)
        }
        catch {
            # Handle "no matching connections" gracefully
            if ($_.FullyQualifiedErrorId -like 'CmdletizationQuery_NotFound*') {
                $tcp = @()
            } else {
                throw
            }
        }

        # Apply state filtering for TCP
        if ($State -eq 'Active') {
            $tcp = $tcp | Where-Object { $_.State -eq 'Listen' -or $_.State -eq 'Established' }
        }
        elseif ($State -ne 'All') {
            $tcp = $tcp | Where-Object { $_.State -eq $State }
        }
        
        $connections += $tcp
    }
    
    if ($Protocol -eq 'UDP' -or $Protocol -eq 'Both') {
        # Skip UDP if user explicitly asked for a TCP-only state
        if ($State -in @('Active', 'All') -or $Protocol -eq 'UDP') {
            $udpParams = @{ ErrorAction = 'Stop' }
            if ($portFilter -and $Port.Count -eq 1) {
                $udpParams.LocalPort = $Port[0]
            }

            try {
                $udp = @(Get-NetUDPEndpoint @udpParams)
            }
            catch {
                if ($_.FullyQualifiedErrorId -like 'CmdletizationQuery_NotFound*') {
                    $udp = @()
                } else {
                    throw
                }
            }
            
            $connections += $udp
        }
    }
}
catch {
    Write-Error "Failed to retrieve network connections: $($_.Exception.Message)"
    return
}

# --- 2. Apply post-retrieval filters ---
if ($portFilter -and $Port.Count -gt 1) {
    $connections = $connections | Where-Object { $_.LocalPort -in $Port }
}

if ($RemoteAddress) {
    $connections = $connections | Where-Object { $_.RemoteAddress -eq $RemoteAddress }
}

if ($NoLoopback) {
    $connections = $connections | Where-Object { 
        $_.LocalAddress -notmatch '^(127\.|::1$)' -and 
        $_.RemoteAddress -notmatch '^(127\.|::1$)' 
    }
}

if (-not $connections) {
    Write-Warning "No listening or established connections found for the specified criteria."
    return
}

# --- 3. Resolve Process Info via CIM ---
$processCache = @{}
$ownerCache = @{}
$pids = $connections.OwningProcess | Select-Object -Unique

try {
    # Query processes locally
    $allProcesses = Get-CimInstance -ClassName Win32_Process -ErrorAction Stop
    $cimProcesses = $allProcesses | Where-Object { $_.ProcessId -in $pids }
    
    foreach ($proc in $cimProcesses) {
        $processCache[$proc.ProcessId] = $proc
    }
}
catch {
    Write-Warning "Could not retrieve process details via CIM (running without admin rights?): $($_.Exception.Message)"
}

# --- 4. Build Result Objects ---
$results = @()

foreach ($conn in $connections) {
    $pidVal = $conn.OwningProcess
    $procInfo = $processCache[$pidVal]
    
    $procName = "Unknown"
    $procPath = ""
    $cmdLine  = ""
    $owner    = ""

    if ($procInfo) {
        $procName = $procInfo.Name
        $procPath = $procInfo.ExecutablePath
        $cmdLine  = $procInfo.CommandLine
        
        # Check owner cache first to avoid multiple GetOwner calls for the same PID
        if ($ownerCache.ContainsKey($pidVal)) {
            $owner = $ownerCache[$pidVal]
        }
        else {
            try {
                $ownerResult = Invoke-CimMethod -InputObject $procInfo -MethodName GetOwner -ErrorAction Stop
                if ($ownerResult.ReturnValue -eq 0) {
                    $owner = "$($ownerResult.Domain)\$($ownerResult.User)"
                }
            }
            catch {
                $owner = "Access Denied"
            }
            $ownerCache[$pidVal] = $owner
        }
    }

    # Apply ProcessName filter AFTER resolving the process name
    if ($ProcessName -and $procName -notlike "*$ProcessName*") {
        continue
    }

    $results += [PSCustomObject][ordered]@{
        Protocol     = if ($conn.CimClass.CimClassName -match 'TCP') { 'TCP' } else { 'UDP' }
        LocalAddress = $conn.LocalAddress
        LocalPort    = $conn.LocalPort
        RemoteAddress= $conn.RemoteAddress
        RemotePort   = $conn.RemotePort
        State        = if ($conn.State) { $conn.State } else { 'N/A' }
        ProcessID    = $pidVal
        ProcessName  = $procName
        User         = $owner
        Path         = $procPath
        CommandLine  = $cmdLine
    }
}

if ($results.Count -eq 0) {
    Write-Warning "No connections matched the specified filters."
    return
}

$results = $results | Sort-Object LocalPort

# --- 5. Output ---
if ($CsvPath) {
    try {
        $results | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Exported $($results.Count) records to $CsvPath"
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
    if ($portFilter -and $Port.Count -eq 1) {
        $results | Format-Table Protocol, LocalPort, ProcessID, ProcessName, User, Path -AutoSize
    } else {
        $results | Format-Table Protocol, LocalPort, RemoteAddress, RemotePort, State, ProcessName, User -AutoSize
    }
}