<#
.SYNOPSIS
    Finds stale (inactive) Microsoft 365 / Entra ID users and shows which licences they hold.

.DESCRIPTION
    Read-only report. Connects to Microsoft Graph, lists every user with their last sign-in,
    assigned licences and enabled status, flags accounts inactive for N days, and exports a CSV.
    Useful for cutting licence costs and tightening security. Makes NO changes to your tenant.

.PARAMETER StaleDays
    Days without sign-in before an account is flagged as stale. Default: 90.

.PARAMETER OutputPath
    Where to save the CSV report.

.EXAMPLE
    .\Get-StaleUserLicenceReport.ps1 -StaleDays 60

.NOTES
    Requires: Install-Module Microsoft.Graph -Scope CurrentUser
    Permissions (delegated, read-only): User.Read.All, AuditLog.Read.All, Organization.Read.All
    Sign-in activity data requires Entra ID P1 or higher on the tenant.
    Test in a dev tenant first.
#>
[CmdletBinding()]
param(
    [int]$StaleDays = 90,
    [string]$OutputPath = ".\StaleUserReport_$(Get-Date -Format 'yyyyMMdd').csv"
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    throw "Microsoft Graph module missing. Run: Install-Module Microsoft.Graph -Scope CurrentUser"
}

Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All', 'Organization.Read.All' -NoWelcome

# Map licence SKU IDs to readable names
$skuMap = @{}
Get-MgSubscribedSku | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$cutoff = (Get-Date).AddDays(-$StaleDays)

$users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, AccountEnabled,
    AssignedLicenses, SignInActivity, CreatedDateTime

$report = foreach ($u in $users) {
    $lastSignIn = $u.SignInActivity.LastSignInDateTime
    $licences = ($u.AssignedLicenses | ForEach-Object { $skuMap[$_.SkuId] }) -join '; '
    $isNew = $u.CreatedDateTime -and ($u.CreatedDateTime -gt $cutoff)

    $status = if ($isNew) { 'New account' }
              elseif (-not $lastSignIn) { 'Never signed in' }
              elseif ($lastSignIn -lt $cutoff) { 'Stale' }
              else { 'Active' }

    [pscustomobject]@{
        DisplayName       = $u.DisplayName
        UserPrincipalName = $u.UserPrincipalName
        AccountEnabled    = $u.AccountEnabled
        LastSignIn        = $lastSignIn
        Status            = $status
        Licences          = $licences
        HasLicence        = [bool]$licences
    }
}

$report | Sort-Object Status, LastSignIn | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

# Summary
$flagged = $report | Where-Object { $_.Status -in 'Stale', 'Never signed in' }
$wasted = $flagged | Where-Object { $_.HasLicence -and $_.AccountEnabled }

Write-Host "`nTotal users:                       $($report.Count)"
Write-Host "Stale / never signed in:           $($flagged.Count)"
Write-Host "...of which still hold licences:   $($wasted.Count)  <- potential savings"
Write-Host "Report saved to:                   $OutputPath`n"

Disconnect-MgGraph | Out-Null
