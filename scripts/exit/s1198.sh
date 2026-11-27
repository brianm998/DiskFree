#!/bin/bash
# s1198: the unmeasurable-baseline rule is recorded (decision 1188).
set -euo pipefail
cd "$(dirname "$0")/../.."
grep -q 'unmeasured' docs/decisions/1188-unmeasurable-baselines.md || { echo "s1198: rule missing" >&2; exit 1; }
echo "s1198: ok"
