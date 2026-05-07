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

Issue I encounter:

```bash
$ zig build test
test
└─ run test 1/2 passed, 1 failed
error: 'root.test.attach works' failed: path: /home/spencer/github.com/zig-sqlite-attach-example/single-file.db
[default] (err): unable to prepare statement, got error error.SQLiteError. diagnostics: {code: 1, near: -1, message: no such table: source.envr_env_files}
/home/spencer/.cache/zig/p/sqlite-3.48.0-F2R_a8eODgCnwT0ssaQUTNrsbDeDOtmuOPzF33cgvN13/errors.zig:179:27: 0x107e176 in errorFromResultCode (sqlite.zig)
        c.SQLITE_ERROR => return error.SQLiteError,
                          ^
/home/spencer/.cache/zig/p/sqlite-3.48.0-F2R_a8eODgCnwT0ssaQUTNrsbDeDOtmuOPzF33cgvN13/sqlite.zig:1567:17: 0x10c7704 in prepareWithTail (sqlite.zig)
                return errors.errorFromResultCode(result);
                ^
/home/spencer/.cache/zig/p/sqlite-3.48.0-F2R_a8eODgCnwT0ssaQUTNrsbDeDOtmuOPzF33cgvN13/sqlite.zig:1549:9: 0x109fb79 in prepare (sqlite.zig)
        return prepareWithTail(db, query, options, flags, null);
        ^
/home/spencer/.cache/zig/p/sqlite-3.48.0-F2R_a8eODgCnwT0ssaQUTNrsbDeDOtmuOPzF33cgvN13/sqlite.zig:532:16: 0x107dd31 in prepareDynamicWithDiags (sqlite.zig)
        return try DynamicStatement.prepare(self, query, options, 0);
               ^
/home/spencer/.cache/zig/p/sqlite-3.48.0-F2R_a8eODgCnwT0ssaQUTNrsbDeDOtmuOPzF33cgvN13/sqlite.zig:481:20: 0x118902f in execDynamic__anon_23460 (sqlite.zig)
        var stmt = try self.prepareDynamicWithDiags(query, options);
                   ^
/home/spencer/github.com/zig-sqlite-attach-example/src/root.zig:98:9: 0x1189a5b in test.attach works (root.zig)
        return err;
        ^
error: while executing test 'root.test.attach works', the following test command failed:
./.zig-cache/o/322eb6f8863ba87200c57f40c42aeb46/test --cache-dir=./.zig-cache --seed=0x1461d678 --listen=-

Build Summary: 5/7 steps succeeded; 1 failed; 1/2 tests passed; 1 failed
test transitive failure
└─ run test 1/2 passed, 1 failed

error: the following build command failed with exit code 1:
.zig-cache/o/1af901c87c810087ca61a981554b8206/build /nix/store/zgahw5m4yy873sh5k5h8dd2rjb1fzxbr-zig-0.15.2/bin/zig /nix/store/zgahw5m4yy873sh5k5h8dd2rjb1fzxbr-zig-0.15.2/lib/zig /home/spencer/github.com/zig-sqlite-attach-example .zig-cache /home/spencer/.cache/zig --seed 0x1461d678 -Zaaf3a895a0ede366 test
