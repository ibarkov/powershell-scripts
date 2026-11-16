# PowerShell Scripts

[![License](https://img.shields.io/github/license/ibarkov/powershell-scripts)](LICENSE)
![Windows](https://img.shields.io/badge/Platform-Windows-0078D4)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
[![Last Commit](https://img.shields.io/github/last-commit/ibarkov/powershell-scripts)](https://github.com/ibarkov/powershell-scripts/commits)
[![Security Policy](https://img.shields.io/badge/Security-Policy-blue)](SECURITY.md)

A collection of practical PowerShell utilities for **Windows Server administration, security auditing, troubleshooting, networking, and infrastructure automation**.

Each script focuses on a specific real-world administration task and includes its own README with usage examples, requirements, and limitations.

## Scripts

### Windows Security

| Script | Description |
|---|---|
| [Get-FailedLogonAttempts](Windows/Security/Get-FailedLogonAttempts/) | Investigate failed Windows logon attempts (Security Event ID **4625**), including usernames, source IPs, logon types, and failure reasons. |
| [Get-SuccessfulLogons](Windows/Security/Get-SuccessfulLogons/) | Audit successful Windows logons (Security Event ID **4624**); filter console, RDP, network, and other logon types by name or ID. |
| [Get-RdpSessionHistory](Windows/Security/Get-RdpSessionHistory/) | View Windows RDP session history, including logons, reconnects, disconnects, and logoffs. Supports filtering by user, time range, and event type, with CSV export. |
| [Get-AccountLockoutEvents](Windows/Security/Get-AccountLockoutEvents/) | Audit Windows account lockouts (Security Event ID **4740**), identify locked accounts and caller computers, filter by username and time range, and export results to CSV. |
| [Get-AccountAndGroupChanges](Windows/Security/Get-AccountAndGroupChanges/) | Audit Windows account and security group changes (Event IDs **4720, 4722, 4725, 4726, 4738, 4728, 4729, 4732, 4733, 4756, 4757**), including account changes and membership changes in Administrators and other security groups. |

### Windows Network

| Script | Description |
|---|---|
| [Get-PortUsage](Windows/Network/Get-PortUsage/) | Identify processes using local TCP and UDP ports, including PID, process name, owner, executable path, and command line. Filter by port, protocol, TCP state, process name, and remote TCP address; export to CSV. |

## Requirements

- Windows with a compatible version of PowerShell (see each script's README).
- Appropriate permissions to access relevant Windows Event Logs and system/network information.
- Administrator privileges may be required for reading Security event logs or retrieving process owners and command lines.
- Required Windows audit policies enabled for security-event-based scripts.

## PowerShell Execution Policy

Check the current execution policy:

```powershell
Get-ExecutionPolicy
```

If necessary, allow locally created scripts to run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

For a script downloaded from GitHub, you may need to unblock the file after reviewing it:

```powershell
Unblock-File -Path .\script.ps1
```

Organizational Group Policy settings may override local execution policy settings.

## Usage

Each utility has its own README with instructions, supported parameters, examples, and known limitations.

Open the script's folder to get started. Scripts can be executed independently; installing the entire collection is not required.

## Security

Found a security vulnerability? Please read the [Security Policy](SECURITY.md) and report it privately.

Do not include credentials, sensitive account data, production audit logs, or unreviewed process command lines in public GitHub issues or CSV attachments.

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Igor Barkov.
