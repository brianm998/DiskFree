# 1186: pipeline-level findings belong in the mason project

- Observation: analyst tasks #603-#606 were filed into disk_free but concern MASON's switches, timing metrics and retry policy. They produced only stage notes or decision records (0615, 0618); #605 named cargo tests absent from this repo. Finding #18's source, task #582, ran in project mason yet was reported against disk_free.
- The finding router lives in the MASON pipeline, not in DiskFree, so no change in this repo can implement it.
- Recommendation for the pipeline: (1) route a finding whose subject is pipeline code or configuration to the mason project; (2) refuse or re-route a finding that names files or tests absent from the target repo; (3) attribute a finding to the project of its source task; (4) apply the same rule to every pipeline finding in an analyst report.
- No code change in this repo.
