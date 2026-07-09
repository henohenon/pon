const std = @import("std");
const Io = std.Io;

const BOOL = i32;
const DWORD = u32;
const ASFW_ANY: DWORD = 0xFFFFFFFF;

extern "user32" fn AllowSetForegroundWindow(dwProcessId: DWORD) callconv(.winapi) BOOL;

pub const Center = struct { x: i32, y: i32 };

pub fn captureCenter() Center {
    return .{ .x = -1, .y = -1 };
}

// Z-order: ShowDialog(IWin32Window) makes the dialog an owned window of Zed.
// Owned windows are always above their owner — no TopMost games needed.
// SetProcessDPIAware() before any HWND so GetWindowRect coords are correct.
// Form.Location before ShowDialog is silently dropped; SetWindowPos in Shown is the fix.
// Opacity=0 hides the initial (0,0) position; set to 1 after SetWindowPos.
const PS_CMD =
    "Add-Type -AssemblyName System.Windows.Forms;" ++
    "Add-Type -AssemblyName System.Drawing;" ++
    "Add-Type 'using System;using System.Runtime.InteropServices;" ++
    "[StructLayout(LayoutKind.Sequential)]" ++
    "public struct RECT{public int L,T,R,B;}" ++
    "public class W32{" ++
    "[DllImport(\"user32.dll\")]public static extern bool SetProcessDPIAware();" ++
    "[DllImport(\"user32.dll\")]public static extern bool GetWindowRect(IntPtr h,out RECT r);" ++
    "[DllImport(\"user32.dll\")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int ht,uint f);" ++
    "[DllImport(\"user32.dll\")]public static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,IntPtr l);" ++
    "[DllImport(\"user32.dll\")]public static extern bool SetForegroundWindow(IntPtr h);" ++
    "[DllImport(\"user32.dll\")]public static extern IntPtr GetForegroundWindow();" ++
    "[DllImport(\"user32.dll\")]public static extern uint GetWindowThreadProcessId(IntPtr h,IntPtr p);" ++
    "[DllImport(\"user32.dll\")]public static extern bool AttachThreadInput(uint a,uint b,bool f);" ++
    "[DllImport(\"kernel32.dll\")]public static extern uint GetCurrentThreadId();" ++
    "}';" ++
    "Add-Type -TypeDefinition 'using System;using System.Windows.Forms;" ++
    "public class HwndWrapper:IWin32Window{" ++
    "IntPtr _h;public HwndWrapper(IntPtr h){_h=h;}" ++
    "public IntPtr Handle{get{return _h;}}}'" ++
    " -ReferencedAssemblies ([System.Windows.Forms.Form].Assembly.Location);" ++
    "[W32]::SetProcessDPIAware()|Out-Null;" ++
    "$zh=[IntPtr]::Zero;" ++
    "$zp=Get-Process -Name 'zed' -ErrorAction SilentlyContinue|" ++
    "Where-Object{$_.MainWindowHandle -ne [IntPtr]::Zero}|Select-Object -First 1;" ++
    "if($zp){$zh=$zp.MainWindowHandle};" ++
    "$own=if($zh -ne [IntPtr]::Zero){New-Object HwndWrapper($zh)}else{$null};" ++
    "$f=New-Object System.Windows.Forms.Form;" ++
    "$f.FormBorderStyle='None';" ++
    "$f.BackColor=[System.Drawing.Color]::FromArgb(55,55,55);" ++
    "$f.TopMost=$true;" ++
    "$f.StartPosition='Manual';" ++
    "$f.Opacity=0;" ++
    "$f.ClientSize=New-Object System.Drawing.Size(330,46);" ++
    "$f.Padding=New-Object System.Windows.Forms.Padding(1);" ++
    "$f.KeyPreview=$true;" ++
    "$t=New-Object System.Windows.Forms.TextBox;" ++
    "$t.BorderStyle='None';" ++
    "$t.Font=New-Object System.Drawing.Font('Consolas',13);" ++
    "$t.BackColor=[System.Drawing.Color]::FromArgb(30,30,30);" ++
    "$t.ForeColor=[System.Drawing.Color]::FromArgb(204,204,204);" ++
    "$t.Dock='Fill';" ++
    "$tlp=New-Object System.Windows.Forms.TableLayoutPanel;" ++
    "$tlp.Dock='Fill';" ++
    "$tlp.BackColor=[System.Drawing.Color]::FromArgb(30,30,30);" ++
    "$tlp.RowCount=3;" ++
    "$tlp.ColumnCount=1;" ++
    "$tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent',50)))|Out-Null;" ++
    "$tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))|Out-Null;" ++
    "$tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent',50)))|Out-Null;" ++
    "$tlp.Controls.Add($t,0,1)|Out-Null;" ++
    "$f.Controls.Add($tlp);" ++
    "$f.Add_KeyDown({" ++
    "if($_.KeyCode -eq 'Return'){$_.SuppressKeyPress=$true;$f.DialogResult='OK';$f.Close()}" ++
    "elseif($_.KeyCode -eq 'Escape'){$f.DialogResult='Cancel';$f.Close()}});" ++
    "$f.Add_Shown({" ++
    "if($zh -ne [IntPtr]::Zero){" ++
    "$zr=New-Object RECT;" ++
    "[W32]::GetWindowRect($zh,[ref]$zr)|Out-Null;" ++
    "$cx=[int](($zr.L+$zr.R)/2)-165;" ++
    "$cy=[int](($zr.T+$zr.B)/2)-23;" ++
    "[W32]::SetWindowPos($f.Handle,[IntPtr]::Zero,$cx,$cy,0,0,1)|Out-Null};" ++
    "$f.Opacity=1;" ++
    "[W32]::SendMessage($t.Handle,0xD3,[IntPtr]3,[IntPtr]((8 -shl 16) -bor 8))|Out-Null;" ++
    "$fw=[W32]::GetForegroundWindow();" ++
    "$ft=[W32]::GetWindowThreadProcessId($fw,[IntPtr]::Zero);" ++
    "$ct=[W32]::GetCurrentThreadId();" ++
    "[W32]::AttachThreadInput($ft,$ct,$true)|Out-Null;" ++
    "[W32]::SetForegroundWindow($f.Handle)|Out-Null;" ++
    "$f.Activate();$t.Focus();" ++
    "[W32]::AttachThreadInput($ft,$ct,$false)|Out-Null;" ++
    "});" ++
    "if($own){$r=$f.ShowDialog($own)}else{$r=$f.ShowDialog()};" ++
    "if($r -eq 'OK' -and $t.Text -ne ''){Write-Output $t.Text}";

pub fn askFilename(gpa: std.mem.Allocator, io: Io, center: Center) !?[]u8 {
    _ = center;
    _ = AllowSetForegroundWindow(ASFW_ANY);

    const result = try std.process.run(gpa, io, .{
        .argv = &.{ "powershell.exe", "-NoProfile", "-Command", PS_CMD },
        .create_no_window = true,
    });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    const trimmed = std.mem.trim(u8, result.stdout, " \r\n\t");
    if (trimmed.len == 0) return null;
    return try gpa.dupe(u8, trimmed);
}
