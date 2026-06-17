# azd preprovision hook (PowerShell).
#
# Registers resource providers that azd does not reliably auto-register before the nested AVM
# modules need them. Microsoft.AlertsManagement backs the Application Insights "failure anomalies"
# smart-detector alert rule created by avm/ptn/azd/monitoring; if it is not registered, provisioning
# fails with MissingSubscriptionRegistration. This is identity-model-independent (same on the
# user-assigned `main` branch). Registration is idempotent and a no-op when already registered.
$ErrorActionPreference = 'Stop'

$providers = @('Microsoft.AlertsManagement')
foreach ($ns in $providers) {
    $state = az provider show --namespace $ns --query registrationState -o tsv 2>$null
    if ($state -eq 'Registered') {
        Write-Host "preprovision: $ns already registered."
    } else {
        Write-Host "preprovision: registering $ns (current: $state); waiting for completion ..."
        az provider register --namespace $ns --wait
        Write-Host "preprovision: $ns registered."
    }
}
