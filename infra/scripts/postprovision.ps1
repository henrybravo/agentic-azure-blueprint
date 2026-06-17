# azd postprovision hook (PowerShell).
#
# Runs after `azd provision`. Imports the container base images into the project ACR so the
# remote image builds pull them from ACR (authenticated) instead of Docker Hub — avoiding the
# anonymous pull rate limit ("toomanyrequests") that fails azd's remote build. Also the natural
# place to wire anything that can't live in Bicep (e.g. Entra app registrations for OBO).
#
# Base images are sourced from the Microsoft Artifact Registry (MCR) Docker mirror
# (mcr.microsoft.com/mirror/docker/library/*), which is Microsoft-operated, needs no Docker Hub
# login, and is NOT subject to Docker Hub's anonymous pull rate limit. node:20-slim maps to the
# Debian bookworm-slim variant — the same base Docker Hub's node:20-slim currently aliases.
#
# Optional break-glass: if a primary import fails and BASEIMAGE_FALLBACK_REGISTRY is set, the image
# is re-imported from <BASEIMAGE_FALLBACK_REGISTRY>/<image> (e.g. another ACR you control). Set
# BASEIMAGE_FALLBACK_USERNAME / BASEIMAGE_FALLBACK_PASSWORD for an authenticated fallback (omit for
# an anonymous-pull ACR). Wire it with `azd env set` — see HACKATHON.md "Base images".
$ErrorActionPreference = 'Stop'

$acrEndpoint = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT
if (-not $acrEndpoint) {
    Write-Host "postprovision: AZURE_CONTAINER_REGISTRY_ENDPOINT not set; skipping base-image import."
    return
}

$acrName = $acrEndpoint.Split('.')[0]

# Warn-only so a transient import miss never aborts the deploy; the remote build surfaces a hard
# error if a base image is genuinely missing.
function Import-BaseImage {
    param([string]$Image, [string]$Source)
    Write-Host "postprovision: importing $Image into $acrName (from $Source) ..."
    az acr import --name $acrName --source $Source --image $Image --force 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Warning "primary import of $Image failed."
    if ($env:BASEIMAGE_FALLBACK_REGISTRY) {
        $fb = "$($env:BASEIMAGE_FALLBACK_REGISTRY)/$Image"
        Write-Host "postprovision: retrying $Image from fallback $fb ..."
        if ($env:BASEIMAGE_FALLBACK_USERNAME) {
            az acr import --name $acrName --source $fb --image $Image --force `
                --username $env:BASEIMAGE_FALLBACK_USERNAME --password $env:BASEIMAGE_FALLBACK_PASSWORD 2>$null | Out-Null
        } else {
            az acr import --name $acrName --source $fb --image $Image --force 2>$null | Out-Null
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Host "postprovision: fallback import of $Image succeeded."
            return
        }
        Write-Warning "fallback import of $Image also failed."
    }
    Write-Warning "$Image not imported. The remote build will try to pull it directly and may fail; pre-import it manually (see HACKATHON.md)."
}

Import-BaseImage -Image 'python:3.11-slim' -Source 'mcr.microsoft.com/mirror/docker/library/python:3.11-slim'
Import-BaseImage -Image 'node:20-slim'     -Source 'mcr.microsoft.com/mirror/docker/library/node:20-bookworm-slim'

Write-Host "postprovision: base-image import complete for $acrName."

# --- Configure each app's ACR registry with its system-assigned identity ---
# The container apps are provisioned WITHOUT a registries block (see resources.bicep: that would
# deadlock, because ACA validates the registry against the system identity before AcrPull is
# granted). Provisioning has now granted AcrPull to each app's system identity, so it is safe to
# attach the registry here with `--identity system`. `azd deploy` then pulls the real images.
# Warn-only: a transient RBAC-propagation miss is healed by the deploy revision that follows.
function Set-AppRegistry {
    param([string]$AppId)
    if (-not $AppId) { return }
    $rg   = if ($AppId -match '/resourceGroups/([^/]+)/') { $Matches[1] } else { '' }
    $name = if ($AppId -match '/containerApps/([^/]+)')   { $Matches[1] } else { '' }
    Write-Host "postprovision: configuring ACR registry on $name (identity: system) ..."
    az containerapp registry set -g $rg -n $name --server $acrEndpoint --identity system 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "could not set registry on $name; azd deploy will retry the pull once RBAC propagates."
    }
}

Set-AppRegistry -AppId $env:AZURE_RESOURCE_ORCHESTRATOR_ID
Set-AppRegistry -AppId $env:AZURE_RESOURCE_AGENTIC_API_ID
Set-AppRegistry -AppId $env:AZURE_RESOURCE_AGENTIC_UI_ID

Write-Host "TODO: create Entra app registrations / assign extra roles here as your app needs them."
