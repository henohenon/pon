const std = @import("std");
const Io = std.Io;
pub const Config = struct {
    target: []const u8,
    dir: Io.Dir,
};

pub fn load(
    gpa: std.mem.Allocator,
    io: Io,
) !Config {
    // Find .env by walking up from exe directory
    var exe_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = try std.process.executablePath(io, &exe_buf);
    const exe_path = exe_buf[0..exe_len];
    const exe_dir = std.fs.path.dirname(exe_path) orelse ".";

    var current = try gpa.dupe(u8, exe_dir);

    var level: usize = 0;
    while (level < 6) : (level += 1) {
        const env_path = try std.fs.path.join(gpa, &.{ current, ".env" });

        const f = Io.Dir.openFileAbsolute(io, env_path, .{}) catch {
            const parent = std.fs.path.dirname(current) orelse break;
            if (std.mem.eql(u8, parent, current)) break;
            current = try gpa.dupe(u8, parent);
            continue;
        };
        defer f.close(io);

        const stat = try f.stat(io);
        const size = @min(stat.size, 4096);
        const buf = try gpa.alloc(u8, size);
        const n = try f.readPositionalAll(io, buf, 0);

        const target = try parseTarget(gpa, buf[0..n]);
        const dir = try Io.Dir.openDirAbsolute(io, current, .{ .access_sub_paths = true });
        return .{ .target = target, .dir = dir };
    }
    return error.EnvNotFound;
}

fn parseTarget(
    gpa: std.mem.Allocator,
    content: []const u8,
) ![]const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\t");
        if (std.mem.startsWith(u8, trimmed, "TARGET=")) {
            return gpa.dupe(u8, trimmed["TARGET=".len..]);
        }
    }
    return error.TargetNotSet;
}
