const std = @import("std");

const DWORD = u32;
const BOOL = i32;
const HANDLE = *anyopaque;
const CREATE_NO_WINDOW: DWORD = 0x08000000;

const STARTUPINFOW = extern struct {
    cb: DWORD,
    lpReserved: ?[*:0]u16,
    lpDesktop: ?[*:0]u16,
    lpTitle: ?[*:0]u16,
    dwX: DWORD,
    dwY: DWORD,
    dwXSize: DWORD,
    dwYSize: DWORD,
    dwXCountChars: DWORD,
    dwYCountChars: DWORD,
    dwFillAttribute: DWORD,
    dwFlags: DWORD,
    wShowWindow: u16,
    cbReserved2: u16,
    lpReserved2: ?*u8,
    hStdInput: ?HANDLE,
    hStdOutput: ?HANDLE,
    hStdError: ?HANDLE,
};

const PROCESS_INFORMATION = extern struct {
    hProcess: ?HANDLE,
    hThread: ?HANDLE,
    dwProcessId: DWORD,
    dwThreadId: DWORD,
};

extern "kernel32" fn CreateProcessW(
    lpApplicationName: ?[*:0]const u16,
    lpCommandLine: ?[*:0]u16,
    lpProcessAttributes: ?*anyopaque,
    lpThreadAttributes: ?*anyopaque,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?*anyopaque,
    lpCurrentDirectory: ?[*:0]const u16,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) callconv(.winapi) BOOL;

extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.winapi) BOOL;

pub fn inZed(gpa: std.mem.Allocator, path: []const u8) !void {
    // zed CLI is a console-subsystem exe; CREATE_NO_WINDOW suppresses the flash
    const cmd_utf8 = try std.fmt.allocPrint(gpa, "zed \"{s}\"", .{path});
    defer gpa.free(cmd_utf8);
    const cmd_w = try std.unicode.utf8ToUtf16LeAllocZ(gpa, cmd_utf8);
    defer gpa.free(cmd_w);

    var si: STARTUPINFOW = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    var pi: PROCESS_INFORMATION = std.mem.zeroes(PROCESS_INFORMATION);

    if (CreateProcessW(null, cmd_w.ptr, null, null, 0, CREATE_NO_WINDOW, null, null, &si, &pi) == 0)
        return error.ZedLaunchFailed;

    _ = CloseHandle(pi.hProcess.?);
    _ = CloseHandle(pi.hThread.?);
}
