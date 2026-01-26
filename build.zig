// Copyright 2024 TerseTS Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const std = @import("std");

pub fn build(b: *std.Build) !void {

    // Create root module.
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/capi.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    // Task for compilation.
    const library = b.addLibrary(.{
        .name = "tersets",
        .root_module = root_module,
        .linkage = .dynamic,
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
    });

    b.installArtifact(library);

    // Task for running tests.
    const tests = b.addTest(.{
        .root_module = root_module,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const opt_small = std.builtin.OptimizeMode.ReleaseSmall;
    // we build for ARM, but as object files to be linked either on the target or using cross-ld
    const arm_step = b.step("arm", "build a single object file for arm-linux-eabihf");
    // rpi 1a+
    const bcm2835_target_query = try std.Build.parseTargetQuery(.{
        .arch_os_abi = "arm-linux-gnueabihf",
        .cpu_features = "arm1176jzf_s",
    });
    // rpi zero 2 w
    const rp3a0_target_query = try std.Build.parseTargetQuery(.{
        .arch_os_abi = "aarch64-linux-gnueabihf",
        .cpu_features = "cortex_a53",
    });
    const bcm2835_target = b.resolveTargetQuery(bcm2835_target_query);
    const rp3a0_target = b.resolveTargetQuery(rp3a0_target_query);
    const bcm2835_obj = b.addLibrary( .{ // b.addObject(.{
        .name = "tersets_arm_bcm2835",
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi.zig"),
            .target = bcm2835_target,
            .optimize = opt_small,
        }),
        .linkage = .dynamic,
    });
    const rp3a0_obj = b.addLibrary( .{ // b.addObject(.{
        .name = "tersets_arm_rp3a0",
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi.zig"),
            .target = rp3a0_target,
            .optimize = opt_small,
        }),
        .linkage = .dynamic,
    });
    arm_step.dependOn(&bcm2835_obj.step);
    arm_step.dependOn(&rp3a0_obj.step);
    arm_step.dependOn(&(b.addInstallBinFile(bcm2835_obj.getEmittedBin(), "libtersets_arm_bcm2835.so").step));
    arm_step.dependOn(&(b.addInstallBinFile(rp3a0_obj.getEmittedBin(), "libtersets_arm_rp3a0.so").step));
}
