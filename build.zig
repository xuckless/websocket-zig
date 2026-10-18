const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("websocket", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);

    // zlib.h for the Autobahn echo binaries' permessage-deflate (Zig 0.17
    // has no @cImport).
    const zlib_h = b.addWriteFiles().add("zlib_c.h", "#include <zlib.h>\n");
    const zlib_c = b.addTranslateC(.{
        .root_source_file = zlib_h,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }).createModule();

    const echo_server = b.addExecutable(.{
        .name = "echo-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/echo_server.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "websocket", .module = mod },
                .{ .name = "zlib_c", .module = zlib_c },
            },
        }),
    });
    echo_server.root_module.linkSystemLibrary("zlib", .{ .use_pkg_config = .force });

    b.installArtifact(echo_server);

    const echo_run = b.addRunArtifact(echo_server);
    echo_run.addPassthruArgs();

    const echo_step = b.step("echo-server", "Run the Autobahn echo server");
    echo_step.dependOn(&echo_run.step);

    const echo_client = b.addExecutable(.{
        .name = "echo-client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/echo_client.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "websocket", .module = mod },
                .{ .name = "zlib_c", .module = zlib_c },
            },
        }),
    });
    echo_client.root_module.linkSystemLibrary("zlib", .{ .use_pkg_config = .force });
    b.installArtifact(echo_client);

    const examples_step = b.step("examples", "Build all examples");

    const blocking_echo = b.addExecutable(.{
        .name = "blocking-echo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/blocking-echo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "websocket", .module = mod },
            },
        }),
    });
    b.installArtifact(blocking_echo);
    examples_step.dependOn(&blocking_echo.step);

    const http_upgrade = b.addExecutable(.{
        .name = "http-upgrade",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/http-upgrade.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "websocket", .module = mod },
            },
        }),
    });
    b.installArtifact(http_upgrade);
    examples_step.dependOn(&http_upgrade.step);

    const blocking_client = b.addExecutable(.{
        .name = "blocking-client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/blocking-client.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "websocket", .module = mod },
            },
        }),
    });
    b.installArtifact(blocking_client);
    examples_step.dependOn(&blocking_client.step);

    const run_autobahn = b.path("scripts/run-autobahn.nu");

    const conformance_script = b.addSystemCommand(&.{"nu"});

    conformance_script.addFileArg(run_autobahn);

    conformance_script.addArtifactArg(echo_server);
    conformance_script.addArgs(&.{
        "9002",
        "echo-server",
        "fast",
    });
    conformance_script.step.dependOn(&b.addInstallArtifact(echo_server, .{}).step);

    const conformance_step = b.step("conformance", "Run the fast Autobahn conformance suite");
    conformance_step.dependOn(&conformance_script.step);

    const conformance_full_script = b.addSystemCommand(&.{"nu"});

    conformance_full_script.addFileArg(run_autobahn);

    conformance_full_script.addArtifactArg(echo_server);
    conformance_full_script.addArgs(&.{
        "9002",
        "echo-server",
        "full",
    });
    conformance_full_script.step.dependOn(&b.addInstallArtifact(echo_server, .{}).step);

    const conformance_full_step = b.step(
        "conformance-full",
        "Run the full Autobahn conformance test suite",
    );
    conformance_full_step.dependOn(&conformance_full_script.step);

    const run_autobahn_client = b.path("scripts/run-autobahn-client.nu");

    const conformance_client_script = b.addSystemCommand(&.{"nu"});

    conformance_client_script.addFileArg(run_autobahn_client);

    conformance_client_script.addArtifactArg(echo_client);
    conformance_client_script.addArgs(&.{
        "9001",
        "echo-client",
        "fast",
    });
    conformance_client_script.step.dependOn(&b.addInstallArtifact(echo_client, .{}).step);

    const conformance_client_step = b.step(
        "conformance-client",
        "Run the fast Autobahn client conformance suite",
    );
    conformance_client_step.dependOn(&conformance_client_script.step);

    const conformance_client_full_script = b.addSystemCommand(&.{"nu"});

    conformance_client_full_script.addFileArg(run_autobahn_client);

    conformance_client_full_script.addArtifactArg(echo_client);
    conformance_client_full_script.addArgs(&.{
        "9001",
        "echo-client",
        "full",
    });
    conformance_client_full_script.step.dependOn(&b.addInstallArtifact(echo_client, .{}).step);

    const conformance_client_full_step = b.step(
        "conformance-client-full",
        "Run the full Autobahn client conformance test suite",
    );
    conformance_client_full_step.dependOn(&conformance_client_full_script.step);
    // The libxev example (examples/xev-echo.zig) is not built: libxev has
    // no Zig 0.17 port, and the library does not need it.
}
