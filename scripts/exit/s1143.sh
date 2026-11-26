#!/bin/bash
# s1143: the swift suite signs ad hoc and keeps the sandbox (decision 1132).
set -euo pipefail
cd "$(dirname "$0")/../.."

command=$(awk '/^\[/ { in_suite = ($0 == "[suite.swift]") } in_suite && /^command *=/' .mason/mason.toml)

fail() { echo "s1143: $1" >&2; exit 1; }

[ -n "$command" ] || fail "no command in [suite.swift]"
for want in "CODE_SIGN_STYLE=Manual " "CODE_SIGN_IDENTITY=- " "DEVELOPMENT_TEAM= " "-skip-testing:DiskFreeUITests "; do
    case "$command" in
        *"$want"*) ;;
        *) fail "suite command lacks '$want'" ;;
    esac
done
case "$command" in
    *CODE_SIGNING_ALLOWED=NO*) fail "signing is disabled, so the sandbox would not apply" ;;
esac
grep -q 'com.apple.security.app-sandbox' DiskFree/DiskFree/DiskFree.entitlements || fail "sandbox entitlement is missing"
echo "s1143: ok"
