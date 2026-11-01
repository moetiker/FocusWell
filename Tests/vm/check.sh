#!/bin/bash
# Runs inside the test VM as admin, copied there by scripts/test-vm run:
#
#   check.sh cask              install the released cask the way the README says
#   check.sh local <zip>       install a local build (make zip)
#
# Prints "ok:" and "FAIL:" lines and exits with the number of failures.
set -uo pipefail

APP=/Applications/FocusWell.app
ID=ch.oetiker.FocusWell
DB="/Library/Application Support/com.apple.TCC/TCC.db"
HERE=$(cd "$(dirname "$0")" && pwd)
failures=0
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*"; failures=$((failures + 1)); }
tcc() { sudo sqlite3 "$DB" "$@"; }

eval "$(/opt/homebrew/bin/brew shellenv)"

# Accessibility for a program, as a user would switch it on in System Settings.
# Writing TCC.db needs SIP off, which setup does for the clean image. Columns and
# the code requirement follow desktest (github.com/Edison-Watch/desktest,
# docs/macos-support.md), which reports that an entry without a code requirement
# may be ignored even with SIP off.
grant() { # <client: bundle id or path> <client_type: 0 bundle id, 1 path> <code path>
    local req
    codesign -d -r- "$3" 2>&1 | sed -n 's/.*designated => //p' | csreq -r- -b /tmp/focuswell.req
    req=$(xxd -p /tmp/focuswell.req | tr -d '\n')
    tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason,
           auth_version, csreq, policy_id, indirect_object_identifier_type,
           indirect_object_identifier, indirect_object_code_identity, flags, last_modified)
         VALUES ('kTCCServiceAccessibility', '$1', $2, 2, 4, 1, X'$req', NULL, 0, 'UNUSED', NULL, 0,
           $(date +%s))"
}

echo "== install ($1)"
case $1 in
cask)
    brew tap moetiker/FocusWell https://github.com/moetiker/FocusWell
    brew trust --cask moetiker/focuswell/focuswell
    out=$(brew install --cask focuswell 2>&1)
    echo "$out"
    if grep -qi warning <<<"$out"; then bad "brew install printed a warning"; else ok "brew install without warnings"; fi
    if spctl -a -t exec -vv "$APP" 2>&1 | grep -q "source=Notarized Developer ID"; then
        ok "Gatekeeper accepts the app as notarized"
    else
        bad "Gatekeeper does not accept the app: $(spctl -a -t exec -vv "$APP" 2>&1 | tr '\n' ' ')"
    fi
    # A user confirms the "downloaded from the Internet" dialog once; nothing can click it here.
    xattr -dr com.apple.quarantine "$APP"
    ;;
local)
    ditto -x -k "$2" /Applications
    ;;
esac
[ -d "$APP" ] && ok "FocusWell.app is in /Applications" || { bad "no $APP"; exit "$failures"; }

echo "== first start"
open "$APP"
for _ in $(seq 20); do pgrep -qx FocusWell && break; sleep 1; done
pgrep -qx FocusWell && ok "FocusWell runs" || { bad "FocusWell does not start"; exit "$failures"; }
sleep 3
row=$(tcc "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='$ID'")
if [ -n "$row" ]; then
    ok "the Accessibility prompt added FocusWell to the list (auth_value $row)"
else
    bad "the Accessibility prompt did not add FocusWell to the list"
fi
# The prompt dialog would sit in the middle of the screen during the focus test
killall universalAccessAuthWarn 2>/dev/null

echo "== focus follows the mouse"
grant "$ID" 0 "$APP"
grant "$HERE/focus-check" 1 "$HERE/focus-check"
grant /usr/libexec/sshd-keygen-wrapper 1 /usr/libexec/sshd-keygen-wrapper
osascript -e "quit app id \"$ID\"" 2>/dev/null || pkill -x FocusWell
sleep 2
open "$APP"
sleep 3

echo text > /tmp/focuswell-a.txt
open -a TextEdit /tmp/focuswell-a.txt
open -a Calculator
sleep 5
if "$HERE/focus-check" com.apple.TextEdit com.apple.calculator; then
    ok "focus follows the mouse without raising"
else
    bad "focus check failed"
fi

if [ "$1" = cask ]; then
    echo "== uninstall"
    brew uninstall --cask focuswell && [ ! -d "$APP" ] && ok "brew uninstall removes the app" \
        || bad "brew uninstall failed"
fi

echo "== $failures failure(s)"
exit "$failures"
