# hc-mihomo patches (hidden)

This branch holds FreeBSD/OPNsense build patches. The CI workflow on `master` checks out **this** branch, downloads upstream mihomo + sing-tun, applies the patches, and builds FreeBSD binaries.

| File | Role |
|------|------|
| `last_version` | Last released upstream mihomo version built by CI |
| `mihomo.patch` | Patches applied inside the mihomo tree |
| `sing-tun.patch` | FreeBSD TUN implementation for metacubex/sing-tun |

## How to refresh patches

1. Download matching mihomo / sing-tun tags (see `go.mod` in mihomo for the sing-tun version).
2. Apply current patches, edit sources, regenerate:

```bash
diff -ruN clean/ patched/ > mihomo.patch   # or: git diff --no-index
```

3. Paths inside the patch must be `a/path` / `b/path` so `patch -p1` works from the project root (as in CI).
4. Keep `*.patch` as LF (see `.gitattributes`).

Do not commit local `work/` trees used for experimenting.

---

## `mihomo.patch`

### FreeBSD process lookup
- Renames `process_freebsd_amd64.go` → `process_freebsd.go` and selects struct offsets by `hw.machine` (amd64/arm64/riscv/i386).
- Lets find-process work on non-amd64 FreeBSD (OPNsense appliances).

### Redirect / pf
- FreeBSD `redir` uses pf `DIOCNATLOOK` (or falls back to local addr for ipfw) instead of Linux `SO_ORIGINAL_DST`.
- Skips Redir UDP listener on FreeBSD (not supported the same way).

### TUN config: `fib-index`
- Adds `FIBIndex` on `listener/config/tun.go` and passes it into sing-tun options (FreeBSD routing FIBs for auto-route).

### Several TUN listeners: interface names
- `CalculateInterfaceName` on FreeBSD no longer returns a single `"Meta"`.
- Allocates `Meta0`, `Meta1`, … like Darwin `utunN`, so multiple TUN listeners (and leftovers) do not collide on one name.

### Shutdown closes listener TUNs
- `listener.Cleanup()` used to close **only** the global TUN (`tun:`).
- On Ctrl-C / `Shutdown`, inbound `listeners` with `type: tun` were never `Close()`’d; the iface could survive process teardown.
- Cleanup now closes all `inboundListeners` as well (same path as global TUN destroy).

---

## `sing-tun.patch`

### FreeBSD TUN stack
- Adds `tun_freebsd.go` / gVisor bits, build tags, and gateway helpers (Darwin-like gateway = interface address).
- Opens `/dev/tun`, optional rename via `SIOCSIFNAME`, MTU, ND6 flags, `TUNSIFPID`, FIB helpers, auto-route, DNS hijack hooks.

### Addresses (`inet4-address` / `inet6-address`)
- Prefer `/sbin/ifconfig … inet|inet6` so listener TUN (often without auto-route) still gets the configured address on OPNsense.
- Fallback to `SIOCAIFADDR` with a proper IPv4 broadcast; then `ifconfig up`.

### Destroy / Close (no leftover ifaces)
- Remember the **real** iface name after rename.
- **Close order:** close `/dev/tun` fd first (unblocks stack `Read`), then destroy — destroying while `Read` is blocked deadlocks `ifconfig` / `SIOCIFDESTROY`.
- `SIOCIFDESTROY` uses a **32-byte** `ifreq` buffer (WireGuard-style). A 16-byte name-only buffer fails kernel `copyin`.
- Fallback: `/sbin/ifconfig <name> destroy` (3s timeout on shell commands so stop cannot hang forever).
- `closeOnce` so double-close from stack + listener is safe.

### Related CI step (not in the patch file)
- Workflow copies `monitor_darwin.go` → `monitor_freebsd.go` after applying `sing-tun.patch`.

---

## Listener TUN notes (OPNsense)

- Prefer top-level `tun:` for the common case; `listeners` / `type: tun` is for advanced multi-TUN setups.
- Set explicit `inet4-address` (no default on listeners). Use a `/30` **outside** `fake-ip-range` (e.g. fake-ip `198.18.0.1/16` → listener `198.19.0.1/30`).
- Optional unique `device` names; if empty, FreeBSD gets `Meta0`, `Meta1`, …
- Do not use `device: tun` (rejected by the FreeBSD TUN code).

---

## RU кратко

Ветка `hidden` — только патчи для FreeBSD-сборки.  
`mihomo.patch`: process/redir/FIB, уникальные имена MetaN, **Cleanup закрывает и listener TUN**.  
`sing-tun.patch`: реализация TUN, ifconfig для адресов, корректный destroy после close fd (буфер ifreq 32 байта).  
Каталог `work/` для локальных экспериментов в git не коммитить.
