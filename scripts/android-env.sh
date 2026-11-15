#!/usr/bin/env bash
# 安卓构建环境探测，供 scripts/android.sh 引入。
# 已设置的 JAVA_HOME / ANDROID_HOME / NDK_HOME 优先，不会覆盖。

if [[ -z "${JAVA_HOME:-}" ]]; then
  for candidate in \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x "$candidate/bin/java" ]]; then
      JAVA_HOME="$candidate"
      break
    fi
  done
fi
if [[ -z "${JAVA_HOME:-}" ]] && [[ -x /usr/libexec/java_home ]]; then
  JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
fi

if [[ -z "${ANDROID_HOME:-}" ]]; then
  for candidate in \
    "$HOME/Library/Android/sdk" \
    /opt/homebrew/share/android-commandlinetools \
    /usr/local/share/android-commandlinetools; do
    if [[ -d "$candidate/platform-tools" ]]; then
      ANDROID_HOME="$candidate"
      break
    fi
  done
fi

if [[ -z "${NDK_HOME:-}" ]] && [[ -n "${ANDROID_HOME:-}" ]] && [[ -d "$ANDROID_HOME/ndk" ]]; then
  newest_ndk="$(ls -1 "$ANDROID_HOME/ndk" | sort -V | tail -1)"
  NDK_HOME="$ANDROID_HOME/ndk/$newest_ndk"
fi

export JAVA_HOME="${JAVA_HOME:-}"
export ANDROID_HOME="${ANDROID_HOME:-}"
export NDK_HOME="${NDK_HOME:-}"
export PATH="$HOME/.cargo/bin${ANDROID_HOME:+:$ANDROID_HOME/platform-tools}:$JAVA_HOME/bin:$PATH"

if [[ -z "$JAVA_HOME" ]] || [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "找不到 JDK 17：brew install openjdk@17，或设置 JAVA_HOME" >&2
  exit 1
fi
if [[ -z "$ANDROID_HOME" ]] || [[ ! -d "$ANDROID_HOME/platform-tools" ]]; then
  echo "找不到 Android SDK：brew install --cask android-commandlinetools，或设置 ANDROID_HOME" >&2
  exit 1
fi
if [[ -z "$NDK_HOME" ]] || [[ ! -d "$NDK_HOME" ]]; then
  echo "找不到 Android NDK：sdkmanager --install 'ndk;28.2.13676358'，或设置 NDK_HOME" >&2
  exit 1
fi
