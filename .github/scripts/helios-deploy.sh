#!/usr/bin/env bash
set -euo pipefail

remote_action() {
  ssh helios "sh -s -- '$1' '$live' '$release'" < .github/scripts/helios-release.sh
}

live="public_html/$SITE_PATH"
release="$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
if [[ "$MODE" == rollback ]]; then
  digest=$(remote_action rollback | sha256sum | cut -d' ' -f1)
else
  uv sync --locked --no-install-project
  uv run --no-sync mkdocs build --strict
  # Distinguish two publications even if the homepage text is identical.
  printf '\n<!-- release %s %s -->\n' "$GITHUB_SHA" "$release" >> site/index.html
  digest=$(sha256sum site/index.html | cut -d' ' -f1)
  remote_action prepare
  stage="${live%/*}/.${live##*/}-releases/$release"
  rsync -rz --chmod=D755,F644 site/ "helios:$stage/"
  remote_action publish
fi

body="$RUNNER_TEMP/helios-index.html"
for attempt in 1 2 3; do
  if code=$(curl -sS --max-time 20 -o "$body" -w '%{http_code}' "${SITE_URL}?run=$release") &&
     [[ "$code" == 200 ]] && grep -Fq 'id="automl-eda-module"' "$body" &&
     [[ "$(sha256sum "$body" | cut -d' ' -f1)" == "$digest" ]]; then
    echo "HTTP 200 · $MODE · $SITE_PATH · HTML SHA-256 $digest" >> "$GITHUB_STEP_SUMMARY"
    exit 0
  fi
  echo "Healthcheck attempt $attempt failed (HTTP ${code:-000})"
  sleep 2
done
exit 1
