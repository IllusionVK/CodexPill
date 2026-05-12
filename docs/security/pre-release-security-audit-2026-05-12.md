# Pre-release Security Audit - 2026-05-12

## Scope

This audit covers the public beta release gate for CodexPill's sensitive
surfaces. It is source-inspection based, with targeted non-mutating checks. No
real local Codex auth, saved snapshots, or remote host state was mutated.

Severity meanings:

- **Release blocker:** must be fixed before the public beta release proceeds.
- **Beta acceptable:** acceptable for the first beta when documented and not
  exposed through public support workflows.
- **Post-beta hardening:** useful security/privacy work, but not required for
  first beta.
- **No finding:** inspected with no concrete issue found.

## Executive Summary

CodexPill is close to beta-ready from a security posture perspective, but one
release-blocking gap remains: secret-bearing local and remote auth snapshot
storage does not explicitly enforce owner-only file and directory permissions.
The beta can honestly document local cleartext snapshot storage, but it should
not rely on default umask behavior for files that contain credential material.

Release blocker follow-up:

- `RGR-299` - Harden CodexPill auth snapshot file permissions before beta.

## Findings

| Area | Severity | Result |
| --- | --- | --- |
| Local auth snapshot and catalog permissions | Release blocker | `AccountRepository` creates app-support/snapshot directories and writes `accounts.json` and snapshot files without explicit private permissions. `CodexAuthSnapshotService` writes active auth restores with default file behavior. |
| Remote snapshot and remote auth permissions | Release blocker | `SSHRemoteHostClient` creates `.codexpill/snapshots` and `.codex` with plain `mkdir -p`, installs snapshots via `scp`, and copies snapshots into `.codex/auth.json` without a permission repair step. |
| Add Account live-auth preservation | No finding | Isolated add-account captures auth in a temporary `CODEX_HOME`, verifies the live auth fingerprint is unchanged before saving, and cleans up the isolated session on completion/cancel. |
| Local Switch Account mutation path | Beta acceptable | Switching is intentionally mutating and goes through the injected auth activator and Codex relaunch client. There is no rollback if Codex relaunch fails after `auth.json` is written; acceptable for beta because the selected snapshot remains the intended active state. |
| Remove Account deletion behavior | No finding | Removal deletes the saved snapshot and saves the filtered catalog. When asked to remove an active local account, the use case signs out first before deleting the snapshot. |
| Remote command construction and quoting | Beta acceptable | SSH commands are passed as `Process` arguments, not through a local shell. Remote file paths derived from snapshot names are shell-quoted. The remote destination is passed as one OpenSSH operand and scoped by feature docs to working SSH aliases or `user@host` destinations. |
| Remote auth reads | Beta acceptable | Remote `.codex/auth.json` is read to derive metadata/fingerprints and is not printed by product code. Errors can surface remote stderr strings to UI/debug paths; no token echo was found, but these messages should remain private. |
| Remote process control | Post-beta hardening | Codex app-server refresh uses `pgrep -f` and `kill -9` for a fixed app-server command pattern, then starts a server with logs redirected to `/tmp/codex-app-server.log`. This is operationally acceptable for beta, but a per-user/private log path would be cleaner. |
| OSLog privacy | Beta acceptable | Some OSLog messages mark local paths and user-chosen account names as public. These are not raw auth payloads or tokens, but they are private support data and should be made private/redacted after the beta blocker is cleared. |
| Alerts and notifications | Beta acceptable | Alerts and notifications include account names and sometimes host labels because they are user-facing product copy. No raw auth payload, token, or API key emission was found. |
| Validation artifacts and screenshots | Beta acceptable | Validation is disabled unless validation environment variables are set. The release screenshot workflow now uses a synthetic fixture under `build/`; live validation snapshots can still include account names, emails, host labels, and screenshots, so non-demo validation artifacts must stay out of public support attachments unless redacted. |
| Diagnostic script | Beta acceptable | `scripts/inspect_codex_identity.sh` prints a decoded identity summary including email and account identifiers, but not raw token values. It is not referenced by README or user-facing docs. Do not use it as a public support artifact without redaction. |
| Distribution posture | No finding | `make package-release` requires Developer ID Application signing, hardened runtime, notarization, stapling, Gatekeeper assessment, and a clean tree by default. Unsigned builds require an explicit local-validation override and are named `UNSIGNED-LOCAL`. |
| Entitlements and sandbox decision | Beta acceptable | The Tuist project disables injected base entitlements and does not enable App Sandbox. This is honest with the current local-file/process/SSH behavior and should remain documented as a non-Mac-App-Store beta posture. |
| Release docs honesty | No finding | README says signed beta downloads are not available yet, build-from-source is the current path, Homebrew is unavailable, snapshots contain auth material, and remote copies go only to configured hosts. `SECURITY.md` warns against sharing secrets in public reports and includes a maintainer checkpoint for private vulnerability reporting before public beta. |

## Surface Notes

### Storage

Inspected:

- `Sources/Platform/Persistence/AppPaths.swift`
- `Sources/Platform/Persistence/AccountRepository.swift`
- `Sources/Platform/Codex/CodexAuthSnapshotService.swift`
- `Tests/Platform/Persistence/AppPathsTests.swift`
- `Tests/Platform/Codex/CodexAuthSnapshotServiceTests.swift`

CodexPill stores secret-bearing snapshots under app support and writes the
active Codex auth file during switching/restoration. Storage is local-first and
cleartext, matching product docs, but permissions are implicit. This is the
only release-blocking finding.

### Account Workflows

Inspected:

- `Sources/Features/Accounts/Workflows/AddAccountWorkflow.swift`
- `Sources/Features/Accounts/Workflows/SwitchAccountWorkflow.swift`
- `Sources/Features/Accounts/UseCases/DeleteSavedAccountUseCase.swift`
- `Sources/Platform/Codex/SystemIsolatedCodexLoginClient.swift`
- Account workflow tests under `Tests/Accounts`

The add-account path avoids mutating the current live account by using an
isolated `CODEX_HOME`, checking the live fingerprint before save, and cleaning
up the isolated session. Switch and remove paths are intentional mutation
paths with injected process-control boundaries.

### Remote Hosts

Inspected:

- `Sources/Platform/Codex/SSHRemoteHostClient.swift`
- `Sources/Features/Hosts/Workflows/SwitchAccountOnHostWorkflow.swift`
- `Sources/Features/Hosts/Application/RemoteHostRuntime.swift`
- Remote host tests under `Tests/Hosts` and `Tests/Platform/Hosts`
- `docs/features/remote-hosts.md`

The remote implementation does not use a local shell for SSH/SCP invocation.
Remote snapshot paths are internally generated and quoted before use in remote
shell commands. The major gap is permissions on remote snapshot/auth storage.

### Logs, Diagnostics, Alerts, Notifications

Inspected:

- OSLog usage found by source grep.
- `Sources/Features/MenuBar/Validation/MenuBarValidationObserver.swift`
- `Sources/Features/MenuBar/Validation/MenuBarLiveValidation.swift`
- `Sources/Features/MenuBar/Runtime/AccountAvailabilityNotificationRuntime.swift`
- `scripts/inspect_codex_identity.sh`
- `docs/VALIDATION.md`
- `docs/PRIVACY.md`
- `docs/features/release/02-screenshot-demo-data.md`

No raw auth snapshots or token values were found in normal product logging or
notification paths. Validation and diagnostic artifacts can contain private
metadata and should be treated as private artifacts by default.

### Distribution

Inspected:

- `Project.swift`
- `scripts/package_release.sh`
- `docs/features/release/01-signed-github-zip.md`
- `docs/DEVELOPMENT.md`
- `README.md`
- `SECURITY.md`

The release packaging script refuses unsigned public artifacts by default and
verifies Developer ID signing, hardened runtime, notarization, stapling, and
Gatekeeper assessment. The current app is intentionally unsandboxed for beta;
that matches the file/process/SSH behavior and should not be represented as a
sandboxed app.

## Deferred

- Full malicious same-user local process protection.
- Keychain/encryption migration for saved snapshots.
- Mac App Store sandbox design.
- Reusable Apple security-audit skill in `agent-standards`.
- Live mutation checks against real Codex auth or remote hosts.
- Public support diagnostics export design.

## Verification Performed

- Source inspection of storage, account workflow, remote-host, logging,
  notification, diagnostic, validation, and packaging paths.
- Repo safety grep for token/auth/secret/log/diagnostic patterns without
  printing private local auth content.
- Linear release-blocker follow-up created: `RGR-299`.

## Release Gate

The public beta should not proceed until `RGR-299` is fixed and reviewed. After
that, the remaining findings are acceptable for the first beta if release
notes/docs continue to be honest that CodexPill stores local auth snapshots as
local credential material and that diagnostics/support artifacts may contain
private account metadata unless redacted.
