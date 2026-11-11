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
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly APP_DIR
SHOT_DIR=""

installed_version() {
    adb -s "$SERIAL" shell dumpsys package "$PKG" 2>/dev/null \
        | grep -m1 -oE 'versionCode=[0-9]+' | cut -d= -f2 || true
}

fail() {
    echo "deploy: $1" >&2
    exit 50
}

main() {
    local before after
    before="$(installed_version)"
    SHOT_DIR="$(mktemp -d)"
    trap '[[ -n "$SHOT_DIR" ]] && rm -rf -- "$SHOT_DIR"' EXIT

    bash "$PHONE_DEPLOY" "$APP_DIR" --release --shot "$SHOT_DIR/screen.png"

    after="$(installed_version)"
    [[ -n "$after" ]] || fail "$PKG not installed after deploy"
    (( after > ${before:-0} )) || fail "versionCode did not rise ($before -> $after)"
    adb -s "$SERIAL" shell pidof "$PKG" >/dev/null || fail "$PKG not running after launch"
    echo "deploy: ok $PKG versionCode ${before:-none} -> $after"
}

main "$@"
