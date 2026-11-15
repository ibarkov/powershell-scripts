# Security Policy

## Supported Versions

Security fixes are generally applied to the latest version of each script available on the repository's default branch.

Older versions and previously downloaded copies are not actively maintained.

Security fixes are provided on a best-effort basis. No guaranteed response or resolution time is offered.

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, **please do not open a public GitHub issue or discussion**.

Instead, report it privately through GitHub's **Private Vulnerability Reporting** feature:

[Report a vulnerability](https://github.com/ibarkov/powershell-scripts/security/advisories)

Please include:

- A description of the vulnerability.
- Steps to reproduce the issue.
- The affected script and version or commit.
- The potential security impact.
- A proof of concept, if available.

Please avoid publicly disclosing vulnerability details before they have been reviewed.

## Security Considerations

These scripts may access Windows Event Logs, account information, system configurations, and other potentially sensitive data.

Review the source code and test scripts in a controlled environment before running them on production systems.

Do not publish real audit logs, credentials, access tokens, or sensitive infrastructure information.

## Disclaimer

These scripts are provided **as-is**, without warranty of any kind, under the terms of the [MIT License](LICENSE).

Use them at your own risk. The repository maintainer is not responsible for damage or data loss resulting from their use.