owerShell Scripts
A collection of practical PowerShell utilities for Windows Server administration, security auditing, troubleshooting, and infrastructure automation.

Each script focuses on a specific real-world administration task and includes its own README with usage examples, requirements, and limitations.
Scripts
Windows Security
Script	Description
[Get-FailedLogonAttempts](Windows/Security/Get-FailedLogonAttempts/)	Investigate failed Windows logon attempts (Security Event ID 4625), including usernames, source IPs, logon types, and failure reasons.
[Get-SuccessfulLogons](Windows/Security/Get-SuccessfulLogons/)	Audit successful Windows logons (Security Event ID 4624); filter console, RDP, network, and other logon types by name or ID.


Requirements
- Windows and an appropriate version of PowerShell (see each script's README).
- Permission to perform the requested operation or read the relevant Windows event log.
- Review scripts and their parameters before running them, particularly on production servers.
PowerShell Execution Policy
Windows may block PowerShell scripts downloaded from GitHub because they are not digitally signed.

1. Check the effective execution policy:
Get-ExecutionPolicy -List
2. If scripts are restricted and your environment permits it, use RemoteSigned for your user account:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
RemoteSigned allows locally created unsigned scripts but generally requires downloaded scripts to be signed or explicitly unblocked. Do not change organization-managed policies without authorization.

3. Review the downloaded script and unblock that specific file if necessary:
Unblock-File -Path ".\Get-SuccessfulLogons.ps1"
You can check whether it has an internet download marker before unblocking:
Get-Item ".\Get-SuccessfulLogons.ps1" -Stream Zone.Identifier -ErrorAction SilentlyContinue
4. Run the script from its own folder:
.\Get-SuccessfulLogons.ps1 -LogonType RDP -Hours 24
Scripts launched from network shares (UNC paths) can also be affected by Windows security zones. If appropriate, copy the script locally, review it, and unblock only that file.
Security note: Unblock-File does not verify a file's safety. Avoid disabling execution-policy checks globally with Bypass or Unrestricted. Group Policy may override user and machine settings, and execution policy is not a security boundary.

Official references: PowerShell execution policies · Unblock-File.
Contributing
Bug reports and suggested improvements are welcome through GitHub Issues. Please do not include real credentials, customer data, or sensitive event log exports.
Disclaimer
Scripts are provided as-is. Test them in a suitable environment before production use.