#!/usr/bin/env bash
set -euo pipefail

ROUTER_HOST=${ROUTER_HOST:-}
ROUTER_USER=${ROUTER_USER:-}
ROUTER_IDENT=${ROUTER_IDENT:-}

if [[ -z "${ROUTER_HOST}" || -z "${ROUTER_USER}" || -z "${ROUTER_IDENT}" ]]; then
  echo "ROUTER_* env not set - skipping integration test."
  exit 0
fi

scp -i "${ROUTER_IDENT}" -o StrictHostKeyChecking=accept-new   secrets.rsc tests/secrets.yaml tests/integration/example_main.rsc   "${ROUTER_USER}@${ROUTER_HOST}:"

ssh -i "${ROUTER_IDENT}" -o StrictHostKeyChecking=accept-new   "${ROUTER_USER}@${ROUTER_HOST}"   '/import file-name=example_main.rsc' | tee /tmp/secjector-test.log

if grep -q 'TEST_OK:' /tmp/secjector-test.log; then
  echo "Integration test passed"
  exit 0
else
  echo "Integration test failed"
  exit 1
fi
