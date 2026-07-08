const std = @import("std");
const Io = std.Io;

const SYSTEMTIME = extern struct {
    wYear: u16,
    wMonth: u16,
    wDayOfWeek: u16,
    wDay: u16,
    wHour: u16,
    wMinute: u16,
    wSecond: u16,
    wMilliseconds: u16,
};
extern "kernel32" fn GetLocalTime(lpSystemTime: *SYSTEMTIME) callconv(.winapi) void;

var log_file: ?Io.File = null;
var log_io: Io = undefined;
var log_offset: u64 = 0;

pub fn init(dir: Io.Dir, io: Io) !void {
    try dir.createDirPath(io, "logs");
    var logs_dir = try dir.openDir(io, "logs", .{});
    defer logs_dir.close(io);

    const f = try logs_dir.createFile(io, "pon.log", .{ .read = true, .truncate = false });
    const stat = try f.stat(io);
    log_file = f;
    log_io = io;
    log_offset = stat.size;
}

pub fn deinit() void {
    if (log_file) |f| f.close(log_io);
    log_file = null;
}

pub fn write(comptime fmt: []const u8, args: anytype) void {
    const f = log_file orelse return;
    var buf: [1024]u8 = undefined;
    var pos: usize = 0;

    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);
    const ts_part = std.fmt.bufPrint(buf[pos..], "[{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}] ", .{
        st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
    }) catch return;
    pos += ts_part.len;

    const msg_part = std.fmt.bufPrint(buf[pos..], fmt, args) catch return;
    pos += msg_part.len;
    if (pos < buf.len) { buf[pos] = '\n'; pos += 1; }

    const msg = buf[0..pos];
    f.writePositionalAll(log_io, msg, log_offset) catch {};
    log_offset += msg.len;
}
