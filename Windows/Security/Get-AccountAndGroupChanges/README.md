
# Get-AccountAndGroupChanges.ps1 — Windows Account and Security Group Change Audit

A PowerShell script for auditing **Windows user account changes and security group membership changes** using the Windows Security Event Log.

Find out **who created, enabled, disabled, deleted, or modified a user account**, and **who added or removed users from security groups** such as Administrators, Remote Desktop Users, and other local or domain groups.

Useful for Windows Server security auditing, investigating privilege changes, reviewing administrative activity, and tracking account modifications in Windows and Active Directory environments.

**Script version:** 1.0

> **Scope:** The script reads the local Windows Security event log. For Active Directory account and group changes, run it on the relevant domain controllers. The script is read-only and does not modify users or groups.

## Features

- Audits Windows user account creation, modification, enablement, disablement, and deletion.
- Tracks additions and removals from security-enabled local, global, and universal groups.
- Identifies the affected user, target group, and account that performed the change.
- Displays events in chronological order, **newest first**.
- Filters events by time using `-Hours` (default: 24 hours).
- Searches all retained matching events using `-All`.
- Filters by affected account or group member using `-User`.
- Supports short usernames, `DOMAIN\username`, SIDs, and matching against recorded member distinguished names.
- Resolves member SIDs to account names where possible, with a CIM/WMI fallback for local accounts.
- Caches SID resolutions to avoid repeated lookups.
- Limits matching events using `-MaxEvents`.
- Exports detailed records to UTF-8 CSV using `-CsvPath`.
- Returns PowerShell objects using `-PassThru`.
- Displays an event summary by action, unless `-NoSummary` is specified.
- Requires no third-party PowerShell modules or Active Directory module.

## Supported Windows Security Events

### User Account Management

| Event ID | Action | Description |
|---|---|---|
| `4720` | `UserCreated` | A user account was created. |
| `4722` | `UserEnabled` | A user account was enabled. |
| `4725` | `UserDisabled` | A user account was disabled. |
| `4726` | `UserDeleted` | A user account was deleted. |
| `4738` | `UserModified` | A user account was changed. |

### Security Group Management

| Event ID | Action | Description |
|---|---|---|
| `4728` | `MemberAddedGlobal` | A member was added to a security-enabled global group. |
| `4729` | `MemberRemovedGlobal` | A member was removed from a security-enabled global group. |
| `4732` | `MemberAddedLocal` | A member was added to a security-enabled local group. |
| `4733` | `MemberRemovedLocal` | A member was removed from a security-enabled local group. |
| `4756` | `MemberAddedUniversal` | A member was added to a security-enabled universal group. |
| `4757` | `MemberRemovedUniversal` | A member was removed from a security-enabled universal group. |

Group-related events are parsed using their XML field names. In these events, `TargetUserName` identifies the **group**, while `MemberSid` identifies the affected member.

## Requirements

- Windows with `Get-WinEvent` (developed for **Windows PowerShell 5.1**).
- Permission to read the local Security event log.
- **Audit User Account Management (Success)** enabled.
- **Audit Security Group Management (Success)** enabled.
- Relevant events still retained in the Security log.

The built-in `CimCmdlets` module is used as an optional fallback when normal SID translation fails.

### Check audit policy

Run the following commands on an English-language Windows installation:

```powershell
auditpol /get /subcategory:"User Account Management"
auditpol /get /subcategory:"Security Group Management"
```

Both subcategories should include **Success** auditing for the supported successful changes to be recorded.

An elevated PowerShell session may be required.

## Quick Start

Run the script from the directory containing `Get-AccountAndGroupChanges.ps1`:

```powershell
# Account and group changes from the last 24 hours
.\Get-AccountAndGroupChanges.ps1
```

By default, the script retrieves up to 500 matching events.

## Usage Examples

### Search by time range

```powershell
# Changes from the last seven days
.\Get-AccountAndGroupChanges.ps1 -Hours 168

# Changes from the last hour
.\Get-AccountAndGroupChanges.ps1 -Hours 1
```

### Search all retained events

```powershell
# Search all retained matching events
.\Get-AccountAndGroupChanges.ps1 -All

# Retrieve up to 100 of the most recent matching events
.\Get-AccountAndGroupChanges.ps1 -All -MaxEvents 100
```

> `-All` cannot be combined with an explicitly supplied `-Hours` parameter. Without an explicit `-MaxEvents`, `-All` has no event-count limit.

### Find changes affecting a specific user

```powershell
# Search by username
.\Get-AccountAndGroupChanges.ps1 -All -User AuditTestUser

# Search by domain-qualified username
.\Get-AccountAndGroupChanges.ps1 -All -User 'CONTOSO\jdoe'

# Retrieve the two most recent matching events
.\Get-AccountAndGroupChanges.ps1 -All -User AuditTestUser -MaxEvents 2
```

The `-User` parameter filters the **affected user or group member**, not the administrator who performed the change.

For group membership events, the script attempts to resolve the member SID. If resolution fails, the original recorded member name or SID is retained.

### Audit changes to Administrators

```powershell
.\Get-AccountAndGroupChanges.ps1 -Hours 168 -PassThru |
    Where-Object GroupSID -eq 'S-1-5-32-544' |
    Format-Table Time, Action, User, ChangedBy
```

`S-1-5-32-544` is the well-known SID of the built-in Administrators group.

Using the SID avoids dependence on localized group names.

### Audit Remote Desktop Users membership

```powershell
.\Get-AccountAndGroupChanges.ps1 -Hours 168 -PassThru |
    Where-Object GroupSID -eq 'S-1-5-32-555' |
    Format-Table Time, Action, User, ChangedBy
```

### Export account and group changes to CSV

```powershell
# Export the most recent 100 retained events
.\Get-AccountAndGroupChanges.ps1 -All -MaxEvents 100 -CsvPath .\account-changes.csv

# View exported data
Import-Csv .\account-changes.csv | Format-List *
```

### Inspect detailed event properties

```powershell
.\Get-AccountAndGroupChanges.ps1 -All -MaxEvents 10 -PassThru |
    Format-List *
```

### Disable summary output

```powershell
.\Get-AccountAndGroupChanges.ps1 -Hours 24 -NoSummary
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Hours <int>` | `24` | Search the last 1–8,760 hours. Cannot be explicitly combined with `-All`. |
| `-All` | Off | Search all retained matching Security events without a time filter. |
| `-MaxEvents <int>` | `500` | Retrieve up to 1–50,000 matching events. With `-All`, the limit applies only when explicitly supplied. |
| `-User <string>` | — | Filter by affected account or group member. Supports wildcards, domain-qualified names, SIDs, and member DN matching. |
| `-CsvPath <string>` | — | Export detailed event records to UTF-8 CSV. |
| `-PassThru` | Off | Return structured PowerShell objects instead of a formatted table. |
| `-NoSummary` | Off | Suppress the action summary when displaying the normal table. |

### How -User and -MaxEvents Work

Without `-User`, `Get-WinEvent` applies `-MaxEvents` during event retrieval.

With `-User`, the script first retrieves the selected event types, resolves account information, filters by the affected account, and then applies `-MaxEvents`.

This prevents unrelated events from consuming the result limit.

**Performance note:** A username-filtered search may load a large number of events into memory before filtering. Avoid unrestricted searches on high-volume Security logs unless necessary.

## Example Output

```text
Time                Action             TargetGroup    User          ChangedBy
----                ------             -----------    ----          ---------
16.11.2026 11:50:11 MemberRemovedLocal ORA_DBA        AuditTestUser LAB-SERVER\Administrator
16.11.2026 11:50:03 MemberAddedLocal   ORA_DBA        AuditTestUser LAB-SERVER\Administrator
16.11.2026 11:44:45 MemberRemovedLocal Administrators AuditTestUser LAB-SERVER\Administrator
16.11.2026 11:44:42 MemberAddedLocal   Administrators AuditTestUser LAB-SERVER\Administrator

Summary: 4 event(s), 2026-11-16 11:44:42 .. 2026-11-16 11:50:11

Action             Count
------             -----
MemberAddedLocal       2
MemberRemovedLocal     2
```

*Illustrative output based on tested local group membership scenarios. Hostnames and account names have been anonymized.*

The script can reveal temporary administrative group membership even when a user is removed from the group shortly after being added.

## Output Fields

The default table displays **Time, Action, TargetGroup, User, and ChangedBy**.

Use `-PassThru` or `-CsvPath` to access all properties.

| Field | Description |
|---|---|
| `Time` | Event timestamp in the local computer's time zone. |
| `Action` | Human-readable action derived from the Windows Event ID. |
| `User` | Affected account or group member; may be a SID or raw DN if resolution fails. |
| `Domain` | Domain or computer name associated with the affected account, when known. |
| `UserSID` | SID of the affected account or group member. |
| `TargetGroup` | Security group whose membership was changed, when applicable. |
| `GroupDomain` | Domain or computer context of the target group. |
| `GroupSID` | SID of the target group. |
| `Member` | Resolved member account name, or original DN/SID when resolution is unavailable. |
| `MemberNameRaw` | Original member name recorded in the Windows event. |
| `MemberSID` | Original member SID recorded in the event. |
| `ChangedBy` | Account recorded as performing the change (`SubjectDomainName\SubjectUserName`). |
| `ChangedBySID` | SID of the account that performed the change. |
| `SubjectLogonId` | Subject's logon ID, useful for correlating events on the same computer. |
| `Server` | Computer that generated the event. |
| `EventID` | Original Windows Security Event ID. |
| `LogName` | Source event log, normally `Security`. |
| `RecordID` | Record identifier within the local Security log. |

## Understanding Group Membership Events

For security group events, Windows records the group and member separately.

- `TargetUserName` identifies the group, not the affected user.
- `TargetSid` identifies the group SID.
- `MemberSid` identifies the added or removed member.
- `MemberName` may contain an LDAP Distinguished Name or `-`.
- `SubjectUserName` identifies the account recorded as performing the change.

The script preserves the original fields and attempts SID-to-account-name resolution for more readable results.

### SID Resolution

SID resolution uses Windows `SecurityIdentifier.Translate()` with a CIM/WMI fallback for local user accounts.

Resolution may fail if an account has been deleted, a domain is unavailable, or a trust relationship is inaccessible.

The script does not invent missing account names.

## Limitations and Security Considerations

- Reads the **local Windows Security event log only**; it does not collect events from remote computers.
- For domain-wide auditing, relevant events may need to be collected from multiple domain controllers.
- Only events still retained in the Security log are available.
- Event availability depends on the configured audit policies.
- Group membership auditing does not reconstruct historical group membership snapshots.
- SID resolution is best-effort. Deleted or unavailable accounts may remain represented by SIDs or raw distinguished names.
- The `-User` filter also supports substring matching against the recorded member DN. This may match text in an organizational unit or another part of the DN, not only the account name.
- Large event logs may require considerable memory, particularly with `-User` and unrestricted `-All`.
- Event ID 4738 identifies an account modification but the default output does not describe every changed attribute. Inspect the original event for more details.
- The summary counts event records, not unique users or distinct administrative sessions.
- CSV files may contain account names, domain information, SIDs, and other sensitive security metadata. Do not commit production audit exports to public repositories.
- This script is **read-only** and does not create, delete, or modify Windows accounts or groups.

## Troubleshooting

### No matching events

Check the selected time range and confirm that the required auditing is enabled.

Try:

```powershell
.\Get-AccountAndGroupChanges.ps1 -All -MaxEvents 20
```

### Access denied

Run PowerShell using an account permitted to read the local Security event log. Elevation may be necessary.

### Member appears as a SID or Distinguished Name

SID translation may be unavailable. The script keeps the original value rather than guessing the account name.

### Inspect the raw Windows event

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4720,4722,4725,4726,4738,4728,4729,4732,4733,4756,4757
} -MaxEvents 1 | ForEach-Object {
    $_.ToXml()
}
```

### View built-in PowerShell help

```powershell
Get-Help .\Get-AccountAndGroupChanges.ps1 -Detailed
```

## Testing Status

Tested on a local Windows machine with Windows PowerShell 5.1.

Verified scenarios:

- User creation (`4720`).
- User enablement (`4722`).
- User modification (`4738`).
- Global group membership addition (`4728`).
- Local group membership addition (`4732`).
- Local group membership removal (`4733`).
- Membership changes in Administrators, Remote Desktop Users, Users, and ORA_DBA.
- SID resolution and identification of the account performing changes.
- Username filtering with `-User`.
- Combined `-User` and `-MaxEvents` filtering.
- CSV export and import.
- Structured object output with `-PassThru`.
- Summary suppression with `-NoSummary`.

**Not yet tested:** domain controller scenarios, universal group changes (`4756`/`4757`), user disablement/deletion (`4725`/`4726`), and global/universal group membership removal (`4729`/`4757`).

## Related Scripts

- [Get-AccountLockoutEvents](../Get-AccountLockoutEvents/) — audit Windows account lockouts (Event ID 4740).
- [Get-FailedLogonAttempts](../Get-FailedLogonAttempts/) — investigate failed logons (Event ID 4625).
- [Get-SuccessfulLogons](../Get-SuccessfulLogons/) — audit successful logons (Event ID 4624).
- [Get-RdpSessionHistory](../Get-RdpSessionHistory/) — inspect RDP session history.

## References

- [Microsoft Learn: Audit User Account Management](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/audit-user-account-management)
- [Microsoft Learn: Audit Security Group Management](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/audit-security-group-management)
- [Microsoft Learn: Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)

## License

Licensed under the [MIT License](../../../LICENSE).

Copyright (c) 2026 Igor Barkov.
