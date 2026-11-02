#!/usr/bin/env bash
# Read-only sync check for a celestia-appd node: compares the local height
# with a reference RPC. Exit 0 = in sync, 1 = behind, wrong network or unreachable.
set -uo pipefail

# ----------------------------
# Configuration
# ----------------------------

LOCAL_RPC="${LOCAL_RPC:-http://127.0.0.1:26657}"
REF_RPC="${REF_RPC:-https://celestia-mainnet-rpc.astrosynx.org}"   # Mocha: https://celestia-testnet-rpc.astrosynx.org
WARN_LAG="${WARN_LAG:-5}"     # blocks
FAIL_LAG="${FAIL_LAG:-50}"    # blocks

status() {
  curl -sf -m 5 "$1/status" 2>/dev/null
}

echo "== Celestia Sync Check =="
echo

# ----------------------------
# Local node
# ----------------------------

echo "[+] Local node ($LOCAL_RPC)"

LOCAL=$(status "$LOCAL_RPC" || true)
if [[ -z "$LOCAL" ]]; then
  echo "  ✗ local RPC not reachable"
  exit 1
fi

LOCAL_NET=$(echo "$LOCAL" | jq -r '.result.node_info.network')
LOCAL_HEIGHT=$(echo "$LOCAL" | jq -r '.result.sync_info.latest_block_height')
CATCHING_UP=$(echo "$LOCAL" | jq -r '.result.sync_info.catching_up')

echo "  ✓ chain $LOCAL_NET, height $LOCAL_HEIGHT"
if [[ "$CATCHING_UP" == "true" ]]; then
  echo "  ! node reports catching_up = true"
fi

# ----------------------------
# Reference
# ----------------------------

echo
echo "[+] Reference ($REF_RPC)"

REF=$(status "$REF_RPC" || true)
if [[ -z "$REF" ]]; then
  echo "  ✗ reference RPC not reachable, set REF_RPC to another endpoint"
  exit 1
fi

REF_NET=$(echo "$REF" | jq -r '.result.node_info.network')
REF_HEIGHT=$(echo "$REF" | jq -r '.result.sync_info.latest_block_height')

if [[ "$REF_NET" != "$LOCAL_NET" ]]; then
  echo "  ✗ reference is on $REF_NET, local node is on $LOCAL_NET"
  exit 1
fi
echo "  ✓ chain $REF_NET, height $REF_HEIGHT"

# ----------------------------
# Lag
# ----------------------------

echo
LAG=$((REF_HEIGHT - LOCAL_HEIGHT))

if [[ "$LAG" -le "$WARN_LAG" ]]; then
  echo "✓ In sync ($LAG blocks behind the reference)"
  exit 0
elif [[ "$LAG" -le "$FAIL_LAG" ]]; then
  echo "! Slightly behind: $LAG blocks. Check peers and disk I/O."
  exit 0
else
  echo "✗ Behind by $LAG blocks"
  exit 1
fi
