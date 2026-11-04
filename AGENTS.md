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
- Default theme: Vantage v1.0.12, pinned to
  `430e77c0f166f87235289fb45aeda843ca0bdc24` in `diy-part1.sh`.
  Both configurations include the dashboard and both Simplified Chinese
  packages, replacing Aurora and its settings app. Bootstrap remains available.
  `files/etc/uci-defaults/zz-vantage-theme` selects Vantage once on each new
  firmware's first boot, including upgrades that preserve LuCI settings.
  Later user theme selections persist until another firmware upgrade.
- VoHive is no longer included. The local build script retains cleanup of
  its old checkout and cached artifacts to support existing build directories.
- OpenClash and the old `luci-app-wg-reality` are no longer included.
  Use custom PassWall2 26.10.20-r5 at d4f79af3b6984da958b15f832b681db4cffec456
  with the SHA-256 pinned official ARM64 Xray 26.10.31 release.
  `scripts/prepare-passwall2.sh` also pins the PassWall dependency feed.
  `scripts/prepare-passwall2-golang.sh` pins the compatible Go tooling;
  geoview 0.2.8 cannot build with the original Go 1.23 feed.
  After the final feed install, `diy-part2.sh` removes feed Xray override
  links. Builds must select `package/xray-core/Makefile` in `tmp/.packageinfo`;
  otherwise feeds can silently replace the pinned binary with their recipe.
  The r4 monitor adds authenticated, read-only telemetry and optional Bandix
  device traffic. Its exit probe uses Xray's loopback SOCKS input only. Bandix
  traffic collection is enabled separately; do not enable DNS logging or disk
  history just to use the dashboard.
  The custom source adds LAN route exceptions and bounded traffic
  history without changing its r5 package version. The recipe disables the
  history service's automatic enable/start; users opt in explicitly after
  installing firmware. Existing history files remain in upgrade backups.
- `diy-part2.sh` repairs the upstream literal `ifup` file at
  `package/network/config/netifd/files/sbin/ifdown` into the intended symlink.
- Preserve `/etc/config/passwall2`, `/etc/passwall2/`, and old
  `/etc/wg-reality/` backups during upgrades. The dedicated UCI default enables
  the new guard before retiring old includes and switches Xray to /usr/bin/xray.
- Both repositories are public under `localhost-copilot`. Actions checks out
  `localhost-copilot/openwrt-passwall2` at the pinned commit without a deploy key.
  `PASSWALL2_SOURCE` identifies the local checkout; local Docker builds mount
  it read-only. Keep local router backups and credentials out of Git.

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

The 2026-11-03 update pins Vantage v1.0.12, the custom PassWall2
commit above, and Xray 26.10.31. Validate both device configurations with
`make defconfig` and check `make package/xray-core/download` against the
new hash. In a privileged disposable OpenWrt container, enable
`TEST_PACKET_LEAKS=1` for the migration test to verify backup/restore and
IPv4/IPv6/DNS blocking across service stop, relay failure, firewall reload
and guard generation/application failure. Never run these scripts on a router.

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

- Ruby YJIT is disabled in both configs. It is optional for the retained Ruby
  interpreter and otherwise pulls in a full Rust host compiler build, which
  caused the previous Actions release build to exceed its six-hour limit.
- Expect a long first build because the target toolchain and LLVM BPF tools
  still compile from source.
- The first successful build used about 41G in the OpenWrt work directory.
- The machine had enough resources during the run: 24 CPUs, 94GiB RAM, and more
  than 500G free disk.
- Keep `.build/openwrt-workdir` if future rebuild speed matters.
- `.build/` and `firmware_collection/` are generated output and are ignored by
  git.
