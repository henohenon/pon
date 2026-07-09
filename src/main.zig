const std = @import("std");
const Io = std.Io;
const config = @import("config.zig");
const db = @import("db.zig");
const clipboard = @import("clipboard.zig");
const dialog = @import("dialog.zig");
const paste = @import("paste.zig");
const log = @import("log.zig");

pub fn main(init: std.process.Init) void {
    const center = dialog.captureCenter(); // capture Zed window center before anything else
    earlyLog(init.io, "pon starting\n");
    const named_mode = parseNamedFlag(init.minimal.args, init.gpa);
    run(init, named_mode, center) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "fatal: {}\n", .{err}) catch "fatal: unknown\n";
        earlyLog(init.io, msg);
        log.write("fatal: {}", .{err});
        std.debug.print("pon: {}\n", .{err});
    };
}

fn parseNamedFlag(args: std.process.Args, gpa: std.mem.Allocator) bool {
    var it = std.process.Args.Iterator.initAllocator(args, gpa) catch return false;
    _ = it.next(); // skip exe name
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) return true;
    }
    return false;
}

fn earlyLog(io: Io, msg: []const u8) void {
    var exe_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = std.process.executablePath(io, &exe_buf) catch return;
    const exe_dir = std.fs.path.dirname(exe_buf[0..exe_len]) orelse return;

    var dir = Io.Dir.openDirAbsolute(io, exe_dir, .{}) catch return;
    defer dir.close(io);

    const f = dir.createFile(io, "pon_early.log", .{ .read = true, .truncate = false }) catch return;
    defer f.close(io);

    const stat = f.stat(io) catch return;
    f.writePositionalAll(io, msg, stat.size) catch {};
}

fn run(init: std.process.Init, named_mode: bool, center: dialog.Center) !void {
    const gpa = init.arena.allocator();
    const io = init.io;
    const env = init.environ_map;

    const cfg = try config.load(gpa, io, env);
    defer cfg.dir.close(io);

    try log.init(cfg.dir, io);
    defer log.deinit();

    log.write("=== pon start ===", .{});
    log.write("target: {s}", .{cfg.target});

    // Find active .md file via Zed SQLite
    const active_path = try db.getActiveEditorPath(gpa, io, env);
    if (active_path == null) {
        log.write("no active editor found", .{});
        return;
    }
    const path = active_path.?;
    log.write("active: {s}", .{path});

    if (!std.mem.endsWith(u8, path, ".md")) {
        log.write("not a .md file, exit", .{});
        return;
    }
    if (!std.mem.startsWith(u8, path, cfg.target)) {
        log.write("not under TARGET, exit", .{});
        return;
    }

    const basename = std.fs.path.basename(path);
    const slug = basename[0 .. basename.len - ".md".len];
    log.write("slug: {s}", .{slug});

    // Named mode: show dialog first (before clipboard check)
    const named_input: ?[]u8 = if (named_mode) blk: {
        log.write("mode: named", .{});
        const input = (try dialog.askFilename(gpa, io, center)) orelse {
            log.write("dialog cancelled", .{});
            return;
        };
        log.write("input: {s}", .{input});
        break :blk input;
    } else null;

    // Get PNG bytes from clipboard
    const png = try clipboard.getPng(gpa);
    if (png == null) {
        log.write("no PNG in clipboard", .{});
        return;
    }
    log.write("clipboard: {} bytes", .{png.?.len});

    // Ensure target/images/<slug>/ exists
    var nono_dir = try Io.Dir.openDirAbsolute(io, cfg.target, .{ .access_sub_paths = true });
    defer nono_dir.close(io);

    const img_rel = try std.fmt.allocPrint(gpa, "images\\{s}", .{slug});
    try nono_dir.createDirPath(io, img_rel);

    var img_dir = try nono_dir.openDir(io, img_rel, .{ .access_sub_paths = true, .iterate = true });
    defer img_dir.close(io);

    // Determine image filename
    const name: []const u8 = if (named_input) |input|
        try std.fmt.allocPrint(gpa, "{s}.png", .{input})
    else blk: {
        log.write("mode: auto", .{});
        var max_n: u32 = 0;
        var it = img_dir.iterate();
        while (try it.next(io)) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".png")) continue;
            const stem_n = entry.name[0 .. entry.name.len - 4];
            const n = std.fmt.parseInt(u32, stem_n, 10) catch continue;
            if (n > max_n) max_n = n;
        }
        var name_buf: [16]u8 = undefined;
        break :blk try gpa.dupe(u8, try std.fmt.bufPrint(&name_buf, "{d:0>2}.png", .{max_n + 1}));
    };

    // Save PNG
    const out = try img_dir.createFile(io, name, .{});
    defer out.close(io);
    try out.writePositionalAll(io, png.?, 0);
    log.write("saved: {s}\\{s}", .{ img_rel, name });

    // Build markdown link, set to clipboard, paste
    const stem = name[0 .. name.len - ".png".len];
    const md = try std.fmt.allocPrint(gpa, "![{s}](images/{s}/{s})", .{ stem, slug, name });
    try clipboard.setText(md);
    try paste.sendCtrlV();

    log.write("done: {s}", .{md});
}
