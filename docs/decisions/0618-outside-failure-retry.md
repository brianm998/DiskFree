# 0618: outside-class failures need a bounded automatic retry

- Observation: `retries_by_failure_class` shows outside: manual 1, auto 0. Outside failures (environment, network, disk stalls) are never retried automatically, so the owner had to intervene (interventions_per_landed 0.053).
- The retry policy lives in the MASON pipeline, not in DiskFree, so no app change can move this metric.
- Recommendation for the pipeline: retry outside-class failures automatically once or twice with backoff, and escalate to the owner only after that.
- No code change in this repo.
