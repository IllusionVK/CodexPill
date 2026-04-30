# Remove Account

## User Story

As a CodexPill user, I want to remove a saved account from the local catalog, so that accounts I no longer want to use do not clutter the menu or get suggested.

## Product Contract

- Removing an account deletes CodexPill's saved local snapshot for that account.
- Removing an account does not log out Codex or mutate the live local Codex auth state.
- If the removed account is currently active locally, CodexPill should no longer consider the live session matched to a saved account after removal.
- Removing an account does not delete remote snapshots already installed on remote hosts.
- The action is destructive for the local saved snapshot and must require confirmation.
- CodexPill must not log or expose raw auth payloads during removal.

## Entry Point

Saved account submenu:

```text
Remove…
```

## Happy Path

1. The user opens a saved account submenu.
2. The user chooses `Remove…`.
3. CodexPill shows a destructive confirmation.
4. The user confirms `Remove`.
5. CodexPill deletes the saved snapshot for that account.
6. CodexPill removes the account from the local catalog.
7. CodexPill recomputes the active saved-account match.

## Confirmation Copy

Title:

```text
Remove saved account?
```

Body:

```text
This will remove the saved snapshot for <account>.

This action cannot be undone.
```

If the account is currently active locally, append:

```text
The live Codex session will remain logged in, but it will no longer match a saved account.
```

Actions:

- `Remove`
- `Cancel`

## Acceptance Criteria

### Confirmation Required

Given a saved account exists, when the user chooses `Remove…`, then CodexPill asks for confirmation before deleting the saved snapshot.

### Cancel Does Not Mutate

Given the remove confirmation is visible, when the user chooses `Cancel`, then CodexPill keeps the account, snapshot, active account match, and menu state unchanged.

### Remove Deletes Local Snapshot

Given the user confirms removal, then CodexPill deletes the saved local snapshot for that account and removes the account from the catalog.

### Active Account Removal

Given the removed account is the active local saved account, when removal completes, then the live Codex session remains logged in but CodexPill no longer reports it as a saved current account.

### Remote Snapshots Are Not Deleted

Given the removed account had previously been installed on a remote host, when the saved account is removed locally, then CodexPill does not delete remote files as part of this action.

### Busy State Blocks Removal

Given CodexPill is performing another account operation, then remove actions are disabled until the app returns to idle.

## Validation Targets

- `remove_account_requires_confirmation`
- `remove_account_cancel_does_not_mutate_catalog`
- `remove_account_deletes_local_snapshot_and_catalog_entry`
- `remove_account_active_session_remains_logged_in_but_unmatched`
- `remove_account_does_not_delete_remote_snapshots`
- `remove_account_disabled_while_busy`
