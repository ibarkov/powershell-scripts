# Get-RdpSessionHistory.ps1 — Windows RDP Session History (Event IDs 21, 23, 24, 25)

A lightweight PowerShell script for auditing **Windows Remote Desktop (RDP) session history**. Find when users logged on, reconnected, disconnected, or logged off, along with the recorded username, client address, and Windows session ID.

The script reads the local **Microsoft-Windows-TerminalServices-LocalSessionManager/Operational** event log. Unlike querying Security Event ID **4624** with Logon Type **10**, it can show reconnections to an existing session—not just new logons.

> **Scope:** This is a history of *recorded session lifecycle events*, not a complete history of every RDP network connection or a count of unique sessions. The log may also contain local/console session activity.

## Features

- Reads Windows session events **21 (Logon), 23 (Logoff), 24 (Disconnect), and 25 (Reconnect)**.
- Shows **Time, User, SourceAddress, SessionID, and Action** in a compact table.
- Filters by time range (`-Hours`), username (`-User`), or action (`-Action`).
- Matches short usernames (`Administrator`), domain-qualified names (`CONTOSO\Administrator`), and wildcard patterns.
- Parses **UserData/EventXML** fields, with **EventData** as a fallback.
- Preserves original addresses, including `LOCAL`, and leaves unavailable values empty.
- Exports detailed records to UTF-8 CSV with `-CsvPath`.
- Returns structured PowerShell objects with `-PassThru` for additional filtering.
- Displays a summary of event counts by action (unless suppressed).
- Requires no third-party PowerShell modules.

## Requirements

- Windows with the `Microsoft-Windows-TerminalServices-LocalSessionManager/Operational` event log available.
- **Windows PowerShell 5.1** or a compatible PowerShell version with `Get-WinEvent`.
- Permission to read the event log; elevation may be required in some environments.
- Relevant event logging enabled and matching events still retained.

## Quick start

Save `Get-RdpSessionHistory.ps1` and run it in PowerShell:

```powershell
# RDP session events recorded in the last 24 hours (up to 500 events)
.\Get-RdpSessionHistory.ps1
```

## Usage examples

### Search by time range

```powershell
# Session history for the last 72 hours
.\Get-RdpSessionHistory.ps1 -Hours 72

# Session history for the last 7 days
.\Get-RdpSessionHistory.ps1 -Hours 168
```

### Search all retained history

```powershell
# All retained matching session events; no count limit
.\Get-RdpSessionHistory.ps1 -All

# The 1,000 most recent matching events
.\Get-RdpSessionHistory.ps1 -All -MaxEvents 1000
```

> `-All` and an explicitly supplied `-Hours` cannot be combined. `-All` searches only the records still present in the log.

### Filter by username

```powershell
# Short username
.\Get-RdpSessionHistory.ps1 -Hours 168 -User Administrator

# Domain-qualified username
.\Get-RdpSessionHistory.ps1 -All -User 'CONTOSO\Administrator'

# The five most recent events for this user
.\Get-RdpSessionHistory.ps1 -All -User Administrator -MaxEvents 5
```

The `-User` parameter is case-insensitive and accepts wildcards. The username filter is applied **after reading and parsing** events, so a user-specific search may process more than `-MaxEvents` records.

### Filter by session action

```powershell
# Only successful reconnects
.\Get-RdpSessionHistory.ps1 -Hours 72 -Action Reconnect

# New logons and reconnects
.\Get-RdpSessionHistory.ps1 -Hours 168 -Action Logon,Reconnect
```

### Export RDP session history to CSV

```powershell
# Export session history for the last seven days
.\Get-RdpSessionHistory.ps1 -Hours 168 -CsvPath .\rdp-history.csv

# Export all retained events
.\Get-RdpSessionHistory.ps1 -All -CsvPath .\rdp-history.csv
```

### Filter output in PowerShell

```powershell
# Show events with a specific recorded client IP address
.\Get-RdpSessionHistory.ps1 -Hours 72 -PassThru |
    Where-Object SourceIP -eq '192.0.2.10'

# Inspect all available fields
.\Get-RdpSessionHistory.ps1 -Hours 24 -PassThru |
    Format-List *
```

### Hide the summary

```powershell
.\Get-RdpSessionHistory.ps1 -NoSummary
```

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Hours <int>` | `24` | Look back 1–8,760 hours. Cannot be explicitly combined with `-All`. |
| `-MaxEvents <int>` | `500` | Limit to 1–50,000 matching events. With `-All`, a limit is applied only if explicitly supplied. |
| `-All` | Off | Search all retained matching events, regardless of age. |
| `-User <string>` | — | Filter by short or domain-qualified username; supports case-insensitive wildcards. |
| `-Action <string[]>` | All four actions | Filter by `Logon`, `Reconnect`, `Disconnect`, and/or `Logoff`. |
| `-CsvPath <string>` | — | Export all result properties to a UTF-8 CSV file. |
| `-PassThru` | Off | Return PowerShell objects instead of a formatted table; also suppresses the summary. |
| `-NoSummary` | Off | Hide the summary when displaying the default table. |

### How `-MaxEvents` works

- Without `-User`, `Get-WinEvent` applies the limit while retrieving events.
- With `-User`, the script retrieves the matching event IDs, parses and filters them by username, then keeps the latest `-MaxEvents` records. This can require more memory on large logs.
- With `-All` and no explicit `-MaxEvents`, the script reads all retained matching records and displays a warning.
- Selected results are displayed in **chronological order (oldest first)**.

## Windows event IDs

Events are read from:

```text
Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
```

| Event ID | Action | Meaning |
| --- | --- | --- |
| `21` | Logon | A session logon succeeded. |
| `23` | Logoff | A session logoff succeeded. |
| `24` | Disconnect | A session was disconnected; the user session may continue to exist. |
| `25` | Reconnect | Reconnection to an existing session succeeded. |

**Disconnect is not Logoff:** closing the RDP client can leave the Windows session running. Some records in this log can describe local sessions rather than remote access.

## Example output

```text
Time                User          SourceAddress  SessionID Action
----                ----          -------------  --------- ----------
13.11.2026 15:55:27 Administrator 192.0.2.10             2 Reconnect
13.11.2026 16:11:58 Administrator 192.0.2.10             2 Disconnect
14.11.2026 08:05:46 Administrator 192.0.2.20             3 Logon

Summary: 3 event(s), 2026-11-13 15:55:27 .. 2026-11-14 08:05:46

Action     Count
------     -----
Disconnect     1
Logon          1
Reconnect      1
```

*Illustrative data; `192.0.2.0/24` addresses are reserved for documentation.*

## Output fields

The default table displays **Time, User, SourceAddress, SessionID, and Action**. Use `-PassThru` or `-CsvPath` to access all properties.

| Field | Description |
| --- | --- |
| `Time` | Event timestamp in the server's local time. |
| `User` | Account name without the domain prefix, if one was recorded. |
| `Domain` | Domain or computer name parsed from the account name, when present. |
| `SourceAddress` | Original address from the event; may be an IP address, `LOCAL`, or empty. |
| `SourceIP` | Recorded address excluding `LOCAL`; empty if missing or local. The value is not independently validated as an IP address. |
| `SessionID` | Session identifier recorded by Windows. |
| `Action` | `Logon`, `Reconnect`, `Disconnect`, or `Logoff`. |
| `Server` | Computer that generated the event. |
| `Workstation` | Client workstation name, only if explicitly present in the event. |
| `EventID` | Windows event identifier: `21`, `23`, `24`, or `25`. |
| `LogName` | Source Windows event log. |
| `RecordID` | Record identifier within that log. |

## Limitations and security considerations

- The script reads the **local computer's event log only**; it does not query remote servers.
- Only **retained records** are available. Older events may have been overwritten or the log may have been cleared.
- **Session IDs are reused.** `SessionID = 2` in different months does not imply one continuous session.
- `SourceAddress` can be absent or show `LOCAL`. The script does not substitute `127.0.0.1` or invent a workstation name.
- **Not every event represents remote access:** the LocalSessionManager log can include local/console session activity.
- Summary counts reflect the **selected event records after filters and limits**, not unique sessions or distinct network connections.
- `-User` filters after retrieval and may be slower or use more memory on large logs.
- The script does not correlate records across Windows logs or reconstruct complete RDP session timelines.
- CSV files may contain account names and internal network addresses. Review them before sharing.

For complementary RDP reconnect/disconnect evidence, Windows Security events **4778** and **4779** may be useful when the corresponding auditing is enabled.

## Troubleshooting

**No matching events:** Check the period, username, and action filters. Try:

```powershell
.\Get-RdpSessionHistory.ps1 -All -MaxEvents 50
```

**Access denied:** Use an account permitted to read the operational event log; elevation may be necessary.

**SourceAddress or Workstation is empty:** These fields are not available for every event. Missing values do not necessarily indicate a parsing error.

**Inspect a raw event:**

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
    Id      = 21,23,24,25
} -MaxEvents 1 | ForEach-Object {
    $_.ToXml()
}
```

## Related scripts

- [Get-SuccessfulLogons](../Get-SuccessfulLogons/) — audit successful Windows logons using Security Event ID **4624** and logon types such as RDP (Type 10).
- [Get-FailedLogonAttempts](../Get-FailedLogonAttempts/) — investigate failed Windows logon attempts using Security Event ID **4625**.

To display built-in script help:

```powershell
Get-Help .\Get-RdpSessionHistory.ps1 -Detailed
```
