#!/usr/bin/env sh
# azd postprovision hook (POSIX).
#
# Runs after `azd provision`. Imports the container base images into the project ACR so the
# remote image builds pull them from ACR (authenticated) instead of Docker Hub — avoiding the
# anonymous pull rate limit ("toomanyrequests") that fails azd's remote build. Also the natural
# place to wire anything that can't live in Bicep (e.g. Entra app registrations for OBO).
set -e

if [ -z "$AZURE_CONTAINER_REGISTRY_ENDPOINT" ]; then
  echo "postprovision: AZURE_CONTAINER_REGISTRY_ENDPOINT not set; skipping base-image import."
  exit 0
fi

acr_name="${AZURE_CONTAINER_REGISTRY_ENDPOINT%%.*}"

# "image|source" pairs. Prefer the Microsoft Artifact Registry Docker mirror
# (mcr.microsoft.com/mirror/docker/library/*) where available — it is not subject to Docker Hub's
# anonymous pull rate limit. The mirror is an allow-listed subset, so images it does not carry
# (e.g. node:20-slim) fall back to docker.io and are best-effort: a failed import prints a warning
# and the remote build will still try Docker Hub directly.
for pair in \
  "python:3.11-slim|mcr.microsoft.com/mirror/docker/library/python:3.11-slim" \
  "node:20-slim|docker.io/library/node:20-slim"; do
  image="${pair%%|*}"
  source="${pair#*|}"
  echo "postprovision: importing $image into $acr_name (from $source) ..."
  if ! az acr import --name "$acr_name" --source "$source" --image "$image" --force >/dev/null; then
    echo "WARNING: postprovision: import of $image failed (likely Docker Hub rate limit). The remote build will fall back to Docker Hub; pre-import it manually if the build fails."
  fi
done
echo "postprovision: base-image import complete for $acr_name."
echo "TODO: create Entra app registrations / assign extra roles here as your app needs them."
