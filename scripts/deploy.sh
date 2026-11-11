#!/bin/bash

# ============================================================================
# Deploy umbrella for real: release build of THIS checkout (Ship runs it in
# the worktree holding the pushed commit) + phone_deploy to the Pixel.
# phone_deploy installs with `install -r` and has no uninstall / pm clear
# path, so app data survives. Rerunning is safe: each run picks a versionCode
# above the installed one.
#
# The app runs on the phone, not from ~/src/umbrella, so there is no checkout
# to pull: building kuhy's checkout would ship whatever is dirty there.
#
# Health check (exit 50 on failure): after the deploy the installed
# versionCode is higher than before and the app process is running.
# Other exits come straight from phone_deploy (30 = phone unreachable, ...).
# ============================================================================

set -euo pipefail

readonly PKG="com.kuhy.umbrella"
readonly SERIAL="${ADB_SERIAL:-23181JEGR08034}"
readonly PHONE_DEPLOY="${PHONE_DEPLOY:-$HOME/.claude/scripts/phone_deploy.sh}"
# Ship's deploy unit passes only PATH/HOME, not the login env from ~/.zshenv.
export ANDROID_HOME="${ANDROID_HOME:-$HOME/sdk/foss-android-sdk}"
# Without a claude ancestor every process is its own lease owner, so
# phone_deploy's lease blocks its own phone_vd launch (exit 35). One stable
# owner also lets a rerun after a failure reuse the lease it left behind.
export PHONE_LEASE_OWNER="${PHONE_LEASE_OWNER:-deploy:$PKG}"
# Shared release signing config; key.properties is gitignored, so a fresh
# worktree (where Ship runs this) has none and would build debug-signed.
readonly SHARED_KEY_PROPS="${SHARED_KEY_PROPS:-$HOME/.android/release/key.properties}"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly APP_DIR
# Kept after the run so the on-device result can be looked at.
readonly SHOT="${DEPLOY_SHOT:-${XDG_CACHE_HOME:-$HOME/.cache}/umbrella-deploy/screen.png}"

installed_version() {
    adb -s "$SERIAL" shell dumpsys package "$PKG" 2>/dev/null \
        | grep -m1 -oE 'versionCode=[0-9]+' | cut -d= -f2 || true
}

fail() {
    echo "deploy: $1" >&2
    exit 50
}

# Link the shared key.properties into the checkout when it has none.
ensure_signing() {
    local props="$APP_DIR/android/key.properties"
    [[ -e "$props" ]] && return 0
    [[ -f "$SHARED_KEY_PROPS" ]] || fail "no $props and no $SHARED_KEY_PROPS to sign with"
    ln -s "$SHARED_KEY_PROPS" "$props"
}

main() {
    local before after
    ensure_signing
    before="$(installed_version)"
    mkdir -p "$(dirname "$SHOT")"

    bash "$PHONE_DEPLOY" "$APP_DIR" --release --shot "$SHOT"

    after="$(installed_version)"
    [[ -n "$after" ]] || fail "$PKG not installed after deploy"
    (( after > ${before:-0} )) || fail "versionCode did not rise ($before -> $after)"
    adb -s "$SERIAL" shell pidof "$PKG" >/dev/null || fail "$PKG not running after launch"
    echo "deploy: ok $PKG versionCode ${before:-none} -> $after (screen: $SHOT)"
}

main "$@"
