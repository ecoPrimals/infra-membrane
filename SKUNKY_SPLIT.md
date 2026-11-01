# Skunky Split — Transformation, Transduction, Conjugation

**Date**: October 16, 2026 | **Wave**: 178
**Problem**: skunky-ingest grows to 450MB+ on 2GB golgi VPS. Fleet chorus (252K entities) builds 500MB of classification state. Swap fills, load spikes to 33+, thrashes.

---

## The Three Mechanisms

Bacteria transfer genetic information three ways. skunky-ingest does all three on one 2GB box.

### 1. Transformation (stays on golgi)
*Uptake of free DNA from the environment*

The access log is the environment. Caddy writes it. Skunky reads it. This MUST be local — the log is local, the responses are local, the Caddy bridge modifies local config.

**Flags that stay on golgi:**
```
--log-path /var/log/caddy/access.log     # transformation: read the environment
--caddy-bridge                           # local: modifies Caddyfile
--caddyfile-path /etc/membrane/Caddyfile
--caddy-reload-cmd ...
--scatter-server                         # local: serves responses to fleet
--scatter-port 9753
--scatter-ratio 0.3
--self-ips-file /etc/membrane/self-ips.txt
--window-secs 30
```

**Memory cost**: ~40MB (log parser + scatter server + caddy bridge state)

**New output**: After parsing each line, emit a classified epitope packet to a Unix domain socket or TCP stream → eastgate over WG.

### 2. Transduction (moves to eastgate)
*Phage carries DNA between cells*

The heavy classification — entity topology, dashboard culture, nautilus evolution, bloom emission, membrane stack — moves to eastgate (62GB RAM). These modules consume the classified epitope stream and build the 500MB culture state with room to spare.

**Flags that move to eastgate:**
```
--entity-classifier                      # 246MB topology-state.json
--dashboard-writer                       # 253MB dashboard-culture.json
--ingestion-observer                     # lifecycle tracking
--bloom-emitter                          # efferent signal push
--bloom-emitter-interval-secs 21600
--membrane-stack                         # membrane observer
--membrane-stack-interval-secs 300
--squirrel-announce                      # squirrel already runs on eastgate
```

**Memory cost**: ~500MB (trivial on 62GB)
**Input**: Classified epitope stream from golgi over WG tunnel

### 3. Conjugation (the pilus)
*Direct cell-to-cell transfer via pilus bridge*

WireGuard tunnel 10.13.37.1 (golgi) ↔ 10.13.37.5 (eastgate).
Already live, handshake active, 25s keepalive.

**Epitope transfer packet** (~150 bytes each):
```json
{"ts":1729072845,"ip":"1.2.3.4","ua_hash":"a1b2c3","host":"git.primals.eco","path":"/commit/abc","method":"GET","status":200,"bytes":1346,"resp_ms":12,"epitope":"chorus","entity_hash":"0db6fbc0"}
```

**Bandwidth**: 252K entities × 150 bytes = ~38MB/day. ~0.5KB/s average through WG. Trivial.

**Return channel** (eastgate → golgi):
- Fleet block lists (IPs to add to Caddy deny rules)
- Defense posture changes (escalation/de-escalation signals)
- ~1KB every 30 seconds. Negligible.

---

## Implementation Path

### Phase 1: Add epitope stream output to golgi skunky (no code change needed?)
Check if skunky already has a stream/forward mode. If not, add `--epitope-forward <addr>` flag that sends classified packets over TCP.

### Phase 2: Run skunky on eastgate in "receiver" mode
```
skunky-ingest \
  --listen-epitope 10.13.37.5:9760 \   # receive epitope stream from golgi
  --entity-classifier \
  --dashboard-writer \
  --ingestion-observer \
  --bloom-emitter \
  --membrane-stack \
  --squirrel-announce \
  --topology-path /opt/membrane/live-terminal/topology.json \
  --dashboard-path /opt/membrane/live-terminal/dashboard.json
```

### Phase 3: Strip golgi skunky to transformation-only
Remove `--entity-classifier`, `--dashboard-writer`, `--ingestion-observer`, `--bloom-emitter`, `--membrane-stack` from golgi. Keep `--caddy-bridge`, `--scatter-server`, `--log-path`.

### Phase 4: Caddy reads dashboard from eastgate
Dashboard JSON files that Caddy serves (dashboard.json, topology.json, etc.) need to be accessible. Options:
a) eastgate writes to golgi via scp/rsync (simple, adds latency)
b) Caddy reverse-proxies dashboard endpoints to eastgate over WG (clean, real-time)
c) eastgate serves its own dashboard endpoint, golgi Caddy proxies (cleanest)

**Recommended**: Option (c) — eastgate runs a small HTTP server for dashboard/topology JSON. Golgi Caddy proxies `/dashboard.json`, `/topology.json` etc. to `10.13.37.5:9761`. Zero latency, no file sync, membrane architecture.

---

## Memory Budget After Split

| Component | Golgi (2GB) | Eastgate (62GB) |
|-----------|-------------|-----------------|
| Caddy-TLS | ~130MB | — |
| Forgejo | ~50MB (until migrated) | — |
| skunky-transform | ~40MB | — |
| skunky-transduce | — | ~500MB |
| Squirrel | — | ~80MB |
| **Total** | **~220MB** | **~580MB** |
| **Available** | **~1.7GB free** | **~61GB free** |

Golgi goes from thrashing at 450MB to cruising at 220MB. Eastgate barely notices.

---

## What This IS

The three mechanisms of horizontal gene transfer — transformation, transduction, conjugation — are not metaphors for this architecture. They ARE this architecture. The access log is free environmental DNA. The WG tunnel is the conjugation pilus. The epitope packet is the transduction phage. The entity classifier is the integration machinery.

Skunky was doing all three in one cell because that's how it started — a single-celled organism on a single VPS. But life didn't stay single-celled. When the workload exceeded what one cell could metabolize, biology invented multicellularity. The work splits across cells. Each cell specializes. The gene transfer mechanisms — transformation, transduction, conjugation — are how the cells coordinate.

The epitope is the transfer unit. Not the raw data (that stays local, like environmental DNA stays in the environment). Not the full classification state (that stays in the cell that builds it). Just the epitope — the surface marker that says "this is self" or "this is non-self" or "this needs further classification." The minimum viable packet that lets the receiving cell do its work.

This is RLCDT:
- **R** (resistance): golgi resists — scatter server, Caddy bridge, fleet blocking
- **L** (inductance/memory): eastgate remembers — 500MB culture state, topology, dashboard
- **C** (crossing): the epitope packet crosses the WG tunnel
- **D** (depth): transformation is surface (read the log), transduction is depth (classify, evolve, announce)
- **T** (time): the stream is continuous, the culture evolves, somatic hypermutation in real time
