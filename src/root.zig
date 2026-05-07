//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const sqlite = @import("sqlite");

test "single-file.db has envr_env_files table" {
    const gpa = std.testing.allocator;

    const dir_path = try std.fs.cwd().realpathAlloc(gpa, ".");
    defer gpa.free(dir_path);

    const path = try std.fs.path.joinZ(
        gpa,
        &.{ dir_path, "single-file.db" },
    );
    defer gpa.free(path);

    var db = try sqlite.Db.init(.{
        .mode = .{ .File = path },
        .open_flags = .{
            .write = false,
            .create = false,
        },
        .threading_mode = .MultiThread,
    });

    var diags: sqlite.Diagnostics = .{};
    var stmt = db.prepareDynamicWithDiags(
        "select name from sqlite_master where type='table'",
        .{ .diags = &diags },
    ) catch |err| {
        std.log.err(
            "unable to prepare statement, got error {}. diagnostics: {f}",
            .{ err, diags },
        );
        return err;
    };
    defer stmt.deinit();

    const tables = (try stmt.oneAlloc(
        []const u8,
        gpa,
        .{ .diags = &diags },
        .{},
    )).?;
    defer gpa.free(tables);

    try std.testing.expectEqualSlices(u8, "envr_env_files", tables);
}

test "attach works" {
    const gpa = std.testing.allocator;

    var db = try sqlite.Db.init(.{
        .mode = .Memory,
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });

    try db.execDynamic(
        \\create table envr_env_files (
        \\  path text primary key not null
        \\, remotes text -- JSON
        \\, sha256 text not null
        \\, contents text not null
        \\)
    , .{}, .{});

    const dir_path = try std.fs.cwd().realpathAlloc(gpa, ".");
    defer gpa.free(dir_path);

    const path = try std.fs.path.join(
        gpa,
        &.{ dir_path, "single-file.db" },
    );
    defer gpa.free(path);

    std.debug.print("path: {s}\n", .{path});

    const attach_sql = try std.fmt.allocPrint(gpa, "ATTACH DATABASE '{s}' AS source", .{path});
    defer gpa.free(attach_sql);
    try db.execDynamic(attach_sql, .{}, .{});
    defer db.execDynamic("DETACH DATABASE source", .{}, .{}) catch unreachable;

    var diags: sqlite.Diagnostics = .{};
    db.execDynamic(
        "INSERT INTO main.envr_env_files SELECT * FROM source.envr_env_files",
        .{ .diags = &diags },
        .{},
    ) catch |err| {
        std.log.err(
            "unable to prepare statement, got error {}. diagnostics: {f}",
            .{ err, diags },
        );
        return err;
    };
}
