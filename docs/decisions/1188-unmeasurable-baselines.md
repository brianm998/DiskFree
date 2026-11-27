# 1188: fix verdicts need a baseline that can show a change

Task 1181. The weekly analyst issued `didnt_help` on findings whose baseline could not move:

- Finding 26: `repeat_failure_rate` 0.000 before and 0.000 after. A rate already at its floor cannot improve.
- Finding 25: `wait_share` baseline of 1 sample (25 of 27965 ms) against 45 after. The fix was a decision record that changed no code (see 0616).

Rule for the verdict step: report `unmeasured`, not `didnt_help`, when
1. the baseline is already at the metric's best value (0 for rates and shares where lower is better), or
2. the baseline has too few samples to compare (fewer than a handful; one sample is never enough).

`didnt_help` is reserved for a baseline that could have improved and did not. A fix that changes no code (a decision record) should also read `unmeasured`.

This repo holds no verdict code; the verdict logic lives in MASON's introspection analyst and must apply this rule there. Nothing in DiskFree changes.
