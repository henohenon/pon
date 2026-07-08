# pon

Clipboard image → Markdown paste helper for Zed on Windows.

## What it does

1. Detects which `.md` file is open in Zed (via window title)
2. Saves the clipboard image as `images/<slug>/NN.png` alongside that file
3. Pastes `![](images/<slug>/NN.png)` at the cursor

Bind it to a hotkey in AutoHotkey or similar — copy a screenshot, press the key, done.

## Spec

### Trigger

Invoked as a CLI: `pon.exe`

### Active file detection

Read Zed's SQLite state database (`%LOCALAPPDATA%\Zed\db\0-stable\db.sqlite`) to find the currently active editor:

```sql
SELECT e.buffer_path
FROM items i
JOIN editors e ON i.item_id = e.item_id AND i.workspace_id = e.workspace_id
WHERE i.active = 1 AND i.kind = 'Editor'
```

- The DB is locked while Zed runs, so pon copies it to a temp file first
- If multiple Zed windows are open, match `workspaces.window_id` against the foreground window handle
- Exit silently if no active editor or the active file is not a `.md`

### Image save

- Source: Windows clipboard (must contain a bitmap/PNG image)
- Destination: `<nono-root>/images/<slug>/NN.png`
  - `<nono-root>` is configured via `NONO` environment variable or a config file
  - `NN` is zero-padded, auto-incremented (e.g. `01`, `02`, …)
- Exit silently if clipboard has no image

### Paste

- Set clipboard text to `![](images/<slug>/NN.png)`
- Send `Ctrl+V` to the active window

## Building

```
zig build
```

Requires the latest stable Zig release.

## Config

Create a `.env` file in the same directory as `pon.exe`:

```env
NONO=D:\1.atrium\nono
```
