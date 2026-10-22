<a href="../README.md"><img src="../assets/banner.svg" width="100%" alt="Astrosynx Celestia Tools"></a>

[← Celestia Tools](../README.md) · **Fibre off the validator host**

# Running Fibre on a separate host

Fibre is the data-availability service introduced with **app version 10**. Rollups upload and download blob shards directly from validator-run Fibre servers, and every bonded validator is expected to run one. The simplest setup puts Fibre on the validator machine. This guide covers the next step: moving Fibre to its own server and connecting it back to the validator over a private link.

> [!NOTE]
> **Status:** Fibre (app v10) is live on **mainnet** (`celestia`) since 20 October 2026, and on **Mocha** (`mocha-5`). The current release is **`v10.5.0`** on mainnet and **`v10.5.0-mocha`** on Mocha. The commands below use mainnet. Notes show the Mocha values.

<img src="../assets/fibre-topology.svg" width="100%" alt="Fibre on host B, validator on host A, connected over a private VLAN">

## Why split them

| Concern | On one host | Split |
|---|---|---|
| **Memory** | Fibre's receive buffers can reach roughly `max_connections × max_concurrent_streams × 132 MiB`, about 27 GiB at the defaults. That memory is taken from the node. | Fibre's memory spikes stay on its own host. |
| **CPU** | Upload verification competes with block production. | Consensus keeps its cores. |
| **Disk and bandwidth** | Shard storage and blob traffic share the validator's NVMe and uplink. | Both scale on their own. |
| **Exposure** | Port `7980` is open to the internet on the machine that holds the consensus key. | The validator has no public Fibre port at all. |

At launch-day load this split is about headroom rather than necessity. It becomes important as rollups move blob traffic to Fibre and throughput grows.

## The three connections

| Link | Port | Security | Rule |
|---|---|---|---|
| Clients → Fibre | `7980` | TLS. The certificate is endorsed by the validator's consensus key, so no public CA is needed. | Open to the internet on host B. |
| Fibre → app gRPC | `9090` | **Plaintext.** | Private network only. Never expose it. |
| Fibre → signer (privval gRPC) | `26669` | **mTLS required.** The node refuses to start if the signer listens on a non-loopback address without full TLS. | Private network only, firewalled to host B. |

The signer endpoint signs raw bytes with the consensus key. mTLS authenticates only after a TCP connection is accepted, so the firewall and private network are part of the protection, not optional extras.

## Before you start

**Hardware for host B.** Run these checks on the actual machine, not from the provider's spec sheet:

```bash
# Both flags must be printed: gfni and sha_ni
grep -o -w -E 'gfni|sha_ni' /proc/cpuinfo | sort -u

nproc                  # 8–16 high-clock cores are recommended
free -g                # leave room for the ~27 GiB worst case at default limits
ldd --version | head -1  # glibc 2.34 or newer
```

The celestia-app repository also ships `tools/cpu_requirements` for a full CPU check. Disk size and traffic depend on your stake and the network's target throughput. Use the sizing calculator in the [official Fibre docs](https://docs.celestia.org/operate/consensus-validators/fibre/).

**Private link.** Use the provider's private VLAN between your servers if it has one. They are usually free, unmetered, and use the same NICs. If not, a WireGuard tunnel works. The examples below use:

| Host | Role | Private address |
|---|---|---|
| A | celestia-appd (validator) | `10.10.0.1` |
| B | Fibre server | `10.10.0.2` |

Check that the private interface comes back on its own after a reboot of **both** hosts before going further: `ip -br addr`.

## 1. Certificates

Create a small private CA **on a machine that is neither host**, such as an offline workstation. Keep `ca.key` off both servers. You only need it to issue or rotate certificates.

```bash
mkdir -p fibre-pki && cd fibre-pki

# CA (EC P-256, 10 years)
cat > ca.ext <<'EOF'
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
EOF
openssl ecparam -name prime256v1 -genkey -noout -out ca.key
openssl req -new -key ca.key -subj "/CN=fibre-signer-ca" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -days 3650 -sha256 -extfile ca.ext -out ca.pem

# Server certificate for the node (host A). SAN = the exact address Fibre dials.
cat > node.ext <<'EOF'
subjectAltName = IP:10.10.0.1
extendedKeyUsage = serverAuth
keyUsage = critical, digitalSignature
EOF
openssl ecparam -name prime256v1 -genkey -noout -out node.key
openssl req -new -key node.key -subj "/CN=celestia-signer" -out node.csr
openssl x509 -req -in node.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -days 825 -sha256 -extfile node.ext -out node.pem

# Client certificate for Fibre (host B)
cat > fibre.ext <<'EOF'
subjectAltName = IP:10.10.0.2
extendedKeyUsage = clientAuth
keyUsage = critical, digitalSignature
EOF
openssl ecparam -name prime256v1 -genkey -noout -out fibre.key
openssl req -new -key fibre.key -subj "/CN=fibre-server" -out fibre.csr
openssl x509 -req -in fibre.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -days 825 -sha256 -extfile fibre.ext -out fibre.pem

# Sanity check
openssl verify -CAfile ca.pem node.pem fibre.pem
```

If Fibre will reach the node by DNS name, use `DNS:<name>` in `node.ext` instead of `IP:`. The SAN must match what Fibre dials exactly, otherwise verification fails.

Copy only what each host needs, readable by the service user only:

| Host A (node) → `~/.celestia-app/config/tls/` | Host B (Fibre) → `/etc/fibre/tls/` |
|---|---|
| `ca.pem`, `node.pem`, `node.key` | `ca.pem`, `fibre.pem`, `fibre.key` |

```bash
chmod 600 *.key
```

## 2. Firewall on host A

```bash
sudo ufw allow from 10.10.0.2 to 10.10.0.1 port 9090 proto tcp
sudo ufw allow from 10.10.0.2 to 10.10.0.1 port 26669 proto tcp
```

Make sure no broader rule opens `9090` or `26669` on the public interface. On host B, open only `7980/tcp` publicly.

## 3. Prepare host B

Install the Fibre binary from the same release as your celestia-appd (`v10.5.0` on mainnet, `v10.5.0-mocha` on Mocha). The release archive is `fibre_Linux_x86_64.tar.gz` or `fibre_Linux_arm64.tar.gz`. Follow the steps in the [official guide](https://docs.celestia.org/operate/consensus-validators/fibre/). Then create the service. **Do not start it yet.**

```bash
sudo tee /etc/systemd/system/fibre.service > /dev/null <<EOF
[Unit]
Description=Celestia Fibre server
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=$(which fibre) start \\
  --home $HOME/.celestia-fibre \\
  --app-grpc-address 10.10.0.1:9090 \\
  --signer-grpc-address 10.10.0.1:26669 \\
  --signer-grpc-ca-file /etc/fibre/tls/ca.pem \\
  --signer-grpc-cert-file /etc/fibre/tls/fibre.pem \\
  --signer-grpc-key-file /etc/fibre/tls/fibre.key \\
  --server-listen-address 0.0.0.0:7980
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
```

The three `--signer-grpc-*-file` flags must be set together. They can also live in `server_config.toml` as `signer_grpc_ca_file`, `signer_grpc_cert_file` and `signer_grpc_key_file`.

## 4. Cutover

The node restart in step 4.2 costs a few blocks, so plan it. Run the steps in this order:

**4.1 Stop the old Fibre on host A**

```bash
sudo systemctl disable --now fibre
```

**4.2 Move the node's endpoints to the private address**

In `~/.celestia-app/config/config.toml`:

```toml
priv_validator_grpc_laddr          = "10.10.0.1:26669"
priv_validator_grpc_cert_file      = "config/tls/node.pem"
priv_validator_grpc_key_file       = "config/tls/node.key"
priv_validator_grpc_client_ca_file = "config/tls/ca.pem"
```

In `~/.celestia-app/config/app.toml`:

```toml
[grpc]
enable = true
address = "10.10.0.1:9090"
```

Anything else on host A that used `127.0.0.1:9090`, such as a bridge node or monitoring, must now use `10.10.0.1:9090`.

```bash
sudo systemctl restart celestia-appd
journalctl -u celestia-appd -f -o cat     # the node starts and keeps signing blocks
```

**4.3 Check mTLS from host B before starting Fibre**

```bash
# With the client cert: expect "Verify return code: 0 (ok)"
openssl s_client -connect 10.10.0.1:26669 -CAfile /etc/fibre/tls/ca.pem \
  -cert /etc/fibre/tls/fibre.pem -key /etc/fibre/tls/fibre.key </dev/null 2>/dev/null | grep "Verify return"

# Without it: the handshake must be rejected
openssl s_client -connect 10.10.0.1:26669 -CAfile /etc/fibre/tls/ca.pem </dev/null
```

**4.4 Start Fibre on host B**

```bash
sudo systemctl enable --now fibre
journalctl -u fibre -f -o cat
```

Look for the signer becoming ready over an mTLS transport and the server listening on `7980`.

**4.5 Point the chain at host B**

Run this only once `7980` on host B answers from the outside:

```bash
nc -vz <public host of B> 7980

celestia-appd tx valaddr set-host <public host of B>:7980 \
  --from <validator wallet> --chain-id celestia --fees 2000utia -y    # Mocha: --chain-id mocha-5
```

Until this transaction lands, clients keep connecting to the old address on host A. Use a DNS name rather than an IP. A later move then only needs a DNS change, with no new transaction.

**4.6 Verify**

```bash
VALCONS=$(celestia-appd comet show-address)
celestia-appd query valaddr provider $VALCONS    # host is B's public address
```

Since `v10.5.0`, Fibre serves the standard gRPC health service on `7980`. Use it for monitoring. When the server is not ready, the log names the failing check.

```bash
# on host B, with grpc_health_probe installed
grpc_health_probe -addr=127.0.0.1:7980 -tls -tls-no-verify                          # readiness
grpc_health_probe -addr=127.0.0.1:7980 -tls -tls-no-verify -service=fibre-liveness   # liveness
```

Then reboot host B once and confirm that the private interface, firewall and Fibre all come back on their own.

## Field notes

These come from a public report by **unitynodes**, who moved Fibre off their Mocha validator in October 2026, combined with our own checklist:

- **Vendor spec sheets often omit GFNI and SHA-NI.** Confirm them on the delivered server before you migrate anything.
- **The TLS handshake cost was negligible.** Client-side handshake latency was the same before and after the move, within about 2 ms.
- **At current Mocha load Fibre is light.** It used well under 1% CPU and about 200 MB of RAM. Size for the worst case anyway, because the buffers are allocated under load, not at idle.
- **Even a short link flap costs blocks.** A 5–7 second outage on each bonded port, one after the other, cost about ten blocks. Ask the provider to schedule network work, and do not run the validator on a single uplink.
- **Forgetting `set-host` is the most common mistake.** Everything looks healthy, but clients still go to the old address.
- **Stick to one Fibre server per validator for now.** Each server currently derives the full storage budget as if it were the only one, so extra servers would each reserve the same storage. Splitting the budget and routing between servers is tracked in celestia-app issue [#7690](https://github.com/celestiaorg/celestia-app/issues/7690). Once that lands, servers in several locations become practical, and a WireGuard mesh will matter more than a single VLAN.

## Upgrading

celestia-appd and Fibre come from the same release and are upgraded together. On a split setup the order is: upgrade and restart celestia-appd on host A, confirm it is signing, then upgrade and restart Fibre on host B.

Releases can add new config keys. After installing new binaries, let them fill in anything missing. Existing values are kept and backups are made:

```bash
# host A
celestia-appd config sync --home ~/.celestia-app --dry-run
celestia-appd config sync --home ~/.celestia-app

# host B (run with the new celestia-appd binary copied there, or sync server_config.toml by hand)
celestia-appd config sync --fibre-home ~/.celestia-fibre --dry-run
celestia-appd config sync --fibre-home ~/.celestia-fibre
```

`v10.5.0` adds a `[health]` table to `server_config.toml`. The defaults apply if it is missing. It also requires `object_storage.endpoint` to be an `https://` URL if you use S3 or R2.

## Rotating certificates

Certificates are loaded at startup. To rotate, issue new `node.pem` and `fibre.pem` from the same CA, replace the files, and restart celestia-appd and then Fibre. The leaf certificates above are valid for 825 days. Put a reminder in your calendar.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| celestia-appd refuses to start after step 4.2 | The signer address is non-loopback but one of the three TLS file keys is missing or unreadable |
| `s_client` shows a SAN or hostname error | `node.ext` SAN does not match the address in `--signer-grpc-address` |
| Fibre: signer connection failed | Firewall on A, wrong private IP, or the client certificate is not signed by the CA the node trusts |
| Fibre: app gRPC connection refused | `[grpc] address` in `app.toml` still on `127.0.0.1`, or the node was not restarted |
| `derived storage budget is 0` | The validator is not bonded, or Fibre is pointed at the wrong network |
| Fibre runs but receives no uploads | `set-host` not sent, or `7980` not reachable from outside |

## Sources

- [Run a Fibre server](https://docs.celestia.org/operate/consensus-validators/fibre/), Celestia docs
- [privval gRPC TLS guide](https://github.com/celestiaorg/celestia-core/blob/main/docs/guides/privval-grpc-tls.md), celestia-core
- [Moving Fibre off the validator host: private VLAN + mTLS (mocha-5)](https://forum.celestia.org/t/moving-fibre-off-the-validator-host-private-vlan-mtls-mocha-5/2314), field report by unitynodes on the Celestia forum

<sub>Commands are examples for mainnet. Check flags against the release you run. <a href="../README.md">← Back to Celestia Tools</a></sub>
