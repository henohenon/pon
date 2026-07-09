# pon

Clipboard image → Markdown paste helper for Zed on Windows.

## Modes

| Launcher | Flag | What it does |
|---|---|---|
| `pon.vbs` | *(none)* | Auto: saves clipboard PNG → `images/<slug>/NN.png`, pastes `![NN](…)` |
| `pon-name.vbs` | `--name` | Same, but prompts for a custom filename first |
| `pon-today.vbs` | `--today` | Opens (or creates) today's `YYYY-MM-DD.md` in Zed |
| `pon-new-md.vbs` | `--new-md` | Prompts for a name, opens (or creates) `<name>.md` in Zed |

Assign the `.vbs` files to hotkeys in your launcher (Stream Deck, AutoHotkey, etc.).

## Active file detection

Reads Zed's SQLite state DB (`%LOCALAPPDATA%\Zed\db\0-stable\db.sqlite`) to find the currently active editor. The DB is locked while Zed runs, so pon copies it to a temp file first.

## Config

`.env` file in the same directory as `pon.exe`:

```env
TARGET=D:\path\to\your\notes
```

## Building

```
zig build
```

Requires Zig 0.16.0.
