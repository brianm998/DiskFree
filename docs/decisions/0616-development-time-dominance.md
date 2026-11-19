# 0616: development time dominating the clock is expected

Task 604 flagged developing at 5.27M of 6.14M ms (86%), with claim-to-land median 231s and p90 574s.

- Queue wait is about 1.5k ms, so the pipeline adds no delay. Agent work is the task itself, so a high development share is expected, not a defect.
- `wait_share` of 0.001 comes from one sample and is not evidence of a problem.
- The p90/median ratio of 2.5x is within normal spread for tasks of differing size. No threshold or code change is justified from one sample.
- Revisit if development share stays high while median claim-to-land grows across several weekly digests.
