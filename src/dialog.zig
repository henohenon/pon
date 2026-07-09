const std = @import("std");
const Io = std.Io;

const PS_CMD =
    "Add-Type -AssemblyName Microsoft.VisualBasic;" ++
    "$r=[Microsoft.VisualBasic.Interaction]::InputBox('Image name (without .png):','pon','');" ++
    "if ($r -ne '') { Write-Output $r }";

pub fn askFilename(gpa: std.mem.Allocator, io: Io) !?[]u8 {
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
