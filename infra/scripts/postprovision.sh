#!/usr/bin/env sh
# azd postprovision hook (POSIX).
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
set -e

if [ -z "$AZURE_CONTAINER_REGISTRY_ENDPOINT" ]; then
  echo "postprovision: AZURE_CONTAINER_REGISTRY_ENDPOINT not set; skipping base-image import."
  exit 0
fi

acr_name="${AZURE_CONTAINER_REGISTRY_ENDPOINT%%.*}"

# Always returns 0 (warn-only) so a transient import miss never aborts the deploy; the remote
# build will surface a hard error if a base image is genuinely missing.
import_image() {
  image="$1"
  source="$2"
  echo "postprovision: importing $image into $acr_name (from $source) ..."
  if az acr import --name "$acr_name" --source "$source" --image "$image" --force >/dev/null 2>&1; then
    return 0
  fi
  echo "WARNING: primary import of $image failed."
  if [ -n "$BASEIMAGE_FALLBACK_REGISTRY" ]; then
    fb="$BASEIMAGE_FALLBACK_REGISTRY/$image"
    echo "postprovision: retrying $image from fallback $fb ..."
    if [ -n "$BASEIMAGE_FALLBACK_USERNAME" ]; then
      if az acr import --name "$acr_name" --source "$fb" --image "$image" --force \
          --username "$BASEIMAGE_FALLBACK_USERNAME" --password "$BASEIMAGE_FALLBACK_PASSWORD" \
          >/dev/null 2>&1; then
        echo "postprovision: fallback import of $image succeeded."
        return 0
      fi
    elif az acr import --name "$acr_name" --source "$fb" --image "$image" --force >/dev/null 2>&1; then
      echo "postprovision: fallback import of $image succeeded."
      return 0
    fi
    echo "WARNING: fallback import of $image also failed."
  fi
  echo "WARNING: $image not imported. The remote build will try to pull it directly and may fail; pre-import it manually (see HACKATHON.md)."
  return 0
}

import_image "python:3.11-slim" "mcr.microsoft.com/mirror/docker/library/python:3.11-slim"
import_image "node:20-slim"     "mcr.microsoft.com/mirror/docker/library/node:20-bookworm-slim"

echo "postprovision: base-image import complete for $acr_name."
echo "TODO: create Entra app registrations / assign extra roles here as your app needs them."
