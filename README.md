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

The first build is **vanilla** (`WITH_GAPPS=false`) to isolate Android 17 boot issues and keep within the Pixel 3's limited retrofit-partition budget. Infinity-X supports GApps, but these should be enabled only after a first successful boot. To compile its built-in GApps variant, rerun with `WITH_GAPPS=true` (the helper verifies GMS source paths). GApps can exceed the Pixel 3's fixed system/product partitions; do not bypass image-size or super-partition errors. The build script uses `lunch infinity_blueline cp2a userdebug`, validates generated SELinux kernel settings, prepares vendor blobs, and calls `m bacon`. Do not flash before inspecting the build log, partition sizes and device-specific boot diagnostics.

## USB ADB and root debugging

The `infinity_blueline` **userdebug** product defaults to `PIXEL3_DEV_USB_ADB=true` for this diagnostic port. The build helper also exports this flag. Debug mode uses:

- `WITH_ADB_INSECURE := true`, so Infinity-X emits `ro.adb.secure=0`
- `PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG := false` to preserve `ro.debuggable=1`
- `persist.sys.usb.config=adb` to request USB debugging even before settings/UI finish booting
- A guarded Pixel 3 init hook at `post-fs`, before the normal `early-boot` stage, that brings up a USB configfs ADB gadget and sets `service.adb.root=1` **before** starting adbd
- Guarded `early-boot` and `boot` actions that reassert development ADB during framework bootloops

On the connected development phone, use `adb devices -l` and `adb shell id` (expect `uid=0(root)` once the debug hook has run). If the daemon is not already root but is alive, use `adb root`, then `adb shell id`; for early logs, try `adb logcat -b all -v threadtime` and `adb shell dmesg`.

**Limitations:** ADB at the Google logo is an intended result, **not guaranteed**. The post-fs hook cannot run during a kernel crash, first-stage init crash, failed partition mount, or before USB configfs and adbd can be initialized. A failed USB enumeration does not establish the precise boot failure. These settings allow root USB access without host authorization: use only on a physical development handset, do not distribute a public image with this mode active.

For a secure build, set `PIXEL3_DEV_USB_ADB=false` and use a secure release product configuration. Confirm `ro.adb.secure` and `ro.debuggable` in the actual built images before distributing.

## Boot-critical checks applied

- **Citadel/Keymaster:** install Pixel 3 `ueventd.hardware.rc` to `/vendor/etc/ueventd.rc`, the path parsed by Android 17 ueventd. This supplies `/dev/citadel0`, `/dev/qseecom`, and secure-element device-node ownership.
- **Linux 4.9 fscrypt:** use the pinned Android 17 `xbill9/android_system_vold` compatibility fork for its legacy session-keyring fallback. The upstream Infinity-X `system_vold` project is removed by manifest name to avoid duplicate checkouts.
- **Display:** restore the early legacy-gralloc mapper setting and keep the Qualcomm HWC module packaged. The later forced `ro.hardware.hwcomposer=qcom` selector was rolled back pending boot-log analysis.
- **BPF/network:** restore the earlier init sequence; the post-first-boot `netd` property-trigger experiment was removed. Inspect BPF and `netd` startup from the new logs.
- **LiveDisplay:** disable the crashing legacy SDM LiveDisplay service during initial boot; this does not remove the Qualcomm hardware composer.
- **Kernel:** check generated `b1c1_defconfig` for SELinux, networking hooks and requisite vendor modules; Android 17 on Pixel 3 still requires hardware tests.
- **ADB:** keep early USB/root debugging restricted to developer images. ADB at the Google logo depends on reaching second-stage init, and is not proof of a healthy boot.
- **Partition handling:** retain Pixel 3's physical and retrofit group partition sizes. Do not enlarge them for GApps without matching physical hardware.

## GApps build after a vanilla boot

```bash
cd ~/infinityx-blueline
git -C .repo/local_manifests pull --ff-only origin main
repo sync -c --fail-fast --no-clone-bundle --no-tags
env -u HECKER_BUILD_JOBS USE_RBE=true WITH_GAPPS=true PIXEL3_DEV_USB_ADB=true \
  bash .repo/local_manifests/build.sh
```

Only test the resulting GApps ZIP after it passes build image-size validation. Do **not** flash a separate GApps ZIP over the Infinity-X GApps build.

## Early boot test

On a PC with Android platform tools, test `adb devices`, `adb shell id`,
`adb shell getprop init.svc.vendor.citadeld`, `adb shell getprop sys.boot_completed`,
`adb logcat -b all -v threadtime`, and `adb shell dmesg`. If ADB never enumerates,
first-stage failures, broken USB gadget setup or kernel issues remain possible.
Testing is required on actual Pixel 3 hardware, especially if different SKU variants behave differently.

## Known bring-up limitations

- A LineageOS 24.0 Pixel 3 `eng` build dated November 14 booted after formatting data, but subsequent variants regressed. Infinity-X boot remains unverified; its hardware tree has now been aligned with that earlier baseline.
- Infinity-X's customized `system/core`, `system/vold` and Connectivity sources have **not** yet been validated with legacy 4.9 fscrypt.
- The manifest reuses pinned legacy SDM845 display, GPS, audio, and GCC binutils, plus a Linux-4.9-compatible vold fork; reassess pins during subsequent builds.
- The vendor helper modifies generated vendor blobs in the synced checkout; it does not mutate the upstream GitHub repositories.
- `PIXEL3_DEV_USB_ADB=true` is development-only. Disable it for a public release.

## Checks

```bash
bash .repo/local_manifests/build.sh --check
bash .repo/local_manifests/build.sh --prepare-only
```

**Credits:** Project Infinity-X, LineageOS, Google Pixel maintainers and xbill9 for legacy Android 17 compatibility work.
