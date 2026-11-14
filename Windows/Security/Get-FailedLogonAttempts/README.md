# Get-FailedLogonAttempts.ps1 — Windows Failed Logon Audit (Event ID 4625)

A lightweight PowerShell script for auditing **failed Windows logon attempts** using **Security Event ID 4625**. Identify the account used, source IP address, workstation, logon type, and Windows-reported authentication failure reason.

Useful for Windows Server troubleshooting, investigating failed network authentications, reviewing unsuccessful RDP logon attempts, and examining the local Security event log.

## Features

- Reads **Windows Security Event ID 4625** from the local computer.
- Displays a compact table with **Time, User, SourceIP, LogonType, Reason,** and **Workstation**.
- Parses event XML and decodes common Windows logon types and failure status codes.
- Searches a configurable period with `-Hours` (default: **24 hours**).
- Searches all **retained** matching events with `-All`.
- Limits returned events with `-MaxEvents` (default: **500** for time-limited searches).
- Exports parsed event details to UTF-8 CSV with `-CsvPath`.
- Returns PowerShell objects for additional filtering with `-PassThru`.
- Requires no third-party PowerShell modules.

## Requirements

- Windows with `Get-WinEvent` (developed for **Windows PowerShell 5.1**).
- Permission to read the **Security** event log; an elevated PowerShell session may be required.
- Windows auditing configured to record failed logon events (for example, **Audit Logon: Failure**).

## Quick start

Run the script from its directory:

```powershell
# Show failed Windows logons from the last 24 hours (up to 500 events)
.\Get-FailedLogonAttempts.ps1
```

## Usage examples

### Search by time range

```powershell
# Last 72 hours, up to 1,000 failed logon events
.\Get-FailedLogonAttempts.ps1 -Hours 72 -MaxEvents 1000
```

### Search all retained history

```powershell
# All retained Event ID 4625 records (no event-count limit)
.\Get-FailedLogonAttempts.ps1 -All

# The 1,000 most recent matching records in the retained log
.\Get-FailedLogonAttempts.ps1 -All -MaxEvents 1000
```

> **Note:** `-All` and `-Hours` cannot be used together. `-All` searches only records still present in the Security log.

### Export failed logons to CSV

```powershell
# Export the last 24 hours
.\Get-FailedLogonAttempts.ps1 -CsvPath .\failed-logons.csv

# Export all retained matching records
.\Get-FailedLogonAttempts.ps1 -All -CsvPath .\failed-logons.csv
```

### Filter by source IP address

```powershell
.\Get-FailedLogonAttempts.ps1 -All -PassThru |
    Where-Object SourceIP -eq '192.0.2.10'
```

### Inspect all event properties

```powershell
.\Get-FailedLogonAttempts.ps1 -MaxEvents 5 -PassThru |
    Format-List *
```

## Parameters

| Parameter | Description |
| --- | --- |
| `-Hours <int>` | Look back the specified number of hours. Default: `24`. Cannot be combined with `-All`. |
| `-MaxEvents <int>` | Maximum number of matching events to retrieve. Default: `500` for time-limited searches; with `-All`, applies only when explicitly provided. |
| `-All` | Search all retained Security Event ID 4625 records regardless of age. |
| `-CsvPath <string>` | Write all parsed output properties to a UTF-8 CSV file. |
| `-PassThru` | Output structured PowerShell objects instead of a formatted table. |

## Output fields

The default table displays **Time, User, SourceIP, LogonType, Reason,** and **Workstation**. Use `-PassThru` or `-CsvPath` to access additional fields.

| Field | Description |
| --- | --- |
| `Time` | Time of the failed logon event. |
| `User` | Account name used in the attempt. |
| `SourceIP` | Source IP address, if recorded by Windows. |
| `LogonType` | Numeric Windows logon type (for example, `3` or `10`). |
| `Reason` | Human-readable failure reason derived from the event data. |
| `Workstation` | Source workstation name, when available. |
| `AccountDomain` | Domain or local computer context reported by Windows. |
| `LogonTypeText` | Human-readable description of the logon type. |
| `AuthPackage` | Authentication package, such as NTLM or Kerberos, when reported. |
| `Status`, `SubStatus`, `ReasonCode` | Original Windows authentication failure codes. |
| `RecordID` | Event record identifier within the Security log. |

## Understanding Windows logon types

| Logon type | Meaning | Typical example |
| --- | --- | --- |
| `2` | Interactive | Local console logon attempt. |
| `3` | Network | Network access, such as SMB authentication. |
| `4` | Batch | Scheduled task or batch logon. |
| `5` | Service | Service logon. |
| `7` | Unlock | Attempt to unlock a workstation. |
| `10` | RemoteInteractive | Remote Desktop (RDP) logon attempt. |
| `11` | CachedInteractive | Cached interactive credentials. |

**Important:** Logon Type `3` is a network logon and **does not by itself prove an RDP attempt**. To investigate RDP activity, correlate the logon type with the source address, account, and relevant RDP event logs.

## Limitations and security considerations

- Reads the **local** Security log only; it does not collect events from remote Windows servers.
- Event ID 4625 records failed logon attempts **when the relevant auditing is enabled**. Missing events do not prove that no attempts occurred.
- `-All` means all **retained** events, not the complete history of the machine. Logs may have been cleared or overwritten.
- Unrestricted `-All` queries may consume considerable time and memory on large logs. Consider `-All -MaxEvents 1000` first.
- `SourceIP` and `Workstation` can be empty, depending on how authentication was attempted.
- Windows status codes provide diagnostic clues, but not necessarily the underlying root cause.
- CSV output can contain sensitive account names, internal addresses, and authentication details. Review exports before sharing them publicly.

## Running downloaded PowerShell scripts

If Windows blocks a script downloaded from the internet, review the file first. If appropriate, remove its downloaded-file mark:

```powershell
Unblock-File -Path .\Get-FailedLogonAttempts.ps1
```

To display built-in script help:

```powershell
Get-Help .\Get-FailedLogonAttempts.ps1 -Detailed
```

## Related scripts

- [Get-SuccessfulLogons](../Get-SuccessfulLogons/) — inspect successful Windows logons (Security Event ID 4624).
- [Get-RdpSessionHistory](../Get-RdpSessionHistory/) — inspect RDP session logons, reconnects, disconnects, and logoffs.
