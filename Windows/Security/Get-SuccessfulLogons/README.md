Get-SuccessfulLogons.ps1
A lightweight PowerShell utility for auditing successful Windows logons (Security Event ID 4624). See who authenticated to a Windows machine, when, from which reported IP address, and using which logon type (console, network, RDP, service, and more).

The script reads the local Windows Security event log. It uses an XPath query to filter by event ID, time range, and optional logon type before applying the event count limit. Event fields are parsed by their XML names, rather than by positional indexes.
Features
- Find successful authentication events (Windows Security Event ID 4624).
- Filter by time (-Hours) or search all retained events (-All).
- Select one or more logon types by friendly name or numeric ID (-LogonType).
- Limit matching events with -MaxEvents (500 by default for time-limited searches).
- View a compact table or return PowerShell objects with -PassThru.
- Export detailed records to CSV with -CsvPath.
- Include user SID, account domain, source IP, workstation, authentication package, logon process, logon ID, and event record ID when available.
- Use built-in Windows PowerShell commands; no third-party modules required.
Requirements
- Windows with a readable Security event log and enabled successful logon auditing.
- Windows PowerShell 5.1 (the script uses Get-WinEvent and standard PowerShell features; test separately if using PowerShell 7).
- An account permitted to read the Security log; an elevated PowerShell window may be required.
Review downloaded scripts before executing them. If Windows blocks an unsigned file downloaded from GitHub, see the [execution policy instructions](../../../README.md#powershell-execution-policy) in the repository root.

Usage
Run the following commands from the directory containing Get-SuccessfulLogons.ps1.

All logon types from the last 24 hours (up to 500 events):
.\Get-SuccessfulLogons.ps1
Successful RDP logons from the last 24 hours:
.\Get-SuccessfulLogons.ps1 -LogonType RDP
Console, RDP, and unlock events from the last 48 hours:
.\Get-SuccessfulLogons.ps1 -LogonType Console,RDP,Unlock -Hours 48
Equivalent numeric filter (Logon Types 2 and 10):
.\Get-SuccessfulLogons.ps1 -LogonType 2,10 -Hours 48
All retained RDP logon events:
.\Get-SuccessfulLogons.ps1 -LogonType RDP -All
At most 10 matching RDP events from the retained log:
.\Get-SuccessfulLogons.ps1 -LogonType RDP -All -MaxEvents 10
Export the collected results to CSV:
.\Get-SuccessfulLogons.ps1 -LogonType RDP -Hours 168 -CsvPath .\successful-logons.csv
Filter results by source IP:
.\Get-SuccessfulLogons.ps1 -PassThru |
    Where-Object SourceIP -eq '192.0.2.10' |
    Format-Table Time, User, SourceIP, LogonType
Inspect every returned field:
.\Get-SuccessfulLogons.ps1 -LogonType RDP -PassThru |
    Select-Object -First 1 |
    Format-List *
To inspect the available help:
Get-Help .\Get-SuccessfulLogons.ps1 -Detailed
Parameters
Parameter	Description	Default
-Hours	Search the last N hours (1–8760); cannot be combined with -All.	24
-MaxEvents	Maximum number of matching events to retrieve (1–50000).	500 with time-limited searches
-All	Search all retained 4624 events, without a time filter.	Off
-LogonType	One or more friendly names or numeric logon types.	All types
-CsvPath	Optional path for a CSV export of all returned fields.	None
-PassThru	Return structured PowerShell objects instead of a formatted table.	Off


When -All is used without an explicit -MaxEvents, the script does not impose a count limit. It warns that the query may be slow or memory-intensive on a busy server.
Supported logon types
ID	Friendly names accepted by -LogonType	Meaning
0	System	System logon
2	Console, Interactive	Local interactive logon
3	SMB, Network	Network logon (not necessarily SMB or RDP)
4	Batch, ScheduledTask	Batch or scheduled task
5	Service	Service logon
7	Unlock	Unlock of an existing session
8	NetworkCleartext	NetworkCleartext logon
9	RunAs, NewCredentials	NewCredentials logon
10	RDP, RemoteInteractive, RemoteDesktop	Remote interactive logon
11	CachedInteractive	Cached interactive logon
12	CachedRemoteInteractive	Cached remote interactive logon
13	CachedUnlock	Cached unlock


The parameter also accepts numeric strings from 0 to 13. Some values do not have dedicated friendly labels in the output and may appear as Unknown (N).
Output
The default table shows:

Time, User, SourceIP, LogonType, Workstation.

Use -PassThru or -CsvPath to access additional fields such as UserSID, AccountDomain, LogonTypeId, AuthPackage, LogonProcess, ElevatedToken, SubjectUser, SubjectDomain, TargetLogonId, LogName, EventId, and RecordID.
Important limitations
- 4624 means a successful Windows logon event, not necessarily a person physically or interactively accessing the machine. Network, batch, and service logons are included unless filtered out.
- RDP session history is a separate question. A new RDP logon can be recorded as type 10, but reconnecting to an existing session does not necessarily create another type-10 event. For session logon, disconnect, reconnect, and logoff, inspect Microsoft-Windows-TerminalServices-LocalSessionManager/Operational (notably IDs 21, 23, 24, 25); Security events 4778 and 4779 can provide additional evidence where audited.
- SourceIP and Workstation may be missing or shown as placeholders. Missing values do not imply a local login.
- The command reads only the local machine. It does not query remote servers.
- -All means all events still retained in the Windows Security log, not all activity since Windows was installed. Older records may already have been overwritten.
- The CSV may contain sensitive usernames, SIDs, IP addresses, and authentication metadata. Store or share it appropriately and do not commit real audit exports to a public repository.
Reference
- Microsoft: Event 4624 — An account was successfully logged on
- Microsoft: Get-WinEvent
License
See the license file at the repository root, if provided.