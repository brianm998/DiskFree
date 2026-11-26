# 1132 Sign test builds ad hoc

## Context

The project signs automatically for team G3L75S65V9. MASON can place the swift suite on a node, such as marmot, that has no "Mac Development" certificate and private key for that team. The build then fails before any test runs.

## Decision

The `swift` suite in `.mason/mason.toml` overrides signing on the command line: `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`. The project file and `release.sh` are unchanged.

## Alternatives rejected

- Keep the suite on one Mac (`remote = false`): every disk_free test run would wait for that machine.
- `CODE_SIGNING_ALLOWED=NO`: the entitlements are not applied, so the test host would run outside the sandbox.
- Install a development certificate on each node: puts a private key on more machines and has to be repeated for every new node. This is the owner's call.

## Consequences

- The suite needs no certificate or Apple account on any node, including this Mac.
- Tests no longer exercise team signing. Behaviour that depends on a team identifier (such as keychain access groups or app groups) would need a signed run elsewhere.
- The test host is still signed with `DiskFree/DiskFree.entitlements`, so it stays sandboxed.
