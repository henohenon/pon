# Active file detection — design & limits

How pon decides which `.md` file to embed the pasted image into.

## How it works

1. Copy Zed's SQLite state DB and read all **active editors** (the focused tab of
   each open workspace), newest-first (`ORDER BY workspaces.timestamp DESC`).
2. Pick the **first one whose full path is under `TARGET`** (from `.env`).
3. Save the image next to that note and paste the Markdown link.
4. If nothing is under `TARGET`, stop and do nothing.

Full paths come straight from the DB (`editors.buffer_path`) — pon never guesses
or reconstructs them.

## Why filter by `TARGET` instead of just taking the newest tab

`workspaces.timestamp` is the workspace's last-serialize time, **not** which window
has OS focus. If an AI agent edits another project while you write notes, that
workspace's timestamp wins and the newest tab is the wrong file. Filtering by
`TARGET` picks your notes regardless.

## Limits — why pon does NOT follow the focused window

Zed exposes nothing that reliably links the focused OS window to a file path
(investigated 2026-07-20):

| Signal | Problem |
|---|---|
| `GetForegroundWindow` + title | Title is only `"<root-folder> — <file-name>"`; needs fuzzy text-matching to get a path |
| DB `window_x/y/width/height` | Doesn't match live `GetWindowRect` (stale logical coords) |
| DB `session_id IS NOT NULL` | Lists ~19 "open" workspaces when only 3 windows exist |
| UI Automation | Zed window has zero accessibility descendants — only the title |

So "embed into whatever project I'm focused on" would rest on fragile title text
matching. We don't do it.

**To change the target, do it Stream Deck-side** (per-button launchers/args), not by
making pon smarter.

## Deferred

Multi-root support is an easy extension: `;`-separated roots in `TARGET`, save
images relative to the matched root. Not implemented — single root is enough for now.
