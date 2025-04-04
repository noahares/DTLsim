const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "dtlh_simulator",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "dtlh_simulator",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("clap", clap.module("clap"));
    const zprob = b.dependency("zprob", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zprob", zprob.module("zprob"));

    exe.linkLibC();
    exe.linkLibCpp();
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "/usr/lib/libstdc++.so" } });

    // CMake Build Step
    const corax_build = b.addSystemCommand(&[_][]const u8{ "cmake", "-S", "lib/coraxlib", "-B", "zig-out/coraxlib-build" });
    // corax_build.step.dependOn(b.getInstallStep());

    const corax_make = b.addSystemCommand(&[_][]const u8{ "make", "-C", "zig-out/coraxlib-build" });
    corax_make.step.dependOn(&corax_build.step);

    // Add dependency step
    exe.step.dependOn(&corax_make.step);

    // Link the generated static library
    exe.addObjectFile(.{
        .src_path = .{ .owner = b, .sub_path = "lib/coraxlib/bin/libcorax.a" },
    });
    // Include path for headers
    exe.addIncludePath(.{
        .src_path = .{ .owner = b, .sub_path = "lib/coraxlib/src" },
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    const exe_check = b.addExecutable(.{
        .name = "dtlh_simulator",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_check.root_module.addImport("clap", clap.module("clap"));
    exe_check.root_module.addImport("zprob", zprob.module("zprob"));

    exe_check.linkLibC();
    exe_check.linkLibCpp();
    exe.addObjectFile(.{ .src_path = .{ .owner = b, .sub_path = "/usr/lib/libstdc++.so" } });
    exe_check.addObjectFile(.{
        .src_path = .{ .owner = b, .sub_path = "lib/coraxlib/bin/libcorax.a" },
    });
    exe_check.addIncludePath(.{
        .src_path = .{ .owner = b, .sub_path = "lib/coraxlib/src" },
    });

    const check = b.step("check", "Check if app compiles");
    check.dependOn(&exe_check.step);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
