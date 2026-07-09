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

pub fn captureCenter() Center {
    const hwnd = GetForegroundWindow() orelse return .{ .x = -1, .y = -1 };
    var rect: RECT = undefined;
    if (GetWindowRect(hwnd, &rect) == 0) return .{ .x = -1, .y = -1 };
    return .{
        .x = @divTrunc(rect.left + rect.right, 2),
        .y = @divTrunc(rect.top + rect.bottom, 2),
    };
}

// Static parts of the PowerShell WinForms dialog script.
// Split so position code (containing {d} format args) can be injected in between.
const PS_PREFIX =
    "Add-Type -AssemblyName System.Windows.Forms;" ++
    "Add-Type -AssemblyName System.Drawing;" ++
    "$f=New-Object System.Windows.Forms.Form;" ++
    "$f.Text='pon';" ++
    "$f.ClientSize=New-Object System.Drawing.Size(325,65);" ++
    "$f.TopMost=$true;" ++
    "$f.FormBorderStyle='FixedDialog';" ++
    "$f.MaximizeBox=$false;$f.MinimizeBox=$false;" ++
    "$f.KeyPreview=$true;";

const PS_SUFFIX =
    "$l=New-Object System.Windows.Forms.Label;" ++
    "$l.Text='Image name (without .png):';" ++
    "$l.SetBounds(10,10,305,18);" ++
    "$t=New-Object System.Windows.Forms.TextBox;" ++
    "$t.SetBounds(10,32,305,20);" ++
    "$f.Add_KeyDown({if($_.KeyCode -eq 'Return'){$f.DialogResult='OK';$f.Close()}" ++
    "elseif($_.KeyCode -eq 'Escape'){$f.DialogResult='Cancel';$f.Close()}});" ++
    "$f.Controls.AddRange(@($l,$t));" ++
    "$f.Add_Shown({$f.Activate();$t.Focus()});" ++
    "$r=$f.ShowDialog();" ++
    "if($r -eq 'OK' -and $t.Text -ne ''){Write-Output $t.Text}";

pub fn askFilename(gpa: std.mem.Allocator, io: Io, center: Center) !?[]u8 {
    _ = AllowSetForegroundWindow(ASFW_ANY);

    const pos_part = if (center.x >= 0)
        try std.fmt.allocPrint(gpa,
            "$f.StartPosition='Manual';" ++
            "$f.Location=New-Object System.Drawing.Point(" ++
            "({d}-[int]($f.Width/2)),({d}-[int]($f.Height/2)));",
            .{ center.x, center.y })
    else
        try gpa.dupe(u8, "$f.StartPosition='CenterScreen';");
    defer gpa.free(pos_part);

    const ps_cmd = try std.mem.concat(gpa, u8, &.{ PS_PREFIX, pos_part, PS_SUFFIX });
    defer gpa.free(ps_cmd);

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
