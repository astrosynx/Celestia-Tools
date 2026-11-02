#!/usr/bin/env bash
# Read-only health check for a Celestia Fibre server.
# Nothing is written, restarted or signed. Exit 0 = healthy, 1 = a check failed.
set -uo pipefail

# ----------------------------
# Configuration
# ----------------------------

FIBRE_SERVICE="${FIBRE_SERVICE:-fibre}"
FIBRE_ADDR="${FIBRE_ADDR:-127.0.0.1:7980}"
APP_RPC="${APP_RPC:-http://127.0.0.1:26657}"   # celestia-appd RPC; skipped if unreachable
CHECK_REGISTRATION="${CHECK_REGISTRATION:-1}"  # set to 0 on a Fibre-only host

FAILED=0
ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*"; }
fail() { echo "  ✗ $*"; FAILED=1; }

echo "== Celestia Fibre Health Check =="
echo

# ----------------------------
# App version
# ----------------------------

echo "[+] App version ($APP_RPC)"

APP_VERSION=$(curl -sf -m 5 "$APP_RPC/abci_info" | jq -r '.result.response.app_version // empty' 2>/dev/null || true)

if [[ -z "$APP_VERSION" ]]; then
  warn "could not read app_version (normal on a Fibre-only host)"
elif [[ "$APP_VERSION" -ge 10 ]]; then
  ok "app_version $APP_VERSION, Fibre available"
else
  fail "app_version $APP_VERSION, Fibre needs 10 or higher"
fi

# ----------------------------
# Service and port
# ----------------------------

echo
echo "[+] Service and port"

if systemctl is-active --quiet "$FIBRE_SERVICE"; then
  ok "$FIBRE_SERVICE is running"
else
  fail "$FIBRE_SERVICE is not running  →  journalctl -u $FIBRE_SERVICE -n 50"
fi

PORT="${FIBRE_ADDR##*:}"
if ss -ltnH | awk '{print $4}' | grep -Eq "(:|\])$PORT$"; then
  ok "listening on :$PORT"
else
  fail "nothing is listening on :$PORT"
fi

# ----------------------------
# gRPC health (celestia-app v10.5.0+)
# ----------------------------

echo
echo "[+] gRPC health"

if command -v grpc_health_probe >/dev/null 2>&1; then
  if grpc_health_probe -addr="$FIBRE_ADDR" -tls -tls-no-verify >/dev/null 2>&1; then
    ok "ready"
  else
    fail "not ready, the Fibre log names the failing check"
  fi
  if grpc_health_probe -addr="$FIBRE_ADDR" -tls -tls-no-verify -service=fibre-liveness >/dev/null 2>&1; then
    ok "live"
  else
    fail "liveness probe failed"
  fi
else
  warn "grpc_health_probe not installed, skipping (needs Fibre from v10.5.0)"
fi

# ----------------------------
# On-chain registration
# ----------------------------

if [[ "$CHECK_REGISTRATION" == "1" ]]; then
  echo
  echo "[+] On-chain registration"

  if command -v celestia-appd >/dev/null 2>&1; then
    VALCONS=$(celestia-appd comet show-address 2>/dev/null || true)
    HOST_LINE=$(celestia-appd q valaddr provider "$VALCONS" 2>/dev/null | grep -i -m1 'host' || true)
    if [[ -n "$HOST_LINE" ]]; then
      ok "registered: $(echo "$HOST_LINE" | sed 's/^[[:space:]]*//')"
    else
      fail "no Fibre host registered for $VALCONS  →  celestia-appd tx valaddr set-host <host>:7980"
    fi
  else
    warn "celestia-appd not found, skipping (set CHECK_REGISTRATION=0 on a Fibre-only host)"
  fi
fi

echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "✓ Fibre health check passed"
else
  echo "✗ Fibre health check failed"
fi
exit "$FAILED"
