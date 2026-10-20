# AGENTS.md

## Local ImmortalWrt Build Notes

This repository is a build recipe, not a full ImmortalWrt source tree. The
local build should clone the upstream source, apply this repo's config and DIY
scripts, then collect firmware artifacts back into this workspace.

## Known-Good Local Build

- Build target: `128M-Ubootmod`
- Partition variant: default 112M UBI
- DTS check for 112M:
  - `target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts`
  - `model = "Cudy TR3000 v1 ubi 112M";`
  - `reg = <0x5c0000 0x7000000>;`
- Upstream repo: `https://github.com/padavanonly/immortalwrt-mt798x-6.6`
- Branch: `openwrt-24.10-6.6`
- Docker base image used successfully: `ubuntu:22.04`
- Persistent work/cache directory:
  `.build/openwrt-workdir`
- Artifact output directory:
  `firmware_collection/`
- VoHive is no longer included. The local build script retains cleanup of
  its old checkout and cached artifacts to support existing build directories.
- OpenClash and the old `luci-app-wg-reality` are no longer included.
  Use private PassWall2 26.10.20-r4 at add8da27e55f78d38d507dfaeb54279840096516
  with the SHA-256 pinned official ARM64 Xray 26.10.17 prerelease.
  `scripts/prepare-passwall2.sh` also pins the PassWall dependency feed.
  `scripts/prepare-passwall2-golang.sh` pins the compatible Go tooling;
  geoview 0.2.8 cannot build with the original Go 1.23 feed.
  The r4 monitor adds authenticated, read-only telemetry and optional Bandix
  device traffic. Its exit probe uses Xray's loopback SOCKS input only. Bandix
  traffic collection is enabled separately; do not enable DNS logging or disk
  history just to use the dashboard.
- `diy-part2.sh` repairs the upstream literal `ifup` file at
  `package/network/config/netifd/files/sbin/ifdown` into the intended symlink.
- Preserve `/etc/config/passwall2`, `/etc/passwall2/`, and old
  `/etc/wg-reality/` backups during upgrades. The dedicated UCI default enables
  the new guard before retiring old includes and switches Xray to /usr/bin/xray.
- The PassWall2 repository is private. Actions checks out its pinned commit using
  the `PASSWALL2_DEPLOY_KEY` secret, a read-only deploy key on that repository.
  `PASSWALL2_SOURCE` identifies the authenticated local checkout; local Docker
  builds mount it read-only without passing credentials.
  Do not replace it with a broad personal token or change repository visibility.

The successful 112M build produced:

```text
firmware_collection/immortalwrt-mediatek-filogic-20260628-cudy_tr3000-v1-ubootmod-squashfs-sysupgrade.bin
sha256: 1f77be0309a6c70969f6a5d490bc4f426745b3f07e100477034f00dfd6697951
```

## Rebuild Command

The 2026-10-20 PassWall2 migration was validated with both configurations
through `make defconfig`, plus `make package/xray-core/download` using the
pinned hash. Disposable OpenWrt-container tests cover fresh install, retained
node migration, and preserving the old guard when new-guard activation fails
(`scripts/test-passwall2-migration.sh`). Xray 26.10.17 passed real-router TCP,
UDP, proxy-stop recovery and unreachable-relay/DNS-block tests. These changes
have not yet produced or flashed a complete firmware image; the artifact
listed above is the older known-good build.

Use Docker with daemon access. The current user may not have direct
`/var/run/docker.sock` permission, so Codex may need escalated execution for
Docker commands.

Rebuild the default 112M Ubootmod image from the repository root with:

```sh
./scripts/local-build.sh
```

Set `DEVICE_INPUT=128M` or `DEVICE_INPUT=all` when explicitly needed.
If Docker requires sudo, run with `DOCKER="sudo docker" ./scripts/local-build.sh`.

## Build Flow To Preserve

The local build should follow the GitHub Actions flow in
`.github/workflows/openwrt-builder.yml`:

1. Install Ubuntu 22.04 build dependencies.
2. Clone upstream source into `.build/openwrt-workdir/openwrt` mounted as
   `/workdir/openwrt` inside Docker.
3. Copy this repo's config into the OpenWrt tree.
4. Run `diy-part1.sh` before feeds update.
5. Run `./scripts/feeds update -a`.
6. Run `./scripts/feeds install -a`.
7. Run `diy-part2.sh` after feeds install.
8. Copy `config/128muboot.config` to `.config`.
9. Run `make defconfig`.
10. Run `make download -j$(nproc)`.
11. Run `make -j$(nproc) CC="ccache gcc" CXX="ccache g++"`.
12. If parallel build fails, rerun `make -j1 V=s`.
13. Copy `bin/targets/**/**sysupgrade.bin` into `firmware_collection/`.

## 122M Variant

Do not accidentally build the 122M variant unless explicitly requested. To make
122M, uncomment or apply the existing `diy-part2.sh` sed line:

```sh
sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0x7a40000>;/' \
  target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts
```

The default checked and built variant is 112M.

## Practical Notes

- Expect a long first build because Rust/LLVM host compilation is enabled by
  the selected package set.
- The first successful build used about 41G in the OpenWrt work directory.
- The machine had enough resources during the run: 24 CPUs, 94GiB RAM, and more
  than 500G free disk.
- Keep `.build/openwrt-workdir` if future rebuild speed matters.
- `.build/` and `firmware_collection/` are generated output and are ignored by
  git.
