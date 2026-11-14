Get-RdpSessionHistory
A PowerShell script for viewing Windows Remote Desktop session history: session logons, reconnects, disconnects, and logoffs.

Unlike a query for Security Event ID 4624 (Logon Type 10), this script also captures reconnections to existing sessions. It reads events from the local Windows TerminalServices-LocalSessionManager/Operational log and displays the account, source address (when recorded), session ID, and action.
Scope: This is a history of recorded session lifecycle events, not a complete record of every RDP network connection or an authoritative count of unique sessions. Local/console session events may also appear in this log.

Features
- Displays session Logon, Reconnect, Disconnect, and Logoff events.
- Filters by time range, username, and action.
- Supports short usernames (Administrator), domain-qualified usernames (CONTOSO\\Administrator), and wildcard matching.
- Extracts fields from UserData/EventXML, with EventData as a fallback.
- Keeps original source addresses, including LOCAL; does not invent missing IP addresses or workstation names.
- Supports CSV export and PowerShell object output for further analysis.
- Shows event counts by action, unless -NoSummary or -PassThru is used.
Requirements
- Windows with the Microsoft-Windows-TerminalServices-LocalSessionManager/Operational event log available.
- Windows PowerShell 5.1 (or a compatible PowerShell version with Get-WinEvent).
- Permission to read the operational event log; elevated PowerShell may be necessary depending on system permissions.
- Relevant event logging must be enabled, and the events must still be retained in the log.
No external PowerShell modules are required.
Usage
Run the script in PowerShell from the directory where it is saved:
# Session history from the last 24 hours (default)
.\Get-RdpSessionHistory.ps1

# Session history from the last 72 hours
.\Get-RdpSessionHistory.ps1 -Hours 72

# All events currently retained in the event log
.\Get-RdpSessionHistory.ps1 -All

# Events for a specific user (short or domain-qualified name)
.\Get-RdpSessionHistory.ps1 -Hours 168 -User Administrator
.\Get-RdpSessionHistory.ps1 -All -User 'CONTOSO\Administrator'

# Only reconnection events
.\Get-RdpSessionHistory.ps1 -Hours 72 -Action Reconnect

# Multiple action types
.\Get-RdpSessionHistory.ps1 -Action Logon,Reconnect -Hours 168

# Limit to the five most recent matching events for a user
.\Get-RdpSessionHistory.ps1 -All -User Administrator -MaxEvents 5

# Export to CSV
.\Get-RdpSessionHistory.ps1 -Hours 168 -CsvPath .\rdp-history.csv

# Return objects and filter by source IP
.\Get-RdpSessionHistory.ps1 -Hours 72 -PassThru |
    Where-Object SourceIP -eq '192.0.2.10'

# Suppress the summary
.\Get-RdpSessionHistory.ps1 -Hours 24 -NoSummary

# View more details
.\Get-RdpSessionHistory.ps1 -Hours 24 -PassThru |
    Format-List *
-All and an explicitly specified -Hours cannot be combined.
Parameters
Parameter	Type	Default	Description
-Hours	Int32	24	Look back 1–8,760 hours; cannot be explicitly combined with -All.
-MaxEvents	Int32	500	Maximum matching events (1–50,000). For -All, it applies only when explicitly supplied.
-All	Switch	Off	Search all retained events regardless of age.
-User	String	—	Filter by short or domain-qualified username; case-insensitive, supports wildcards.
-Action	String[]	All four	Filter by Logon, Reconnect, Disconnect, and/or Logoff.
-CsvPath	String	—	Export all result fields to a UTF-8 CSV file.
-PassThru	Switch	Off	Return structured PowerShell objects rather than a formatted table; suppresses summary output.
-NoSummary	Switch	Off	Hide the summary block in normal table mode.


-MaxEvents behavior
- With a time-limited search and no -User, Get-WinEvent applies the event limit during retrieval.
- With -User, the script loads the matching event IDs for the selected period, filters by username, then takes the latest -MaxEvents matching records. This can require more memory on large logs.
- With -All and no explicit -MaxEvents, all retained matching events are read and a warning is displayed.
- Results are displayed in chronological order (oldest to newest), even when the most recent events are selected.
Event IDs
Events are read from:

Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
Event ID	Action	Meaning
21	Logon	Session logon succeeded.
23	Logoff	Session logoff succeeded.
24	Disconnect	Session was disconnected without necessarily logging the user off.
25	Reconnect	Connection to an existing session succeeded.


A Disconnect is not the same as a Logoff: the Windows session may continue to exist after the client disconnects.
Example output
Time                User          SourceAddress   SessionID Action
----                ----          -------------   --------- ------
13.11.2026 15:55:27 Administrator 192.0.2.10              2 Reconnect
13.11.2026 16:11:58 Administrator 192.0.2.10              2 Disconnect
14.11.2026 08:05:46 Administrator 192.0.2.20              3 Logon

Summary: 3 event(s), 2026-11-13 15:55:27 .. 2026-11-14 08:05:46

Action     Count
------     -----
Disconnect     1
Logon          1
Reconnect      1
Example uses documentation-only IP addresses and illustrative events.
Output properties
The default table shows Time, User, SourceAddress, SessionID, and Action. With -PassThru or -CsvPath, the following fields are also available:
Property	Description
Time	Event timestamp in the server's local time.
User	Account name without the domain prefix, when one is present.
Domain	Domain or computer name from the recorded account name, if present.
SourceAddress	Original recorded address; may be an IP address, LOCAL, or empty.
SourceIP	Recorded address excluding LOCAL; empty when the source is LOCAL or missing. The value is not validated as an IP address.
SessionID	Windows session identifier recorded by the event.
Action	Logon, Reconnect, Disconnect, or Logoff.
Server	Computer that generated the event.
Workstation	Client workstation name if actually present in the event; otherwise empty.
EventID	Windows event ID: 21, 23, 24, or 25.
LogName	Name of the source Windows event log.
RecordID	Event record identifier in that log.


Important limitations
- Only retained events are available. The history depends on event log configuration, retention limits, and whether the log has been cleared.
- Session IDs are reused. An ID such as 2 seen in different months or years does not refer to one continuous session.
- A source address may be missing. The script leaves missing values empty and preserves LOCAL rather than converting it to 127.0.0.1.
- Not all records represent remote access. The LocalSessionManager log can include local/console activity.
- A summary counts event records, not unique sessions or distinct connections. The counts cover only the selected events after filters and limits.
- -User is a post-retrieval filter. Large retained logs may use significant memory or take longer to process.
- No attempt is made to correlate events into unique sessions or reconstruct a complete audit trail from other Windows logs.
For successful Windows logon events across different logon types, use [`Get-SuccessfulLogons.ps1`](../Get-SuccessfulLogons/). For complementary reconnect/disconnect evidence, Windows Security events 4778 and 4779 may be useful if the relevant auditing is enabled.
Troubleshooting
No matching events: Check the selected time range and action filter. Try -All -MaxEvents 50; the log may contain no retained events for the period.

Access denied: Run PowerShell with an account permitted to read the event log; elevation may be required.

SourceAddress or Workstation is empty: These fields are not guaranteed to be present in every event. This is expected and does not necessarily indicate a parsing error.

To inspect the raw event payload:
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
    Id      = 21,23,24,25
} -MaxEvents 1 | ForEach-Object { $_.ToXml() }