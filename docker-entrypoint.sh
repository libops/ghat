#!/usr/bin/env bash

set -eou pipefail

echo "Starting GitHub App Token service"

while [ ! -s "$GITHUB_APP_PRIVATE_KEY" ]; do
  echo "Waiting for $GITHUB_APP_PRIVATE_KEY"
  sleep 5
done

if openssl pkey -in "$GITHUB_APP_PRIVATE_KEY" -check -noout 2>/dev/null; then
  exec /app/ghat
else
  echo "ERROR: $GITHUB_APP_PRIVATE_KEY is not a valid private key (or unreadable)."
  exit 1
fi

echo "$GITHUB_APP_PRIVATE_KEY is ready"

exec /app/ghat
