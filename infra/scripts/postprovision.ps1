# azd postprovision hook (PowerShell).
#
# Runs after `azd provision`. Imports the container base images into the project ACR so the
# remote image builds pull them from ACR (authenticated) instead of Docker Hub — avoiding the
# anonymous pull rate limit ("toomanyrequests") that fails azd's remote build. Also the natural
# place to wire anything that can't live in Bicep (e.g. Entra app registrations for OBO).
$ErrorActionPreference = 'Stop'

$acrEndpoint = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT
if (-not $acrEndpoint) {
    Write-Host "postprovision: AZURE_CONTAINER_REGISTRY_ENDPOINT not set; skipping base-image import."
    return
}

$acrName = $acrEndpoint.Split('.')[0]

# (image, source) pairs. Prefer the Microsoft Artifact Registry Docker mirror
# (mcr.microsoft.com/mirror/docker/library/*) where available — it is not subject to Docker Hub's
# anonymous pull rate limit. The mirror is an allow-listed subset, so images it does not carry
# (e.g. node:20-slim) fall back to docker.io and are best-effort: a failed import prints a warning
# and the remote build will still try Docker Hub directly.
$imports = @(
    @{ image = 'python:3.11-slim'; source = 'mcr.microsoft.com/mirror/docker/library/python:3.11-slim' },
    @{ image = 'node:20-slim';     source = 'docker.io/library/node:20-slim' }
)
foreach ($i in $imports) {
    Write-Host "postprovision: importing $($i.image) into $acrName (from $($i.source)) ..."
    az acr import --name $acrName --source $i.source --image $i.image --force | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "postprovision: import of $($i.image) failed (likely Docker Hub rate limit). The remote build will fall back to Docker Hub; pre-import it manually if the build fails."
    }
}
Write-Host "postprovision: base-image import complete for $acrName."
Write-Host "TODO: create Entra app registrations / assign extra roles here as your app needs them."
