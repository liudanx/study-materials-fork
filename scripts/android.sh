#!/usr/bin/env bash
# 安卓构建入口：统一注入 JDK / SDK / NDK 环境。
#
#   scripts/android.sh init            生成 src-tauri/gen/android
#   scripts/android.sh dev             真机开发调试
#   scripts/android.sh debug [args]    构建 debug APK（默认 aarch64）
#   scripts/android.sh release [args]  构建并签名 release APK
#
# release 签名从 $ANDROID_SIGNING_ENV（默认 ~/.config/hghub/android-signing.env）读取：
#   KEYSTORE_PATH / KEY_ALIAS / KEYSTORE_PASSWORD / KEY_PASSWORD
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=android-env.sh
source "$ROOT/scripts/android-env.sh"

MODE="${1:-debug}"
shift || true

TARGET="${ANDROID_TARGET:-aarch64}"
has_target() { [[ " $* " == *" --target "* ]] || [[ " $* " == *" -t "* ]]; }
default_target() { if has_target "$*"; then echo ""; else echo "--target $TARGET"; fi; }

case "$MODE" in
  init)
    pnpm tauri android init --ci
    ;;
  dev)
    pnpm tauri android dev "$@"
    ;;
  debug)
    node scripts/sync-android-icons.mjs
    # shellcheck disable=SC2046
    pnpm tauri android build --apk --debug --ci $(default_target "$@") "$@"
    APK="$(find src-tauri/gen/android/app/build/outputs/apk -path '*/debug/*' -name '*.apk' | head -1)"
    [[ -n "$APK" ]] || { echo "未找到 debug APK" >&2; exit 1; }
    mkdir -p artifacts
    OUT="artifacts/HGhub_$(node -p "require('./package.json').version")_debug_${TARGET}.apk"
    cp "$APK" "$OUT"
    echo "debug APK -> $OUT"
    ;;
  release)
    SIGNING_ENV="${ANDROID_SIGNING_ENV:-$HOME/.config/hghub/android-signing.env}"
    if [[ -f "$SIGNING_ENV" ]]; then
      # shellcheck source=/dev/null
      source "$SIGNING_ENV"
    fi
    for key in KEYSTORE_PATH KEY_ALIAS KEYSTORE_PASSWORD KEY_PASSWORD; do
      if [[ -z "${!key:-}" ]]; then
        echo "缺少签名配置 $key（见 $SIGNING_ENV）" >&2
        exit 1
      fi
    done
    export KEYSTORE_PATH KEY_ALIAS KEYSTORE_PASSWORD KEY_PASSWORD
    node scripts/sync-android-icons.mjs
    # shellcheck disable=SC2046
    pnpm tauri android build --apk --ci $(default_target "$@") "$@"
    APK="$(find src-tauri/gen/android/app/build/outputs/apk -path '*/release/*' -name '*.apk' | head -1)"
    [[ -n "$APK" ]] || { echo "未找到 release APK" >&2; exit 1; }
    BUILD_TOOLS="$(ls -1 "$ANDROID_HOME/build-tools" | sort -V | tail -1)"
    APKSIGNER="$ANDROID_HOME/build-tools/$BUILD_TOOLS/apksigner"
    mkdir -p artifacts
    OUT="artifacts/HGhub_$(node -p "require('./package.json').version")_${TARGET}.apk"
    "$APKSIGNER" sign \
      --ks "$KEYSTORE_PATH" --ks-key-alias "$KEY_ALIAS" \
      --ks-pass "env:KEYSTORE_PASSWORD" --key-pass "env:KEY_PASSWORD" \
      --v4-signing-enabled false \
      --out "$OUT" "$APK"
    "$APKSIGNER" verify --print-certs "$OUT" | head -3
    echo "release APK -> $OUT"
    ;;
  *)
    echo "用法: scripts/android.sh <init|dev|debug|release> [tauri 参数]" >&2
    exit 1
    ;;
esac
