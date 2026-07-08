const std = @import("std");
const Io = std.Io;
const Environ = std.process.Environ;
const c = @cImport(@cInclude("sqlite3.h"));
const log = @import("log.zig");

const ZED_DB_SUBPATH = "Zed\\db\\0-stable\\db.sqlite";
const QUERY =
    \\SELECT e.buffer_path
    \\FROM items i
    \\JOIN editors e ON i.item_id = e.item_id AND i.workspace_id = e.workspace_id
    \\JOIN workspaces w ON i.workspace_id = w.workspace_id
    \\WHERE i.active = 1 AND i.kind = 'Editor' AND e.buffer_path IS NOT NULL
    \\  AND w.session_id IS NOT NULL
    \\ORDER BY w.timestamp DESC
    \\LIMIT 1
;

pub fn getActiveEditorPath(
    gpa: std.mem.Allocator,
    io: Io,
    env: *Environ.Map,
) !?[]const u8 {
    const local_appdata = env.get("LOCALAPPDATA") orelse return error.NoLocalAppData;
    const temp = env.get("TEMP") orelse env.get("TMP") orelse return error.NoTempDir;

    const db_src = try std.fs.path.join(gpa, &.{ local_appdata, ZED_DB_SUBPATH });
    const db_tmp = try std.fs.path.join(gpa, &.{ temp, "pon_zed_snap.sqlite" });

    try Io.Dir.copyFileAbsolute(db_src, db_tmp, io, .{});
    defer Io.Dir.deleteFileAbsolute(io, db_tmp) catch {};

    log.write("db copy: {s}", .{db_tmp});

    const db_tmp_z = try gpa.dupeZ(u8, db_tmp);
    var db: ?*c.sqlite3 = null;
    if (c.sqlite3_open_v2(db_tmp_z, &db, c.SQLITE_OPEN_READONLY, null) != c.SQLITE_OK) {
        log.write("db open failed", .{});
        return error.DbOpenFailed;
    }
    defer _ = c.sqlite3_close(db);

    var stmt: ?*c.sqlite3_stmt = null;
    if (c.sqlite3_prepare_v2(db, QUERY, -1, &stmt, null) != c.SQLITE_OK) {
        log.write("db prepare failed: {s}", .{c.sqlite3_errmsg(db)});
        return error.DbPrepareFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    const rc = c.sqlite3_step(stmt);
    if (rc == c.SQLITE_DONE) return null;
    if (rc != c.SQLITE_ROW) {
        log.write("db step error: {}", .{rc});
        return error.DbStepFailed;
    }

    const text = c.sqlite3_column_text(stmt, 0) orelse return null;
    const len: usize = @intCast(c.sqlite3_column_bytes(stmt, 0));
    return try gpa.dupe(u8, text[0..len]);
}
