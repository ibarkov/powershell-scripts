# Get-PortUsage.ps1 — Windows TCP/UDP Port and Process Usage

A PowerShell utility for finding **which process is using a local TCP or UDP port** on Windows. It combines network endpoint information with process details to display the **PID, executable name, executable path, command line, and process owner** when available.

Useful for Windows Server troubleshooting, port conflicts, service diagnostics, and investigating current network connections involving applications such as IIS, Apache, Tomcat, Oracle, and PostgreSQL.

**Script version:** 1.3  
**Platform:** Windows  
**PowerShell:** Windows PowerShell 5.1 or later (requires the Windows `NetTCPIP` and `CimCmdlets` cmdlets)

> **Scope:** This script displays a **point-in-time snapshot** of local TCP connections and UDP endpoints. It does not monitor historical connections, capture packets, or determine which side initiated a TCP connection. It is read-only.

## Features

- Find the process using one or more **local** ports (`-Port`).
- Inspect TCP connections, UDP endpoints, or both (`-Protocol`).
- Show listening and established TCP connections by default (`-State Active`).
- Inspect all TCP states or select `Listen`, `Established`, `TimeWait`, or `CloseWait`.
- Filter by process name, remote TCP IP address, and loopback addresses.
- Show PID, process name, executable path, command line, and account owner when accessible.
- Cache process and owner information to avoid repeated owner lookups for the same PID.
- Export records to UTF-8 CSV or return structured PowerShell objects.
- Gracefully handle a port with no matching endpoints.
- Run without third-party PowerShell modules.

## Requirements

- Windows with Windows PowerShell 5.1 or a compatible later PowerShell version.
- `Get-NetTCPConnection` and `Get-NetUDPEndpoint` from the Windows `NetTCPIP` module.
- `Get-CimInstance` and `Invoke-CimMethod` from `CimCmdlets`.
- Sufficient privileges to inspect the relevant connections and processes.

**Run PowerShell as Administrator** for the best chance of retrieving process owners, executable paths, and command lines. Some processes may still restrict access, and a process can exit before its details are retrieved.

## Quick Start

Run the script from its directory:

```powershell
# Show listening and established TCP connections
.\Get-PortUsage.ps1

# Find the process using local TCP port 8081
.\Get-PortUsage.ps1 -Port 8081

# Check several local ports
.\Get-PortUsage.ps1 -Port 80,443,3389
```

By default, the script searches **TCP** and uses `-State Active` (TCP `Listen` and `Established`).

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Port <int[]>` | All local ports | Filter by one or more **local** port numbers from 1 to 65535. |
| `-Protocol <string>` | `TCP` | Choose `TCP`, `UDP`, or `Both`. |
| `-ProcessName <string>` | None | Match process names using case-insensitive substring/wildcard matching, e.g. `tomcat8` or `java*`. |
| `-State <string>` | `Active` | TCP state filter: `Active`, `All`, `Listen`, `Established`, `TimeWait`, or `CloseWait`. |
| `-RemoteAddress <string>` | None | Match an **exact remote TCP IP address**. Not supported with UDP-only mode. |
| `-NoLoopback` | Off | Exclude connections with IPv4 `127.*` or IPv6 `::1` loopback addresses. |
| `-PassThru` | Off | Return PowerShell objects instead of formatting a table. |
| `-CsvPath <string>` | None | Export the selected results to a UTF-8 CSV file. |

### TCP states and UDP behavior

| Example | Returned data |
|---|---|
| `-Protocol TCP` | TCP `Listen` and `Established` (`Active` default). |
| `-Protocol TCP -State All` | All TCP states available in the snapshot. |
| `-Protocol TCP -State TimeWait` | TCP connections in `TimeWait`. |
| `-Protocol UDP` | All UDP endpoints; their reported `State` is `N/A`. |
| `-Protocol Both` | TCP `Listen`/`Established` **and** all UDP endpoints. |
| `-Protocol Both -State All` | All TCP states **and** all UDP endpoints. |
| `-Protocol Both -State Established` | Only TCP `Established` connections; UDP is excluded. |

UDP does not have TCP connection states. For `-Protocol UDP`, only `-State Active` (the default) and `-State All` are accepted, and both return all matching UDP endpoints. The `-RemoteAddress` parameter is not supported with `-Protocol UDP`.

With `-Protocol Both -RemoteAddress <IP>`, the remote-address filter effectively selects TCP connections, since UDP endpoint records do not contain a remote address.

## Usage Examples

### Identify a process by port

```powershell
# Find the process listening on or connected through local port 3389
.\Get-PortUsage.ps1 -Port 3389

# Check the Oracle listener's local TCP port
.\Get-PortUsage.ps1 -Port 1521

# Inspect TCP and UDP on local port 53
.\Get-PortUsage.ps1 -Protocol Both -Port 53
```

`-Port` filters the **local** port. A connection to a remote server's port 443 is not returned by `-Port 443` unless the local port is also 443. Use `-PassThru` with PowerShell filtering for custom remote-port queries.

### Find all ports belonging to a process

```powershell
.\Get-PortUsage.ps1 -ProcessName tomcat8

.\Get-PortUsage.ps1 -ProcessName 'java*' -PassThru |
    Format-Table Protocol, LocalAddress, LocalPort, RemoteAddress, RemotePort, State
```

### List established connections excluding loopback

```powershell
.\Get-PortUsage.ps1 -State Established -NoLoopback
```

This includes non-loopback **inbound and outbound** TCP connections. It does not establish which endpoint initiated the connection.

### Find connections to a particular remote IP

```powershell
.\Get-PortUsage.ps1 -RemoteAddress '203.0.113.10'
```

The example uses a documentation IP address. Matching is exact; the parameter does not perform DNS resolution.

### Inspect UDP endpoints

```powershell
.\Get-PortUsage.ps1 -Protocol UDP

.\Get-PortUsage.ps1 -Protocol UDP -Port 3389

.\Get-PortUsage.ps1 -Protocol Both -State All
```

UDP endpoint records identify **local bindings**, not individual remote peer connections.

### Inspect less-common TCP states

```powershell
.\Get-PortUsage.ps1 -State TimeWait

.\Get-PortUsage.ps1 -State CloseWait

.\Get-PortUsage.ps1 -State All
```

For some TCP states, including `TimeWait`, the original process may already have exited; the reported PID might not identify the process that originally established the connection.

### Inspect detailed process information

```powershell
.\Get-PortUsage.ps1 -Port 8081 -PassThru |
    Format-List *
```

### Export to CSV

```powershell
.\Get-PortUsage.ps1 -State Listen -CsvPath .\listening-ports.csv

Import-Csv .\listening-ports.csv | Format-List *
```

> **Security warning:** The `CommandLine` field may contain passwords, access tokens, connection strings, or other sensitive information. Do not commit diagnostic CSV files to a public repository or share them without reviewing their contents.

## Example Output

### Identify the process using a local port

```text
Protocol LocalPort ProcessID ProcessName User                       Path
-------- --------- --------- ----------- ----                       ----
TCP           8081      3764 tomcat8.exe NT AUTHORITY\LOCAL SERVICE C:\Apps\Tomcat\bin\Tomcat8.exe
```

### Find established TCP connections

```text
Protocol LocalPort RemoteAddress RemotePort State       ProcessName User
-------- --------- ------------- ---------- -----       ----------- ----
TCP          49808 127.0.0.1           5433 Established tomcat8.exe NT AUTHORITY\LOCAL SERVICE
TCP          49732 203.0.113.10         443 Established example.exe NT AUTHORITY\SYSTEM
```

*Examples are illustrative, based on the observed output format. Paths, process IDs, and addresses may vary.*

## Output Fields

Use `-PassThru` or `-CsvPath` to access all fields; the console table shows a subset.

| Field | Description |
|---|---|
| `Protocol` | `TCP` or `UDP`. |
| `LocalAddress` | Local IP address or wildcard binding. |
| `LocalPort` | Local port number. |
| `RemoteAddress` | Remote TCP IP address, when applicable. |
| `RemotePort` | Remote TCP port, when applicable. |
| `State` | TCP state or `N/A` for UDP. |
| `ProcessID` | PID associated with the connection or endpoint. |
| `ProcessName` | Executable/process name, or `Unknown` if unavailable. |
| `User` | Process owner, when resolution succeeds. |
| `Path` | Executable path, when accessible. |
| `CommandLine` | Process command line, when accessible. |

## Notes and Limitations

- The script reports a **snapshot**, not a history. Connections can appear or disappear during collection, so network and process information may not represent precisely the same instant.
- The script does **not** include a `-Watch` mode in version 1.3.
- `0.0.0.0` and `::` mean a socket is bound to all local IPv4 or IPv6 addresses respectively; this does **not** prove the port is reachable from the Internet. Firewall rules, routing, and other controls still apply.
- The same port may appear multiple times for IPv4/IPv6 bindings, different local addresses, or multiple connections. These are not necessarily duplicates.
- An endpoint absent from the default `Active` view does **not** prove that the port is available in every TCP state or on UDP.
- `Get-NetUDPEndpoint` does not expose remote UDP peers or TCP-style connection states.
- `-NoLoopback` covers common IPv4 loopback addresses (`127.*`) and exact IPv6 `::1`; it does not normalize every equivalent IPv6 representation.
- `-ProcessName` performs substring matching and supports wildcards; inspect all matches if process names are similar.
- Process details and owners may be missing for protected/system processes or when the process exits between queries. A `TimeWait` record may not be attributable to the original process.
- Reading process command lines or exporting them may expose sensitive data.
- When no matching connections are found, the script displays a warning and returns no records. This is not by itself proof that a service is not running.

## Troubleshooting

### No matching connections

Try an unrestricted TCP view or examine all states:

```powershell
.\Get-PortUsage.ps1 -State All
.\Get-PortUsage.ps1 -Protocol Both -State All
```

For a specific port, verify that it is a **local** port and that the intended protocol is selected.

### Process name, path, or owner is unavailable

Run PowerShell as Administrator and try again. Process access can also be restricted by Windows, and short-lived processes may exit before details can be retrieved.

### A UDP query has no remote address or state

This is expected: UDP endpoint information does not provide TCP-style connection state or per-peer remote addresses.

### View PowerShell help

```powershell
Get-Help .\Get-PortUsage.ps1 -Detailed
```

## Testing Status

The following scenarios were exercised on a local Windows machine using the script version 1.3:

- Querying a local TCP port with a matching process (`-Port 8081`).
- Querying a local TCP port with no matching active connection (`-Port 65000`).
- Listing UDP endpoints (`-Protocol UDP` and `-Protocol UDP -State All`).
- Querying both protocols on a port with no matching endpoint (`-Protocol Both -Port 53`).
- Retrieving TCP `TimeWait` records.
- Using `-Protocol Both -State Established` without including UDP endpoints.
- Filtering by process name (`-ProcessName tomcat8`, in earlier testing).

The outputs of CSV export, `-PassThru`, permissions-related failures, and the script's behavior on other Windows versions have **not** been independently verified in the supplied version 1.3 test results.

## Related Scripts

- [Get-AccountAndGroupChanges](../../Security/Get-AccountAndGroupChanges/) — audit changes to Windows users and security groups.
- [Get-AccountLockoutEvents](../../Security/Get-AccountLockoutEvents/) — inspect Windows account lockouts.
- [Get-FailedLogonAttempts](../../Security/Get-FailedLogonAttempts/) — investigate failed Windows logons.
- [Get-SuccessfulLogons](../../Security/Get-SuccessfulLogons/) — inspect successful Windows logons.

## References

- [Get-NetTCPConnection — Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection)
- [Get-NetUDPEndpoint — Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netudpendpoint)
- [Win32_Process class — Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process)

## License

Licensed under the [MIT License](../../../LICENSE).

Copyright (c) 2026 Igor Barkov.
