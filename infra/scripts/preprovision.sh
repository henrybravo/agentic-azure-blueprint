#!/usr/bin/env sh
# azd preprovision hook (POSIX).
#
# Registers resource providers that azd does not reliably auto-register before the nested AVM
# modules need them. Microsoft.AlertsManagement backs the Application Insights "failure anomalies"
# smart-detector alert rule created by avm/ptn/azd/monitoring; if it is not registered, provisioning
# fails with MissingSubscriptionRegistration. This is identity-model-independent (same on the
# user-assigned `main` branch). Registration is idempotent and a no-op when already registered.
set -e

for ns in Microsoft.AlertsManagement; do
  state=$(az provider show --namespace "$ns" --query registrationState -o tsv 2>/dev/null || echo "")
  if [ "$state" = "Registered" ]; then
    echo "preprovision: $ns already registered."
  else
    echo "preprovision: registering $ns (current: ${state:-unknown}); waiting for completion ..."
    az provider register --namespace "$ns" --wait
    echo "preprovision: $ns registered."
  fi
done
