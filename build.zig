const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
    } });

    const kernel = b.addExecutable(.{
        .root_source_file = b.path("src/kernel.zig"),
        .optimize = optimize,
        .target = target,
        .name = "kernel",
        .code_model = .medium,
    });
    kernel.setLinkerScript(b.path("src/linker.ld"));
    kernel.addCSourceFiles(.{
        .files = &.{"src/boot.s"},
        .flags = &.{
            "-x", "assembler-with-cpp",
        },
    });
    b.installArtifact(kernel);
}
