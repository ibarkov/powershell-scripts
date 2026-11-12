# PowerShell Scripts

A collection of practical PowerShell scripts for Windows Server administration, troubleshooting, security auditing, and infrastructure automation.

Each script solves a specific real-world IT administration task.


## Scripts

### Windows Security

| Script | Description |
|---|---|
| [Get-FailedLogonAttempts](Windows/Security/Get-FailedLogonAttempts/) | Analyze failed Windows logon attempts (Event ID 4625), including source IP addresses, usernames, and authentication failure reasons. |


## Requirements

- Windows PowerShell 5.1 or PowerShell 7, depending on the script
- Appropriate permissions for the target operation
- See individual script documentation for specific requirements

## PowerShell Execution Policy

Windows may block PowerShell scripts downloaded from GitHub or other internet sources if they are not digitally signed.

### 1. Check the current execution policy

Open PowerShell and run:

```powershell
Get-ExecutionPolicy -List
```

### 2. Enable local script execution

If script execution is restricted, you can enable the `RemoteSigned` policy for your current user:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

`RemoteSigned` allows locally created unsigned scripts to run while requiring downloaded scripts to be signed or explicitly unblocked.

Administrator privileges are not required when changing the `CurrentUser` scope.

### 3. Unblock downloaded scripts

If you see the following error:

```text
File cannot be loaded because it is not digitally signed.
```

You can unblock the downloaded script:

```powershell
Unblock-File -Path ".\Get-FailedLogonAttempts.ps1"
```

Then run it:

```powershell
.\Get-FailedLogonAttempts.ps1
```

To check whether a file is marked as downloaded from the internet:

```powershell
Get-Item ".\Get-FailedLogonAttempts.ps1" -Stream Zone.Identifier -ErrorAction SilentlyContinue
```

### 4. Scripts on network shares

Scripts executed directly from network shares (UNC paths) may also be restricted by Windows security zone settings.

If necessary, copy the script to a local directory, review its contents, and unblock it before running.

### Security Notes

- Always review scripts before executing them, especially with administrator privileges.
- Do not use `Bypass` or `Unrestricted` as a general solution to execution-policy errors.
- `Unblock-File` removes the downloaded-file security marker; it does not verify that a script is safe.
- Organizational Group Policy settings may override local execution policies.

For more information, see the official Microsoft documentation:

- [PowerShell Execution Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [Unblock-File](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file)


## Usage

Each script has its own README with usage examples, requirements, and limitations.

## Disclaimer

Scripts are provided as-is. Review and test them before using them in production environments.