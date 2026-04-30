# Switch Account

## User Story

As a CodexPill user, I want to switch a saved Codex account onto This Mac or a configured remote host, so that I can continue working with an account that has available capacity.

## Product Contract

- Switching is always explicit. Adding, renaming, or removing an account must not implicitly switch the active account.
- `Switch on This Mac` activates the selected saved snapshot as the local Codex auth state.
- Remote switch actions target a specific configured host.
- If a saved account is not installed on a remote host, the remote action installs it before switching.
- Local switching relaunches Codex so the app-server reads the newly active account.
- Remote switching refreshes the remote Codex app-server after the remote auth change and verifies the expected account.
- CodexPill must not log or expose raw auth payloads during switch operations.

## Entry Points

- Saved account submenu: `Switch on This Mac`.
- Saved account submenu for each configured host:
  - `Switch on <host>` when the account is already installed on that host.
  - `Install on <host> and switch` when the account snapshot is missing on that host.
- Add Account success alert: `Use on This Mac`, which routes through the existing local switch path without showing a second switch confirmation.
- Account availability notifications: action buttons may route to the same local or remote switch paths.

## Local Happy Path

1. The user opens a saved account submenu.
2. The user chooses `Switch on This Mac`.
3. CodexPill asks for confirmation.
4. CodexPill replaces the local Codex auth state with the saved snapshot.
5. CodexPill persists the catalog state.
6. CodexPill relaunches Codex.
7. CodexPill refreshes account data after the switch.

## Remote Happy Path

1. The user opens a saved account submenu.
2. The user chooses a remote host switch action.
3. CodexPill checks whether the account snapshot is already installed on that host.
4. If missing, CodexPill installs the snapshot on the host.
5. CodexPill switches the host to that account.
6. CodexPill refreshes the remote Codex app-server.
7. CodexPill verifies that the remote host reports the expected account.
8. CodexPill updates the remote host account state shown in the menu.

## Confirmation Copy

Local switch title:

```text
Switch account?
```

Local switch action:

```text
Switch
```

If Codex CLI sessions are running, the confirmation warns that open Codex CLI terminals must be restarted to use the new account.

## Acceptance Criteria

### Explicit Local Switch

Given a saved account exists, when the user chooses `Switch on This Mac`, then CodexPill asks for confirmation before activating the selected snapshot.

### Local Switch Relaunches Codex

Given the user confirms a local switch, when CodexPill activates the selected snapshot, then CodexPill relaunches Codex and refreshes account data after the switch.

### Add Account Uses Existing Switch Path

Given Add Account succeeds, when the user chooses `Use on This Mac`, then CodexPill switches through the existing local switch path and does not show a second switch confirmation.

### Remote Install And Switch

Given a saved account is not installed on a configured host, when the user chooses `Install on <host> and switch`, then CodexPill installs the account snapshot before switching the remote host.

### Remote Direct Switch

Given a saved account is already installed on a configured host, when the user chooses `Switch on <host>`, then CodexPill switches the remote host without reinstalling the snapshot.

### Remote Verification

Given a remote switch completes, when CodexPill refreshes the remote Codex app-server, then it verifies that the reported remote account matches the selected saved account.

### Remote Verification Failure

Given a remote switch command completes but verification reports a different or ambiguous account, then CodexPill surfaces the verification failure instead of silently marking the remote switch as successful.

## Validation Targets

- `switch_account_local_confirms_before_activation`
- `switch_account_local_activates_snapshot_and_relaunches_codex`
- `switch_account_add_account_success_uses_existing_switch_path`
- `switch_account_remote_installs_missing_snapshot_before_switch`
- `switch_account_remote_switches_directly_when_snapshot_exists`
- `switch_account_remote_verifies_expected_account`
- `switch_account_remote_surfaces_verification_failure`
