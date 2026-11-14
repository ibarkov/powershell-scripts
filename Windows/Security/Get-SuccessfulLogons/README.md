# Get-SuccessfulLogons.ps1 — Windows Successful Logon Audit (Event ID 4624)

A lightweight PowerShell script for auditing **successful Windows logons** using **Security Event ID 4624**. Find out which account authenticated to a Windows computer, when the event was recorded, which source IP address was reported, and what type of logon occurred—**RDP, local console, network, service, batch**, and more.

Useful for **Windows Server security auditing**, investigating successful RDP logons, reviewing network authentication activity, and troubleshooting Windows sign-in events.

The script reads the **local Security event log**. It filters by event ID, time range, and optional logon type **inside the Windows Event Log query using XPath**, before applying `-MaxEvents`. Event fields are parsed from XML by field name instead of positional index.

> **Important:** Event ID 4624 does not necessarily represent a human signing in interactively. It can also describe network, service, or batch logons. For the history of RDP **reconnects and disconnects**, use [Get-RdpSessionHistory](../Get-RdpSessionHistory/).

## Features

- Reads **Windows Security Event ID 4624** from the local computer.
- Displays **Time, User, SourceIP, LogonType, and Workstation** in a compact table.
- Filters by time with `-Hours` (default: **24 hours**) or searches all retained events with `-All`.
- Filters by one or more logon types using friendly names or numeric IDs (`-LogonType`).
- Applies event ID, time, and logon type filtering at the event log query level through **XPath**.
- Limits matching records with `-MaxEvents` (default: **500** for time-limited searches).
- Exports detailed records to UTF-8 CSV with `-CsvPath`.
- Returns structured PowerShell objects for further analysis with `-PassThru`.
- Includes the user SID, account domain, authentication package, logon process, logon ID, and other available event fields.
- Requires no third-party PowerShell modules.

## Requirements

- Windows with `Get-WinEvent` (developed for **Windows PowerShell 5.1**).
- Permission to read the **Security** event log; an elevated PowerShell session may be required.
- Successful logon auditing enabled in Windows audit policy (for example, **Audit Logon: Success**).

## Quick start

Run the script from the directory containing `Get-SuccessfulLogons.ps1`:

```powershell
# Successful Windows logons during the last 24 hours (up to 500 events)
.\Get-SuccessfulLogons.ps1
```

## Usage examples

### Find successful RDP logons

```powershell
# RDP / RemoteInteractive (Logon Type 10) in the last 24 hours
.\Get-SuccessfulLogons.ps1 -LogonType RDP

# The same filter using its numeric ID
.\Get-SuccessfulLogons.ps1 -LogonType 10

# All retained successful RDP logon events
.\Get-SuccessfulLogons.ps1 -LogonType RDP -All
```

### Search by time range and logon type

```powershell
# Console, RDP, and unlock events over the last 48 hours
.\Get-SuccessfulLogons.ps1 -LogonType Console,RDP,Unlock -Hours 48

# Equivalent filter for Console and RDP using numeric IDs
.\Get-SuccessfulLogons.ps1 -LogonType 2,10 -Hours 48

# Network logons over the last 72 hours
.\Get-SuccessfulLogons.ps1 -LogonType Network -Hours 72
```

### Search all retained history

```powershell
# No time limit and no event-count limit
.\Get-SuccessfulLogons.ps1 -All

# The 1,000 most recent matching RDP events in the retained log
.\Get-SuccessfulLogons.ps1 -LogonType RDP -All -MaxEvents 1000
```

> `-All` cannot be combined with an explicitly supplied `-Hours`. Without an explicit `-MaxEvents`, `-All` has no event-count limit and may consume significant time and memory.

### Export successful logons to CSV

```powershell
# Export successful RDP logons over the last seven days
.\Get-SuccessfulLogons.ps1 -LogonType RDP -Hours 168 -CsvPath .\successful-logons.csv

# Export all retained successful logon records
.\Get-SuccessfulLogons.ps1 -All -CsvPath .\successful-logons.csv
```

### Filter and inspect PowerShell objects

```powershell
# Show logons from a specific reported source IP
.\Get-SuccessfulLogons.ps1 -PassThru |
    Where-Object SourceIP -eq '192.0.2.10' |
    Format-Table Time, User, SourceIP, LogonType

# Inspect all available fields for an RDP event
.\Get-SuccessfulLogons.ps1 -LogonType RDP -PassThru |
    Select-Object -First 1 |
    Format-List *
```

*`192.0.2.10` is a documentation-only example IP address.*

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Hours <int>` | `24` | Search the last 1–8,760 hours. Cannot be explicitly combined with `-All`. |
| `-MaxEvents <int>` | `500` | Retrieve up to 1–50,000 matching events. With `-All`, the limit applies only when explicitly provided. |
| `-All` | Off | Search all retained Event ID 4624 records, regardless of age. |
| `-LogonType <string[]>` | All types | Filter by one or more friendly names or numeric logon type IDs. |
| `-CsvPath <string>` | — | Export all parsed result properties to a UTF-8 CSV file. |
| `-PassThru` | Off | Return structured PowerShell objects rather than a formatted table. |

**Query behavior:** The XPath filter selects Event ID 4624, the requested time window, and the specified logon types before `-MaxEvents` is applied. For example, `-LogonType RDP -MaxEvents 10` selects up to ten **matching RDP logon records**, not ten arbitrary 4624 events.

## Supported Windows logon types

| ID | Values accepted by `-LogonType` | Meaning |
| --- | --- | --- |
| `0` | `System` | System logon. |
| `2` | `Console`, `Interactive` | Local interactive logon. |
| `3` | `Network`, `SMB` | Network logon; not limited to SMB. |
| `4` | `Batch`, `ScheduledTask` | Batch or scheduled-task logon. |
| `5` | `Service` | Service logon. |
| `7` | `Unlock` | Unlock of an existing session. |
| `8` | `NetworkCleartext` | NetworkCleartext logon. |
| `9` | `RunAs`, `NewCredentials` | NewCredentials logon. |
| `10` | `RDP`, `RemoteInteractive`, `RemoteDesktop` | Remote interactive logon, usually RDP. |
| `11` | `CachedInteractive` | Cached interactive logon. |
| `12` | `CachedRemoteInteractive` | Cached remote interactive logon. |
| `13` | `CachedUnlock` | Cached unlock. |

Numeric strings from `0` to `13` are accepted. Values without a defined friendly display label may appear as `Unknown (N)` in the output.

**Note:** Logon Type `3` indicates network authentication. It does **not** by itself prove an RDP logon attempt.

## Example output

```text
Time                User          SourceIP     LogonType Workstation
----                ----          --------     --------- -----------
14.11.2026 08:05:46 Administrator 192.0.2.10   RDP       CLIENT-PC
14.11.2026 08:07:12 SYSTEM                     Service
```

*Illustrative events; the source IP is reserved for documentation.*

## Output fields

The default table displays **Time, User, SourceIP, LogonType, and Workstation**. Use `-PassThru` or `-CsvPath` to access all parsed properties.

| Field | Description |
| --- | --- |
| `Time` | Timestamp of the successful logon event. |
| `User` | Account associated with the logon (`TargetUserName`). |
| `UserSID` | Security identifier of the target account, if present. |
| `SourceIP` | Source IP address as reported by Windows, when available. |
| `LogonType` | Short text label, such as `RDP`, `Console`, or `SMB/NTLM`. |
| `LogonTypeId` | Numeric Windows logon type (such as `3` or `10`). |
| `Workstation` | Source workstation name, when supplied by Windows. |
| `AccountDomain` | Domain or local computer context for the target account. |
| `AuthPackage` | Authentication package recorded in the event. |
| `LogonProcess` | Logon process recorded in the event. |
| `ImpersonationLevel` | Impersonation level value reported by Windows. |
| `ElevatedToken` | Original elevated-token field value; may be an encoded resource value. |
| `SubjectUser`, `SubjectDomain` | Account context that requested or initiated the logon, when recorded. |
| `TargetLogonId` | Logon ID recorded in the event. |
| `LogName`, `EventId` | Source log (`Security`) and event ID (`4624`). |
| `RecordID` | Event record identifier in the Security log. |

## Limitations and security considerations

- **Event ID 4624 does not necessarily mean a human accessed the machine.** Network, service, and batch logons may be recorded as successful logons.
- **RDP reconnections are not fully described by Event ID 4624.** To audit logons, reconnects, disconnects, and logoffs of RDP sessions, see [Get-RdpSessionHistory](../Get-RdpSessionHistory/) (LocalSessionManager Event IDs **21, 23, 24, and 25**). Security Events **4778** and **4779** can provide complementary evidence when audited.
- The script reads only the **local** Security event log; it does not query remote Windows servers.
- `-All` searches events **still retained** in the log, not the machine's complete lifetime history. Older events may have been overwritten or cleared.
- `SourceIP` and `Workstation` may be missing or show placeholder values. An absent IP address does not prove a local logon.
- A successful logon event does not, on its own, prove that a user subsequently performed actions in the session.
- Unrestricted `-All` queries can use significant memory on busy Windows servers.
- CSV exports may contain sensitive usernames, SIDs, internal IP addresses, and authentication metadata. Avoid committing real audit exports to a public repository.

## Running downloaded PowerShell scripts

Review scripts before executing them. If Windows blocks a downloaded script under the `RemoteSigned` execution policy, you may unblock a file you have reviewed:

```powershell
Unblock-File -Path .\Get-SuccessfulLogons.ps1
```

For more details, see [PowerShell Execution Policy](../../../README.md#powershell-execution-policy) in the main repository README.

To display built-in script help:

```powershell
Get-Help .\Get-SuccessfulLogons.ps1 -Detailed
```

## References

- [Microsoft Learn: 4624(S) — An account was successfully logged on](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4624)
- [Microsoft Learn: Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)

## Related scripts

- [Get-FailedLogonAttempts](../Get-FailedLogonAttempts/) — investigate failed Windows logon attempts (Security Event ID **4625**).
- [Get-RdpSessionHistory](../Get-RdpSessionHistory/) — audit RDP session logons, reconnects, disconnects, and logoffs.
