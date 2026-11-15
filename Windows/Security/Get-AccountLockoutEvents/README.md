# Get-AccountLockoutEvents.ps1 — Windows Account Lockout Audit (Event ID 4740)

A lightweight PowerShell script for investigating **Windows account lockouts** using **Security Event ID 4740**. Find out **which account was locked**, **when it happened**, and **which caller computer Windows recorded**. The script also reports the computer that logged the event and summarizes lockouts by caller computer.

Useful for Windows Server troubleshooting, local account lockout investigations, and Active Directory account lockout auditing on domain controllers.

> **Scope:** Event ID 4740 records the lockout itself. It does **not** identify the exact process, incorrect password, or root cause. Investigate related authentication failures to determine why an account was locked.

## Features

- Reads **Security Event ID 4740** from the local Windows computer.
- Displays **Time, User, Domain, CallerComputer, and Server** in a compact table, newest first.
- Searches a configurable time window with `-Hours` (default: **24 hours**).
- Searches all **retained** lockout events with `-All`.
- Limits results with `-MaxEvents` (default: **500** for time-limited searches).
- Filters by the **locked account** with `-User` (short username, `DOMAIN\username`, or wildcard pattern).
- Shows a **Lockouts by caller computer** summary; suppress it with `-NoSummary`.
- Exports detailed records to UTF-8 CSV with `-CsvPath`.
- Returns structured PowerShell objects with `-PassThru`.
- Uses built-in Windows PowerShell functionality; **no Active Directory module or third-party modules required**.

## Requirements

- Windows with `Get-WinEvent` (developed for **Windows PowerShell 5.1**).
- Permission to read the local **Security** event log; an elevated session may be required.
- **Audit User Account Management (Success)** enabled and matching events still retained.

For **local accounts**, run the script on the computer that owns the account. For **domain accounts**, run it on a domain controller that recorded the lockout; investigating an entire domain may require checking multiple domain controllers.

## Quick start

Run the script from its directory:

```powershell
# Lockouts during the last 24 hours (up to 500 records)
.\Get-AccountLockoutEvents.ps1
```

## Usage examples

### Search by time range

```powershell
# Lockouts in the last seven days
.\Get-AccountLockoutEvents.ps1 -Hours 168

# Last seven days, without the summary
.\Get-AccountLockoutEvents.ps1 -Hours 168 -NoSummary
```

### Search all retained events

```powershell
# Every retained Event ID 4740 record (no count limit)
.\Get-AccountLockoutEvents.ps1 -All

# Up to 20 of the most recent retained lockouts
.\Get-AccountLockoutEvents.ps1 -All -MaxEvents 20
```

> `-All` and an explicitly supplied `-Hours` cannot be combined. `-All` only includes events still present in the Security log; an unlimited query may consume significant time or memory.

### Filter by locked account

```powershell
# Short username (case-insensitive)
.\Get-AccountLockoutEvents.ps1 -All -User TEST

# Domain-qualified username; requires successful SID-to-name resolution
.\Get-AccountLockoutEvents.ps1 -Hours 168 -User 'CONTOSO\jdoe'

# Wildcard matching
.\Get-AccountLockoutEvents.ps1 -Hours 168 -User 'admin*'
```

The `-User` filter matches the **locked account** (`TargetUserName`), not the event's subject account. When `-User` is specified, the script filters by username *before* applying `-MaxEvents`, so it may need to read more events.

### Export to CSV

```powershell
# Export up to 100 matching lockouts from the retained log
.\Get-AccountLockoutEvents.ps1 -All -MaxEvents 100 -CsvPath .\lockouts.csv

# Inspect the exported fields
Import-Csv .\lockouts.csv | Format-List *
```

### Filter and inspect PowerShell objects

```powershell
# Filter by the caller computer recorded by Windows
.\Get-AccountLockoutEvents.ps1 -Hours 168 -PassThru |
    Where-Object CallerComputer -eq 'CLIENT01'

# Show every field for up to five records
.\Get-AccountLockoutEvents.ps1 -All -MaxEvents 5 -PassThru |
    Format-List *
```

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Hours <int>` | `24` | Search the last 1–8,760 hours. Cannot be explicitly combined with `-All`. |
| `-All` | Off | Search all retained Event ID 4740 records without a time limit. |
| `-MaxEvents <int>` | `500` | Limit to 1–50,000 matching records. With `-All`, only applies if explicitly specified. |
| `-User <string>` | — | Filter by locked username; supports wildcards and `DOMAIN\username` when SID resolution succeeds. |
| `-NoSummary` | Off | Suppress the caller-computer summary in the normal table view. |
| `-CsvPath <string>` | — | Export selected records, including all properties, as UTF-8 CSV. |
| `-PassThru` | Off | Return PowerShell objects instead of the formatted table; suppresses the summary. |

### How `-MaxEvents` works

- **Without `-User`:** `Get-WinEvent` applies the result limit during retrieval.
- **With `-User`:** events are retrieved and parsed, filtered by account, and then limited to the newest matching records. Large logs may require more memory.
- **With `-All` and no explicit `-MaxEvents`:** every retained matching event is read and a warning is displayed.
- Display and CSV results are sorted **newest first**.

## Example output

```text
Time                User Domain      CallerComputer Server
----                ---- ------      -------------- ------
15.11.2026 10:59:43 TEST WIN-TEST01  WIN-TEST01     WIN-TEST01

Lockouts by caller computer (1 selected event(s)):

CallerComputer Count
-------------- -----
WIN-TEST01         1
```

*Illustrative hostname and account name; this layout was verified against a local-account lockout test.*

## Output fields

The default table shows **Time, User, Domain, CallerComputer, and Server**. Use `-PassThru` or `-CsvPath` to access the complete result.

| Field | Description |
| --- | --- |
| `Time` | Time the lockout event was recorded. |
| `User` | Locked account name (`TargetUserName`). |
| `Domain` | Domain or computer name **resolved from `TargetSid`**, if available; otherwise empty. |
| `CallerComputer` | Computer name associated with the attempt that led to the lockout; in standard 4740 XML, stored in `TargetDomainName`. |
| `UserSID` | SID of the locked account (`TargetSid`). |
| `SubjectUser` | Account that recorded/performed the lockout operation, often a computer or system account. |
| `SubjectDomain` | Domain recorded for the subject account. |
| `SubjectSID` | SID of the subject account. |
| `SubjectLogonId` | Subject's logon ID as recorded in the event. |
| `Server` | Computer that generated the Security event. |
| `EventID` | Windows Event ID (`4740`). |
| `LogName` | Event log name (`Security`). |
| `RecordID` | Record identifier within that Security log. |

**Important:** The XML field `TargetDomainName` in **Event ID 4740** represents the *Caller Computer Name*, **not** the locked user's domain. This script attempts to resolve the locked account's domain from `TargetSid` separately.

## Understanding account lockouts

Event ID **4740** reports an account lockout. A caller computer can help narrow down an investigation, but it does **not** prove which program or person caused the lockout. Repeated failures can come from an incorrect password, cached credentials, a Windows service, a scheduled task, or other authentication activity.

For root-cause investigation, correlate the timestamp and account with other relevant events, including:

| Event ID | What it can reveal |
| --- | --- |
| `4625` | Failed Windows logon and failure status codes. |
| `4771` | Kerberos pre-authentication failures. |
| `4776` | NTLM credential validation attempts. |

These events may be recorded on different systems and require the corresponding audit settings.

## Limitations and security considerations

- Reads **only the local Security log**. It does not query other servers or domain controllers.
- An absence of events does not prove that no account lockouts occurred; auditing, retention, and the selected computer matter.
- `-All` searches only retained records. Older events may have been overwritten or cleared.
- `CallerComputer` is the Windows-recorded computer name, **not an IP address** or a verified identification of the process responsible.
- `Domain` may be empty if the SID cannot be resolved; `DOMAIN\username` filtering then may not match, while a short username can still match.
- Summary counts represent **selected event records**, not unique users, password attempts, or confirmed root causes.
- Large queries using `-User` or unlimited `-All` may be memory-intensive.
- CSV exports may contain account names, SIDs, and computer names. Do not publish real audit exports in a public repository.
- This script is **read-only**; it does not unlock accounts or modify account lockout policies.

## Troubleshooting

**No matching events:** Confirm the time window, username, auditing policy, and whether you are querying the computer that recorded the lockout. Try:

```powershell
.\Get-AccountLockoutEvents.ps1 -All -MaxEvents 20
```

**Access denied:** Run with a user permitted to read the Security log; elevation may be required.

**Unknown domain:** SID resolution can fail when the relevant account domain or trust is unavailable. Try filtering with the short username.

**Inspect a raw event:**

```powershell
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4740 } -MaxEvents 1 |
    ForEach-Object { $_.ToXml() }
```

To see the script's built-in help:

```powershell
Get-Help .\Get-AccountLockoutEvents.ps1 -Detailed
```

## Testing status

Tested with a **local Windows account lockout**: event retrieval, time and user filtering, structured output (`-PassThru`), caller-computer summary, and CSV export. **Domain account lockouts on Active Directory domain controllers have not yet been tested.**

## Related scripts

- [Get-FailedLogonAttempts](../Get-FailedLogonAttempts/) — audit failed Windows logons (Security Event ID **4625**).
- [Get-SuccessfulLogons](../Get-SuccessfulLogons/) — audit successful Windows logons (Security Event ID **4624**).
- [Get-RdpSessionHistory](../Get-RdpSessionHistory/) — review session logons, reconnects, disconnects, and logoffs.

## References

- [Microsoft Learn: Event 4740 — A user account was locked out](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4740)
- [Microsoft Learn: Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)
