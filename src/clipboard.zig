const std = @import("std");

const CF_TEXT: u32 = 1;
const GMEM_MOVEABLE: u32 = 0x0002;

// Win32 types
const HWND = ?*anyopaque;
const HANDLE = *anyopaque;
const BOOL = i32;
const UINT = u32;

extern "user32" fn OpenClipboard(hWndNewOwner: HWND) callconv(.winapi) BOOL;
extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.winapi) ?HANDLE;
extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
extern "user32" fn SetClipboardData(uFormat: UINT, hMem: ?HANDLE) callconv(.winapi) ?HANDLE;
extern "user32" fn RegisterClipboardFormatA(lpszFormat: [*:0]const u8) callconv(.winapi) UINT;
extern "kernel32" fn GlobalLock(hMem: HANDLE) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GlobalUnlock(hMem: HANDLE) callconv(.winapi) BOOL;
extern "kernel32" fn GlobalSize(hMem: HANDLE) callconv(.winapi) usize;
extern "kernel32" fn GlobalAlloc(uFlags: UINT, dwBytes: usize) callconv(.winapi) ?HANDLE;
extern "kernel32" fn GlobalFree(hMem: HANDLE) callconv(.winapi) ?HANDLE;

pub fn getPng(allocator: std.mem.Allocator) !?[]const u8 {
    const format = RegisterClipboardFormatA("PNG");
    if (format == 0) return error.RegisterFormatFailed;

    if (OpenClipboard(null) == 0) return error.OpenClipboardFailed;
    defer _ = CloseClipboard();

    const handle = GetClipboardData(format) orelse return null;

    const ptr = GlobalLock(handle) orelse return error.GlobalLockFailed;
    defer _ = GlobalUnlock(handle);

    const size = GlobalSize(handle);
    if (size == 0) return null;

    const src: [*]const u8 = @ptrCast(ptr);
    return try allocator.dupe(u8, src[0..size]);
}

pub fn setText(text: []const u8) !void {
    const size = text.len + 1;
    const handle = GlobalAlloc(GMEM_MOVEABLE, size) orelse return error.GlobalAllocFailed;
    var handle_owned = true;
    defer {
        if (handle_owned) _ = GlobalFree(handle);
    }

    const ptr = GlobalLock(handle) orelse return error.GlobalLockFailed;
    const dst: [*]u8 = @ptrCast(ptr);
    @memcpy(dst[0..text.len], text);
    dst[text.len] = 0;
    _ = GlobalUnlock(handle);

    if (OpenClipboard(null) == 0) return error.OpenClipboardFailed;
    defer _ = CloseClipboard();

    _ = EmptyClipboard();
    _ = SetClipboardData(CF_TEXT, handle) orelse return error.SetClipboardFailed;
    handle_owned = false;
}
