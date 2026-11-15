#!/usr/bin/env bash
# Experimental Project Infinity-X 17 / Android 17 Pixel 3 (blueline) build.
set -eo pipefail
ROOT=$(pwd -P)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=${1:-build}
case "$MODE" in
  build|--check|--prepare-only) ;;
  *) echo "Usage: bash .repo/local_manifests/build.sh [--check|--prepare-only]" >&2; exit 2 ;;
esac
if [[ ! -f build/envsetup.sh ]]; then
  echo "Run from the root of your Infinity-X 17 checkout." >&2
  exit 1
fi
required=(
  device/google/crosshatch/infinity_blueline.mk
  device/google/crosshatch/blueline/extract-files.py
  device/google/crosshatch/development/adb.mk
  vendor/google/blueline/blueline-vendor.mk
  vendor/infinity/config/common_full_phone.mk
  kernel/google/msm-4.9/Makefile
  hardware/qcom/audio/Android.bp
  hardware/qcom/sdm845/display/Android.bp
  hardware/qcom/sdm845/gps/Android.bp
  tools/extract-utils/extract_utils/main.py
  prebuilts/extract-tools/linux-x86/bin/patchelf-0_18
  prebuilts/clang/kernel/linux-x86/clang-r416183b/bin/clang
  prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-ld.gold
  prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-ld
)
missing=0
for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then echo "Missing source/tool: $file" >&2; missing=1; fi
done
if (( missing )); then echo "Check source imports and repo sync before building." >&2; exit 1; fi
if [[ "$MODE" == "--check" ]]; then
  echo "Infinity-X Pixel 3 build inputs found. Compilation/boot NOT verified."
  exit 0
fi

python3 "$SCRIPT_DIR/scripts/prepare-vendor.py" "$ROOT"
if [[ "$MODE" == "--prepare-only" ]]; then exit 0; fi

# Let ServerHive choose the build job count; preserve its existing RBE setup.
export USE_RBE=${USE_RBE:-true}
export WITH_GAPPS=${WITH_GAPPS:-false}
export PIXEL3_DEV_USB_ADB=${PIXEL3_DEV_USB_ADB:-true}
mkdir -p out/build-logs
LOG="$ROOT/out/build-logs/infinity-blueline-$(date -u +%Y%m%d-%H%M%S).log"
echo "Build log: $LOG"
(
  source build/envsetup.sh
  lunch infinity_blueline cp2a userdebug
  m kernelconfig
  python3 "$SCRIPT_DIR/scripts/check-kernel-config.py" "$ANDROID_PRODUCT_OUT/obj/KERNEL_OBJ/.config"
  m bacon
  # A bootable graphics stack needs HWC2, not just software UI rendering.
  prop="$ANDROID_PRODUCT_OUT/vendor/build.prop"
  hwc="$ANDROID_PRODUCT_OUT/vendor/lib64/hw/hwcomposer.qcom.so"
  if [[ ! -f "$prop" ]] || ! grep -qx 'ro.hardware.hwcomposer=qcom' "$prop"; then
    echo "Missing Qualcomm HWC vendor property: $prop" >&2; exit 1
  fi
  if [[ ! -f "$hwc" ]]; then echo "Missing Qualcomm hardware composer: $hwc" >&2; exit 1; fi
  echo "Pixel 3 Qualcomm hardware composer validation: PASS"
) 2>&1 | tee "$LOG"
