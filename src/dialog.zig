const std = @import("std");
const Io = std.Io;

const BOOL = i32;
const DWORD = u32;
const HWND = *anyopaque;
const ASFW_ANY: DWORD = 0xFFFFFFFF;

const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

extern "user32" fn AllowSetForegroundWindow(dwProcessId: DWORD) callconv(.winapi) BOOL;
extern "user32" fn GetForegroundWindow() callconv(.winapi) ?HWND;
extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;

pub const Center = struct { x: i32, y: i32 };

const DIALOG_W = 330;
const DIALOG_H = 36;

pub fn captureCenter() Center {
    const hwnd = GetForegroundWindow() orelse return .{ .x = -1, .y = -1 };
    var rect: RECT = undefined;
    if (GetWindowRect(hwnd, &rect) == 0) return .{ .x = -1, .y = -1 };
    return .{
        .x = @divTrunc(rect.left + rect.right, 2),
        .y = @divTrunc(rect.top + rect.bottom, 2),
    };
}

// Split at the position line so {d} format args can be injected without
// needing to escape all the PowerShell { } in the surrounding script.
const PS_PREFIX =
    "Add-Type -AssemblyName System.Windows.Forms;" ++
    "Add-Type -AssemblyName System.Drawing;" ++
    "$f=New-Object System.Windows.Forms.Form;" ++
    "$f.FormBorderStyle='None';" ++
    "$f.BackColor=[System.Drawing.Color]::FromArgb(55,55,55);" ++
    "$f.TopMost=$true;" ++
    "$f.StartPosition='CenterScreen';" ++
    "$f.ClientSize=New-Object System.Drawing.Size(330,36);" ++
    "$f.Padding=New-Object System.Windows.Forms.Padding(1);" ++
    "$f.KeyPreview=$true;";

const PS_SUFFIX =
    "$t=New-Object System.Windows.Forms.TextBox;" ++
    "$t.Multiline=$true;" ++
    "$t.Dock='Fill';" ++
    "$t.BackColor=[System.Drawing.Color]::FromArgb(30,30,30);" ++
    "$t.ForeColor=[System.Drawing.Color]::FromArgb(204,204,204);" ++
    "$t.BorderStyle='None';" ++
    "$t.Font=New-Object System.Drawing.Font('Consolas',13);" ++
    "$f.Controls.Add($t);" ++
    "$f.Add_KeyDown({" ++
    "if($_.KeyCode -eq 'Return'){$_.SuppressKeyPress=$true;$f.DialogResult='OK';$f.Close()}" ++
    "elseif($_.KeyCode -eq 'Escape'){$f.DialogResult='Cancel';$f.Close()}});" ++
    "$f.Add_Shown({$f.Activate();$t.Focus()});" ++
    "$r=$f.ShowDialog();" ++
    "if($r -eq 'OK' -and $t.Text -ne ''){Write-Output $t.Text}";

pub fn askFilename(gpa: std.mem.Allocator, io: Io, center: Center) !?[]u8 {
    _ = center;
    _ = AllowSetForegroundWindow(ASFW_ANY);

    const ps_cmd = PS_PREFIX ++ PS_SUFFIX;

    const result = try std.process.run(gpa, io, .{
        .argv = &.{ "powershell.exe", "-NoProfile", "-Command", ps_cmd },
        .create_no_window = true,
    });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    const trimmed = std.mem.trim(u8, result.stdout, " \r\n\t");
    if (trimmed.len == 0) return null;
    return try gpa.dupe(u8, trimmed);
}
