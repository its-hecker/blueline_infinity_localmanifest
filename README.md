# Project Infinity-X 17 for Pixel 3 (blueline)

Unofficial Android 17 device bring-up for the Google Pixel 3, maintained by **Hecker**. This is an **experimental source port**: a successful compilation or an Android 17 LineageOS image does not establish that the device boots.

## Repositories

- [Device tree](https://github.com/its-hecker/blueline_infinity_devicetree) — snapshot of the `lineage-24.0` Pixel 3/crosshatch tree, with an `infinity_blueline` product.
- [Kernel](https://github.com/its-hecker/blueline_infinity_kernel) — Pixel 3 Linux 4.9.337 backport tree, `lineage-24.0` source.
- [Vendor](https://github.com/its-hecker/blueline_infinity_vendor) — Pixel 3 blobs from the `lineage-24.0` branch. Git LFS is required.
- This manifest — pinned Android 17 compatibility dependencies, build helper and vendor fixups.

The three source repositories have now been imported to their `main` branches. Verify that the device product, kernel Makefile and vendor makefile exist before syncing; the import workflows are one-time bootstraps.

## Clean ServerHive checkout

```bash
mkdir -p ~/infinityx-blueline
cd ~/infinityx-blueline
repo init --depth=1 --no-repo-verify --git-lfs \
  -u https://github.com/ProjectInfinity-X/manifest -b 17 \
  -g default,-mips,-darwin,-notdefault
git clone -b main https://github.com/its-hecker/blueline_infinity_localmanifest.git .repo/local_manifests
repo sync -c --fail-fast --no-clone-bundle --no-tags
env -u HECKER_BUILD_JOBS USE_RBE=true WITH_GAPPS=false PIXEL3_DEV_USB_ADB=true \
  bash .repo/local_manifests/build.sh
```

The first build is **vanilla** (`WITH_GAPPS=false`) to keep Pixel 3's limited physical partition budget. The build script uses `lunch infinity_blueline cp2a userdebug`, validates generated SELinux kernel settings, prepares vendor blobs, and calls `m bacon`. Do not flash before inspecting the build log, partition sizes and device-specific boot diagnostics.

## Known bring-up limitations

- The earlier LineageOS 24.0 Pixel 3 build reached the Google logo but did not boot successfully. The root cause is not confirmed.
- Infinity-X's customized `system/core`, `system/vold` and Connectivity sources have **not** yet been validated with legacy 4.9 fscrypt.
- The manifest reuses pinned legacy SDM845 display, GPS, audio, and GCC binutils; reassess pins during subsequent builds.
- The vendor helper modifies generated vendor blobs in the synced checkout; it does not mutate the upstream GitHub repositories.
- `PIXEL3_DEV_USB_ADB=true` is development-only. Disable it for a public release.

## Checks

```bash
bash .repo/local_manifests/build.sh --check
bash .repo/local_manifests/build.sh --prepare-only
```

**Credits:** Project Infinity-X, LineageOS, Google Pixel maintainers and xbill9 for legacy Android 17 compatibility work.
