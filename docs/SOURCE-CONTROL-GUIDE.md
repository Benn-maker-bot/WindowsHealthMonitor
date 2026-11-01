# Git Source Control in VS Code

This guide covers the Source Control pane in this Windows Health Monitor project. VS Code's built-in Git support works with the same local repository as Git in the terminal. It does not need a GitHub account, and a commit does not upload anything.

The safest routine is: **review → stage → review staged → write a message → commit → verify**. A commit should contain one coherent change, not every file Git happens to list.

## 1. Open the right repository

1. Open `C:\Scripts\WindowsHealthMonitor` in VS Code (**File → Open Folder**).
2. Open **Source Control** with **Ctrl+Shift+G**.
3. Check the branch name in the Source Control view or status bar. This project's branch is `main`.

Git support is built into VS Code. If the Source Control view says Git is unavailable, open **Terminal → New Terminal** and run `git --version`. VS Code's Git integration uses Git installed on the computer.

## 2. Understand the two change lists

- **Changes** are edits in your working folder that have not been staged.
- **Staged Changes** are the exact versions selected for the next commit.
- **U** means untracked (a new file Git has not yet recorded).
- **M** means modified.
- **A** means added to the next commit.
- **D** means deleted.

Saving a file writes it to disk; it does not stage or commit it. Staging also does not create a commit. A commit records the staged snapshot in the local repository.

## 3. Review, stage, and review again

1. Select a file under **Changes** to open its diff. Review what changed before staging it.
2. Hover over a file and select **+** (**Stage Changes**) to include that file. To stage only part of a file, use the diff editor's actions for a selected line or block.
3. Review every file under **Staged Changes**. Selecting one shows what the next commit would record.
4. If a staged file does not belong in this commit, select **-** (**Unstage Changes**). This keeps the file and its edits; it only removes it from the next commit.

Avoid **Stage All Changes** unless you have reviewed every listed file and intend to include all of them. In particular, check exported reports, archives, duplicate copies, and settings files rather than assuming they belong with a script change.

**Unstage** and **Discard Changes** are different. Unstage preserves the work. Discard removes edits from the working file and can lose work; do not use it as a way to tidy the list unless you have checked what it will remove.

## 4. Write a commit message, then commit

1. After reviewing the staged list, enter a short description in the Source Control message box. For example: `Fix dot-sourcing test guard`.
2. Select **Commit**.
3. Verify that the committed files leave the staged list and that the new commit appears in **Source Control Graph**. You can also check **Terminal → New Terminal** with:

   ```powershell
   git status --short --branch
   git log -1 --oneline
   ```

Always enter the message in the Source Control message box before selecting **Commit**. If it is empty, VS Code may ask Git to open its commit-message editor helper. If that helper does not return a message, the commit fails with an editor error and Git says to supply a message with `-m` or `-F`. Do not change Git's `core.editor` to fix this VS Code workflow; type the message in the Source Control box and retry.

## 5. What happened in this project

On 30 October 2026, the Source Control view appeared to keep working on a commit. The Git output shows `git commit --quiet` ran for about 9½ minutes and then failed: VS Code's `git-editor.sh` had not supplied a commit message, and Git reported, "Please supply the message using either -m or -F option." Git's author name and email were configured. This was not a missing identity or a damaged repository; the required message had not been accepted by the editor hand-off.

The waiting operation was cancelled without changing the index. All 33 staged paths remained staged, and no commit was made. The staged set included the script and test changes, but also many files under `Claude outputs`; it should be reviewed and split into intentional commits before committing.

For next time:

- Put the message in the Source Control message box before selecting **Commit**. This avoids the editor hand-off that failed here.
- Check the staged files before committing, especially when VS Code has staged changes for you.
- To understand a slow or failed operation, open **View → Output** and choose **Git** in the Output channel list. Read the error before trying again; do not repeatedly click Commit.
- Do not delete `.git/index.lock` just because Git seems slow. First check whether a Git operation is active; a lock can protect an operation that is still running.

## 6. Local commits and online sharing

A commit saves a snapshot to this computer's Git history. It is not the same as **Push**, which uploads commits to a configured remote repository. Fetch, Pull, Push, and Sync are separate operations; do not choose them just to finish a local commit.

## Official VS Code documentation

This guide follows the official VS Code documentation:

- [Source control in VS Code](https://code.visualstudio.com/docs/sourcecontrol/overview) - built-in Git support, views, review, staging, commits, and remotes.
- [Quickstart: use source control in VS Code](https://code.visualstudio.com/docs/sourcecontrol/quickstart) - a first-commit walkthrough and the distinction between saving, staging, and committing.
- [Stage and commit changes](https://code.visualstudio.com/docs/sourcecontrol/staging-commits) - reviewing diffs, staging files or selected lines, committing, and undo options.
- [Troubleshoot source control](https://code.visualstudio.com/docs/sourcecontrol/troubleshooting) - using the Git Output channel to diagnose failures.

The procedures here apply those documented workflows to this project's current staged changes and the observed waiting commit.
