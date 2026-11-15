
# PowerShell Scripts

[![License](https://img.shields.io/github/license/ibarkov/powershell-scripts)](LICENSE)
![Windows](https://img.shields.io/badge/Platform-Windows-0078D4)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
[![Last Commit](https://img.shields.io/github/last-commit/ibarkov/powershell-scripts)](https://github.com/ibarkov/powershell-scripts/commits)
[![Security Policy](https://img.shields.io/badge/Security-Policy-blue)](SECURITY.md)

A collection of practical PowerShell utilities for **Windows Server administration, security auditing, troubleshooting, and infrastructure automation**.

Each script focuses on a specific real-world administration task and includes its own README with usage examples, requirements, and limitations.

## Scripts

### Windows Security

| Script | Description |
|---|---|
| [Get-FailedLogonAttempts](Windows/Security/Get-FailedLogonAttempts/) | Investigate failed Windows logon attempts (Security Event ID **4625**), including usernames, source IPs, logon types, and failure reasons. |
| [Get-SuccessfulLogons](Windows/Security/Get-SuccessfulLogons/) | Audit successful Windows logons (Security Event ID **4624**); filter console, RDP, network, and other logon types by name or ID. |
| [Get-RdpSessionHistory](Windows/Security/Get-RdpSessionHistory/) | View Windows RDP session history, including logons, reconnects, disconnects, and logoffs. Supports filtering by user, time range, and event type, with CSV export. |
| [Get-AccountLockoutEvents](Windows/Security/Get-AccountLockoutEvents/) | Audit Windows account lockouts (Security Event ID **4740**), identify locked accounts and caller computers, filter by username and time range, and export results to CSV. |

## Requirements

- Windows with a compatible version of PowerShell (see each script's README).
- Appropriate permissions to access the relevant Windows Event Logs.
- Administrator privileges may be required for reading Security event logs.

## PowerShell Execution Policy

Check your current execution policy:

```powershell
Get-ExecutionPolicy
```

If necessary, allow locally created scripts to run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

For scripts downloaded from GitHub, you may need to unblock the file:

```powershell
Unblock-File -Path .\script.ps1
```

Review scripts before executing them. Organizational Group Policy settings may override local execution policy settings.

## Usage

Each utility has its own README with instructions and examples. Open the script's folder to get started.

## Security

Found a security vulnerability?

Please read the [Security Policy](SECURITY.md) and report it privately.

Do not include credentials, sensitive account data, or production audit logs in public GitHub issues.

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Igor Barkov.
