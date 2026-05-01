# Remove Account

## User Story

As a CodexPill user, I want to remove a saved account from the local catalog, so that accounts I no longer want to use do not clutter the menu or get suggested.

## Product Contract

- Removing an account deletes CodexPill's saved local snapshot for that account.
- If the removed account is currently active locally, CodexPill signs out the local Codex auth and relaunches Codex before deleting the saved snapshot.
- If the removed account is currently active on a connected remote host, CodexPill signs out that remote host before deleting the saved snapshot.
- If any required sign-out fails, CodexPill keeps the saved account and reports the real failure.
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
4. The user confirms `Remove` or `Sign Out & Remove`.
5. CodexPill signs out any active local or connected remote target that is using the account.
6. CodexPill deletes the saved snapshot for that account.
7. CodexPill removes the account from the local catalog.
8. CodexPill recomputes the active saved-account match.

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

If the account is currently active locally or remotely, use:

Title:

```text
<account> is in use
```

Body:

```text
Sign out on <target list> before removing it?
```

Actions:

- `Remove`
- `Sign Out & Remove` when active targets must be signed out first
- `Cancel`

## Acceptance Criteria

### Confirmation Required

Given a saved account exists, when the user chooses `Remove…`, then CodexPill asks for confirmation before deleting the saved snapshot.

### Cancel Does Not Mutate

Given the remove confirmation is visible, when the user chooses `Cancel`, then CodexPill keeps the account, snapshot, active account match, and menu state unchanged.

### Remove Deletes Local Snapshot

Given the user confirms removal, then CodexPill deletes the saved local snapshot for that account and removes the account from the catalog.

### Active Account Removal Signs Out First

Given the removed account is the active local saved account, when removal completes, then the local Codex auth is signed out and Codex is relaunched before the saved snapshot is deleted.

### Remote Active Account Removal Signs Out First

Given the removed account is active on a connected remote host, when removal completes, then the remote host is signed out before the saved snapshot is deleted and the remote card no longer presents the removed account as active.

### Sign-Out Failure Does Not Remove

Given the removed account is active locally or remotely, when a required sign-out fails, then CodexPill keeps the saved snapshot and catalog row and shows the failure.

### Remote Snapshots Are Not Deleted

Given the removed account had previously been installed on a remote host but is not the active remote account, when the saved account is removed locally, then CodexPill does not delete remote files as part of this action.

### Busy State Blocks Removal

Given CodexPill is performing another account operation, then remove actions are disabled until the app returns to idle.

## Validation Targets

- `remove_account_requires_confirmation`
- `remove_account_cancel_does_not_mutate_catalog`
- `remove_account_deletes_local_snapshot_and_catalog_entry`
- `remove_account_active_local_session_signs_out_before_delete`
- `remove_account_active_remote_session_signs_out_before_delete`
- `remove_account_signout_failure_keeps_saved_account`
- `remove_account_does_not_delete_remote_snapshots`
- `remove_account_disabled_while_busy`
