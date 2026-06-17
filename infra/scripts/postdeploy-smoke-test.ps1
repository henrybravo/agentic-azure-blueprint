#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Post-deployment smoke + security tests for the Agentic Azure Blueprint.

.DESCRIPTION
    Runs the full set of post-deploy verifications against a live Azure deployment:
      1. Ingress topology      - only agentic-ui is external; BFF + orchestrator are internal-only
      2. UI reachability       - public UI returns HTTP 200
      3. Streaming round-trip  - browser -> UI proxy -> BFF -> orchestrator, SSE delta + done events
      4. BFF isolation         - internal BFF is NOT reachable from the public internet
      5. Orchestrator isolation- internal orchestrator is NOT reachable from the public internet
      6. Foundry model + wiring- model deployment exists; model env vars injected into orchestrator

    Everything is auto-discovered from the resource group, so the script is reusable across deploys.
    Requires: az CLI (logged in) and curl.exe on PATH.

.PARAMETER ResourceGroup
    The deployment resource group. Defaults to "rg-<azd default env name>".

.EXAMPLE
    ./infra/scripts/postdeploy-smoke-test.ps1
    ./infra/scripts/postdeploy-smoke-test.ps1 -ResourceGroup rg-tmpverify2
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
$script:Pass = 0
$script:Fail = 0

function Assert($Name, [bool]$Condition, $Detail = "") {
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:Pass++
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkYellow }
        $script:Fail++
    }
}

function Section($Title) { Write-Host "`n=== $Title ===" -ForegroundColor Cyan }

# ---------------------------------------------------------------------------
# Discover the deployment
# ---------------------------------------------------------------------------
if (-not $ResourceGroup) {
    $envName = (azd env list --output json 2>$null | ConvertFrom-Json | Where-Object { $_.IsDefault }).Name
    if (-not $envName) { throw "No -ResourceGroup given and no default azd environment found." }
    $ResourceGroup = "rg-$envName"
}

Write-Host "Agentic Azure Blueprint - post-deploy smoke test" -ForegroundColor White
Write-Host "Resource group: $ResourceGroup"

if (-not (az group exists -g $ResourceGroup | Select-String -Quiet "true")) {
    throw "Resource group '$ResourceGroup' does not exist (is the deployment up?)."
}

# Ingress for all three apps
$ingress = @{}
foreach ($app in "agentic-ui", "agentic-api", "orchestrator") {
    $ingress[$app] = az containerapp show -g $ResourceGroup -n $app `
        --query "{external:properties.configuration.ingress.external, fqdn:properties.configuration.ingress.fqdn}" `
        -o json | ConvertFrom-Json
}
$uiUrl = "https://$($ingress['agentic-ui'].fqdn)"

# ---------------------------------------------------------------------------
# 1. Ingress topology
# ---------------------------------------------------------------------------
Section "1. Ingress topology"
Assert "agentic-ui is external (public)"        ($ingress['agentic-ui'].external -eq $true)   "external=$($ingress['agentic-ui'].external)"
Assert "agentic-api (BFF) is internal-only"     ($ingress['agentic-api'].external -eq $false) "external=$($ingress['agentic-api'].external)"
Assert "orchestrator is internal-only"          ($ingress['orchestrator'].external -eq $false)"external=$($ingress['orchestrator'].external)"

# ---------------------------------------------------------------------------
# 2. UI reachability
# ---------------------------------------------------------------------------
Section "2. UI reachability"
try {
    $code = (Invoke-WebRequest $uiUrl -UseBasicParsing -TimeoutSec 30).StatusCode
} catch {
    $code = $_.Exception.Response.StatusCode.value__
}
Assert "UI ($uiUrl) returns HTTP 200" ($code -eq 200) "status=$code"

# ---------------------------------------------------------------------------
# 3. Streaming chat round-trip (browser -> UI -> BFF -> orchestrator)
# ---------------------------------------------------------------------------
Section "3. Streaming chat round-trip"
$probe = "smoke round-trip probe"
$body = "{`"threadId`":`"smoke-test`",`"message`":`"$probe`"}"
$sse = curl.exe -sS -N -m 30 -X POST "$uiUrl/api/chat" -H "Content-Type: application/json" -d $body 2>&1 | Out-String
Assert "SSE stream contains 'delta' events" ($sse -match '"type":\s*"delta"') "no delta events seen"
Assert "SSE stream contains terminal 'done' event" ($sse -match '"type":\s*"done"') "no done event seen"
Assert "Echo answer reflects the message" ($sse -match [regex]::Escape($probe)) "probe text not echoed back"

# ---------------------------------------------------------------------------
# 4 & 5. Internal apps are NOT reachable from the public internet
# ---------------------------------------------------------------------------
function Test-Isolation($Name, $Fqdn, $Path) {
    $url = "https://$Fqdn$Path"
    $body = '{"threadId":"sec-test","message":"hi"}'
    $resp = curl.exe -sS -m 20 -X POST $url -H "Content-Type: application/json" -d $body 2>&1 | Out-String
    # A real app response would contain SSE events / JSON. The ingress front door
    # instead serves an "unavailable / does not exist" page for internal apps,
    # or the connection fails outright. Either way: NOT a valid app response.
    $leaked = ($resp -match '"type":\s*"(delta|done)"')
    Assert "$Name is not reachable externally" (-not $leaked) "LEAK: app responded to external caller`n$resp"
}
Section "4. BFF isolation (external access blocked)"
Test-Isolation "agentic-api (BFF)" $ingress['agentic-api'].fqdn "/api/chat"
Section "5. Orchestrator isolation (external access blocked)"
Test-Isolation "orchestrator" $ingress['orchestrator'].fqdn "/turn"

# ---------------------------------------------------------------------------
# 6. Foundry model + orchestrator wiring
# ---------------------------------------------------------------------------
Section "6. Foundry model and orchestrator wiring"
$acct = az cognitiveservices account list -g $ResourceGroup --query "[0].name" -o tsv
$deployments = az cognitiveservices account deployment list -g $ResourceGroup -n $acct `
    --query "[].{name:name, model:properties.model.name, version:properties.model.version}" -o json | ConvertFrom-Json
Assert "At least one model deployment exists" ($deployments.Count -ge 1) "no deployments on '$acct'"
if ($deployments.Count -ge 1) {
    $d = $deployments[0]
    Write-Host "         model: $($d.model) ($($d.version)) as '$($d.name)'" -ForegroundColor DarkGray
}

$env = az containerapp show -g $ResourceGroup -n orchestrator `
    --query "properties.template.containers[0].env" -o json | ConvertFrom-Json
$envNames = $env.name
Assert "AZURE_OPENAI_ENDPOINT injected into orchestrator"        ($envNames -contains "AZURE_OPENAI_ENDPOINT")
Assert "AZURE_OPENAI_DEPLOYMENT_NAME injected into orchestrator"  ($envNames -contains "AZURE_OPENAI_DEPLOYMENT_NAME")
# Managed-identity wiring differs by branch: the user-assigned variant (main) injects
# AZURE_CLIENT_ID so DefaultAzureCredential targets that identity; the system-assigned
# variant (this branch) injects nothing - DefaultAzureCredential picks up the app's
# system-assigned identity automatically. Pass on either valid wiring.
$identityType = az containerapp show -g $ResourceGroup -n orchestrator --query "identity.type" -o tsv
$hasClientId = $envNames -contains "AZURE_CLIENT_ID"
$hasSystemAssigned = $identityType -match "SystemAssigned"
Assert "Orchestrator has managed identity (AZURE_CLIENT_ID or system-assigned)" `
    ($hasClientId -or $hasSystemAssigned) "identity.type=$identityType, AZURE_CLIENT_ID present=$hasClientId"
$deployEnv = ($env | Where-Object { $_.name -eq "AZURE_OPENAI_DEPLOYMENT_NAME" }).value
Assert "Deployment name env matches a real model deployment" ($deployments.name -contains $deployEnv) "env=$deployEnv"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor White
Write-Host ("Result: {0} passed, {1} failed" -f $script:Pass, $script:Fail) `
    -ForegroundColor ($(if ($script:Fail -eq 0) { "Green" } else { "Red" }))
Write-Host "========================================" -ForegroundColor White
if ($script:Fail -gt 0) { exit 1 }
