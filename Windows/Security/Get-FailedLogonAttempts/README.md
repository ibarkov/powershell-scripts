Get-FailedLogonAttempts — Windows Failed Logon Audit (Event ID 4625)
A lightweight PowerShell script for finding failed Windows logon attempts in the local Security event log. It reads Event ID 4625 and displays the account name, source IP address, workstation, logon type, and reason for authentication failure.

Useful for Windows Server troubleshooting, investigating unsuccessful network logons, and reviewing failed RDP authentication attempts.
Features
- Searches Windows Security Event ID 4625.
- Displays Time, User, SourceIP, LogonType, Reason, and Workstation in a compact table.
- Decodes common Windows logon types and failure codes from event XML.
- Supports a configurable time window (-Hours, default: 24).
- Searches the entire retained Security log with -All.
- Limits the number of results with -MaxEvents when required.
- Exports all parsed fields to CSV with -CsvPath.
- Returns structured PowerShell objects for further filtering with -PassThru.
- Uses built-in Windows PowerShell functionality; no third-party modules required.
Requirements
- Windows with PowerShell and the Get-WinEvent cmdlet (developed for Windows PowerShell 5.1).
- Permission to read the Security event log (an elevated PowerShell session may be necessary).
- Failed logon auditing enabled in Windows security audit policy.
Usage
Run from the directory containing Get-FailedLogonAttempts.ps1.

Last 24 hours (default, up to 500 entries):
.\Get-FailedLogonAttempts.ps1
Last 72 hours (up to 1000 entries):
.\Get-FailedLogonAttempts.ps1 -Hours 72 -MaxEvents 1000
All available events (no time or event-count limit):
.\Get-FailedLogonAttempts.ps1 -All
All available history, limited to the most recent 1000 matching events:
.\Get-FailedLogonAttempts.ps1 -All -MaxEvents 1000
Export the last 24 hours to CSV:
.\Get-FailedLogonAttempts.ps1 -CsvPath .\failed-logons.csv
Export all retained matching events to CSV:
.\Get-FailedLogonAttempts.ps1 -All -CsvPath .\failed-logons.csv
Filter results by source IP address:
.\Get-FailedLogonAttempts.ps1 -All -PassThru |
    Where-Object SourceIP -eq '192.0.2.10'
View all fields in detail:
.\Get-FailedLogonAttempts.ps1 -MaxEvents 5 -PassThru | Format-List *
Output fields
Field	Description
Time	Timestamp of the failed logon event
User	Account used in the attempt
SourceIP	Source IP address, when provided by Windows
LogonType	Numeric Windows logon type (e.g., 3 or 10)
Reason	Decoded authentication failure reason
Workstation	Source workstation name, when available
AccountDomain	Account domain or local computer context reported by Windows
LogonTypeText	Human-readable logon type
AuthPackage	Authentication package (such as NTLM or Kerberos)
Status, SubStatus, ReasonCode	Original failure status codes
RecordID	Record identifier of the event in the Security log


The default table shows only the first six columns. Use -PassThru or -CsvPath to access the full dataset.
Understanding logon types
- Type 3 — Network: A network authentication attempt (for example SMB). It does not, by itself, prove an RDP login attempt.
- Type 10 — RemoteInteractive: A remote interactive logon, typically RDP.
For an RDP investigation, review the account, source address, logon type, and related Windows events together; do not classify every Type 3 event as RDP.
Limitations and safety
- The script reads only the local computer's Security log; it does not query remote servers.
- -All means all events still retained in that log, not all events since Windows was installed. Older records may have been overwritten or cleared.
- A large retained Security log can make unrestricted -All queries slower and more memory-intensive. Consider -All -MaxEvents 1000 first.
- SourceIP and Workstation may be empty or unavailable depending on the authentication scenario.
- Failure events are present only when the corresponding auditing is configured.
- CSV exports may contain sensitive infrastructure and account information. Review them before sharing.
If Windows blocks a reviewed script downloaded from the internet under RemoteSigned, remove its download mark using:
Unblock-File -Path .\Get-FailedLogonAttempts.ps1
PowerShell help
Get-Help .\Get-FailedLogonAttempts.ps1 -Detailed