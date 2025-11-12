<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:10002B,50:4B0082,100:7A1FF3&height=180&section=header&text=Celestia%20Tools%20&fontSize=46&fontAlignY=50&fontColor=FFFFFF" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/astrosynx/Logo/main/celestia-logo.png" width="180" alt="Celestia Logo"/>
</p>

<p align="center">
  <b><i style="color:white; text-shadow: 0px 0px 12px #7A1FF3;">Building and managing Celestia nodes and tools with precision and performance.</i></b>
</p>

---

## 🌐 Celestia Network Endpoints by Astrosynx

### **Mainnet**
> 🔗 [Astrosynx Celestia Mainnet Services](https://astrosynx.gitbook.io/services/documentation/mainnet-guides/celestia)

| Service | URL |
|----------|-----|
| 🧩 Addrbook/Seed/Peer | [https://astrosynx.gitbook.io/services/documentation/mainnet-guides/celestia](https://astrosynx.gitbook.io/services/documentation/mainnet-guides/celestia/public-endpoints-and-peering) |
| ⚙️ RPC | [`https://celestia-mainnet-rpc.astrosynx.com/`](https://celestia-mainnet-rpc.astrosynx.com/) |
| 💬 gRPC | `celestia-mainnet-grpc.astrosynx.com:443` |
| 🌐 API | [`https://celestia-mainnet-api.astrosynx.com/`](https://celestia-mainnet-api.astrosynx.com/) |


### **Testnet**
> 🔗 [Astrosynx Celestia Testnet Services](https://astrosynx.gitbook.io/services/documentation/testnet-guides/celestia)

| Service | URL |
|----------|-----|
| 🧩 Addrbook/Seed/Peer | [https://astrosynx.gitbook.io/services/documentation/testnet-guides/celestia](https://astrosynx.gitbook.io/services/documentation/testnet-guides/celestia/public-endpoints-and-peering) |
| ⚙️ RPC | [`https://celestia-testnet-rpc.astrosynx.com/`](https://celestia-testnet-rpc.astrosynx.com/) |
| 💬 gRPC | `celestia-testnet-grpc.astrosynx.com:443` |
| 🌐 API | [`https://celestia-testnet-api.astrosynx.com/`](https://celestia-testnet-api.astrosynx.com/) |

---

### 🗂 Snapshots
| Network | Snapshot URL | Frequency | Pruning | Indexer |
|--------|--------------|-----------|---------|---------|
| **Mainnet** | https://mainnet-snap.astrosynx.com/celestia/ | Every 4 hours | `custom: 100/10` | `null` |
| **Testnet** | https://testnet-snap.astrosynx.com/celestia/ | Every 4 hours | `custom: 100/10` | `null` |

### 🏛 Archive Snapshots (Full History)
> Contains **both Mainnet and Testnet** archive snapshots.

| Network | Snapshot URL | Frequency | Pruning | Indexer |
|----------|---------------|-----------|----------|----------|
| **Mainnet** | https://archive-snap.astrosynx.com/celestia-mainnet/ | Every 5 days | `nothing` | `kv` |
| **Testnet** | https://archive-snap.astrosynx.com/celestia-testnet/ | Every 5 days | `nothing` | `kv` |

---

## ⚙️ Quick Start

```bash
# Connect to Astrosynx Celestia Mainnet RPC
celestia-appd status --node https://celestia-mainnet-rpc.astrosynx.com:443
```

```bash
# Or query via LCD API
curl https://celestia-mainnet-api.astrosynx.com:443/cosmos/base/tendermint/v1beta1/blocks/latest
```

```bash
# Query Node Version and staking parameters
celestia-appd version
celestia-appd query staking params --node https://celestia-mainnet-rpc.astrosynx.com:443
```

---

### ⚠️ Common Errors & Fixes

| Error | Cause | Solution |
|-------|-------|---------|
| `insufficient fees` | Not enough fees for the transaction | Increase `--fees` when delegating or sending transactions |
| `failed to connect to RPC` | RPC is unavailable or blocked by firewall | Check the URL and open the required ports (443, 26657, 26658) |
| `snapshot not found / download failed` | URL is unavailable or snapshot was removed | Use an updated mirror or the archive snapshot |
| `node stuck / not syncing` | Incorrect peers or corrupted data | Clear the directory `~/.celestia-app` and restore from snapshot |
| `permission denied` | Node does not have permissions for the directory | Run commands as the user owning `$HOME/.celestia-app` or use `sudo` carefully |

---
 
  <p align="center"> <i>Maintained with 💜 by <b>Astrosynx</b> — Validator Infrastructure & Tools</i><br> <a href="https://astrosynx.com" target="_blank">🌐 astrosynx.com</a> • <a href="https://github.com/astrosynx" target="_blank"> <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/github/github-original.svg" width="18" style="vertical-align:middle; margin-right:4px;"> GitHub / Astrosynx </a> </p>

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:7A1FF3,100:10002B&height=120&section=footer"/>
</p>
  
  
