#!/usr/bin/env bash
# Regenerate the committed keystone.json from keystone.yaml.
# Pure Nix evaluation cannot parse YAML, so the JSON is what flakes read;
# run this (and commit the result) after every keystone.yaml edit.
# TODO: replace with `ks config generate` + a CI freshness check so the
# committed JSON cannot silently drift from the YAML.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v yq >/dev/null 2>&1; then
  # Handle both yq variants: mikefarah (Go) and kislyuk (jq wrapper).
  if yq --version 2>&1 | grep -q mikefarah; then
    yq -o=json '.' keystone.yaml > keystone.json
  else
    yq . keystone.yaml > keystone.json
  fi
elif command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys,yaml; json.dump(yaml.safe_load(open("keystone.yaml")), open("keystone.json","w"), indent=2)'
else
  echo "error: need yq or python3+pyyaml to convert keystone.yaml" >&2
  exit 1
fi

echo "wrote keystone.json"
