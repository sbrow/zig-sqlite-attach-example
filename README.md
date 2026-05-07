I am having issues using attach database.

## Instructions

1. clone the repository and run `nix develop` in its root (or install Zig 0.15.2).
2. Run `zig build test`.

The broken code can be found in [src/root.zig](./src/root.zig):

```zig
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
```

