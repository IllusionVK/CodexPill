# Seal V1 Boundary Validation

This document records CodexPill's internal proof emitter for the Seal V1 adoption boundary.

The current V1 boundary is deliberately split:

- CodexPill owns a proof-producing entrypoint for a real product rule.
- Seal owns verification of the emitted proof through `seal-verifier`.

This slice validates `accounts.switch_account.menu_action_changes_active_account` without committing to the future `seal-run` product shape.

## Account Switch Proof Emitter

The internal emitter is `CodexPillProofEmitter`. It is intentionally narrow and is not a polished user CLI.

Run it through the repo-local Makefile:

```bash
OUTPUT_DIR=build/validation-proof/account-switch make emit-account-switch-proof
```

Then verify the proof with Seal:

```bash
swift run --package-path ../Seal seal-verifier --verbose build/validation-proof/account-switch
```

The emitter uses `.integration` execution mode, deterministic fixture accounts, and a caller-provided proof output directory. It does not use Accessibility, browser auth, SSH, app-server reads, live UI automation, or real user Codex auth.

The emitter refuses to write under default Codex production data directories:

- `~/.codex`
- `~/Library/Application Support/Codex`
- `~/Library/Application Support/CodexPill`

## Deferred Runner Shape

The Seal-owned one-command runner remains deferred to a future prototype phase.

The likely future shape is still:

```text
seal-run <scenario> --output <artifact-root>
```

That runner/orchestrator would own fixture setup, invoke CodexPill scenario adapters, wait for proof emission, run verification, and return one verdict. This slice does not implement that runner.

## Runner/Orchestrator Friction

Input for the future prototype phase:

- CodexPill still needs a repo-local wrapper because Seal V1 verifies a completed proof directory but does not know how to build or invoke a client-owned scenario adapter.
- The proof emitter must duplicate the account-switch Seal declaration shape because the current live validation declaration is embedded in menubar validation code and is restricted to `.liveUI`.
- Artifact layout is clear once the proof directory exists, but the caller still has to run the emitter and `seal-verifier` as two separate commands.
