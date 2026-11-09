# M365 Stale User & Licence Report

A read-only PowerShell script that finds inactive Microsoft 365 / Entra ID accounts and shows which paid licences they still hold, so unused licences can be reviewed and reclaimed.

**It makes no changes to your tenant.** It only reads user data and exports a CSV.

## What it does

- Connects to Microsoft Graph with read-only permissions
- Lists all users with last sign-in date, enabled status and assigned licences
- Flags accounts as `Active`, `Stale`, `Never signed in` or `New account`
- Exports a CSV report
- Prints a summary, including how many stale accounts still hold licences

## Requirements

- PowerShell 5.1 or 7+
- Microsoft Graph PowerShell module:

  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser
  ```

- Delegated permissions (read-only): `User.Read.All`, `AuditLog.Read.All`, `Organization.Read.All`
- Sign-in activity data requires Entra ID P1 or higher. Without it, last sign-in dates will be blank.

## Usage

```powershell
# Default: flag accounts inactive for 90 days
.\Get-StaleUserLicenceReport.ps1

# Custom threshold and output path
.\Get-StaleUserLicenceReport.ps1 -StaleDays 60 -OutputPath .\report.csv
```

## Example output

Console summary:

```
Total users:                       248
Stale / never signed in:           31
...of which still hold licences:   22  <- potential savings
Report saved to:                   .\StaleUserReport_20261109.csv
```

CSV (sample data, fictional):

| DisplayName | UserPrincipalName | AccountEnabled | LastSignIn | Status | Licences |
|---|---|---|---|---|---|
| Sam Example | sam@contoso.example | True | 2026-05-02 | Stale | SPE_E3 |
| Alex Sample | alex@contoso.example | True | | Never signed in | O365_BUSINESS_PREMIUM |
| Jo Demo | jo@contoso.example | True | 2026-11-07 | Active | SPE_E3 |

## Notes

- Test in a development tenant first.
- Only run it against tenants you are authorised to access.
- Review flagged accounts manually before removing any licences. Service accounts, shared mailboxes and seasonal staff may appear stale but still be needed.

## Licence

MIT
