const std = @import("std");

const INPUT_KEYBOARD: u32 = 1;
const KEYEVENTF_KEYUP: u32 = 0x0002;
const VK_CONTROL: u16 = 0x11;
const VK_V: u16 = 'V';

// KEYBDINPUT padded to sizeof(MOUSEINPUT) = 32 bytes on x64
const KEYBDINPUT = extern struct {
    wVk: u16 = 0,
    wScan: u16 = 0,
    dwFlags: u32 = 0,
    time: u32 = 0,
    dwExtraInfo: usize = 0, // ULONG_PTR; Zig extern struct adds 4-byte pad before this
    _union_pad: [8]u8 = .{0} ** 8, // pad to 32 bytes (size of MOUSEINPUT on x64)
};

// INPUT: type(4) + implicit_pad(4) + union(32) = 40 bytes on x64
const INPUT = extern struct {
    type: u32 = INPUT_KEYBOARD,
    ki: KEYBDINPUT = .{},
};

comptime {
    // Catch layout mismatches at compile time
    std.debug.assert(@sizeOf(KEYBDINPUT) == 32);
    std.debug.assert(@sizeOf(INPUT) == 40);
}

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;

extern "user32" fn SendInput(
    cInputs: u32,
    pInputs: [*]const INPUT,
    cbSize: i32,
) callconv(.winapi) u32;

pub fn sendCtrlV() !void {
    Sleep(50);

    const inputs = [4]INPUT{
        .{ .ki = .{ .wVk = VK_CONTROL } },
        .{ .ki = .{ .wVk = VK_V } },
        .{ .ki = .{ .wVk = VK_V, .dwFlags = KEYEVENTF_KEYUP } },
        .{ .ki = .{ .wVk = VK_CONTROL, .dwFlags = KEYEVENTF_KEYUP } },
    };

    const sent = SendInput(inputs.len, &inputs, @sizeOf(INPUT));
    if (sent != inputs.len) return error.SendInputFailed;
}
