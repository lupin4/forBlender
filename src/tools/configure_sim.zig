// configure_sim.zig — Configure physics simulation parameters.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"steps_per_second":{"type":"integer","description":"Simulation steps per second (default 250)"},"substeps":{"type":"integer","description":"Solver iterations / substeps (default 10)"},"gravity_x":{"type":"number","description":"Gravity X component (default 0.0)"},"gravity_y":{"type":"number","description":"Gravity Y component (default 0.0)"},"gravity_z":{"type":"number","description":"Gravity Z component (default -9.81)"}}}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));

    var steps_str: []const u8 = "None";
    var substeps_str: []const u8 = "None";
    var gx_str: []const u8 = "None";
    var gy_str: []const u8 = "None";
    var gz_str: []const u8 = "None";

    if (arguments) |a| {
        if (a == .object) {
            if (a.object.get("steps_per_second")) |v| {
                if (v == .integer) steps_str = std.fmt.allocPrint(allocator, "{d}", .{v.integer}) catch "None";
            }
            if (a.object.get("substeps")) |v| {
                if (v == .integer) substeps_str = std.fmt.allocPrint(allocator, "{d}", .{v.integer}) catch "None";
            }
            if (a.object.get("gravity_x")) |v| gx_str = fmtNum(allocator, v);
            if (a.object.get("gravity_y")) |v| gy_str = fmtNum(allocator, v);
            if (a.object.get("gravity_z")) |v| gz_str = fmtNum(allocator, v);
        }
    }

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\scene = bpy.context.scene
        \\if scene.rigidbody_world is None:
        \\    print(json.dumps({{"error": "No rigid body world found"}}))
        \\else:
        \\    sps = {s}
        \\    sub = {s}
        \\    gx = {s}
        \\    gy = {s}
        \\    gz = {s}
        \\    if sps is not None:
        \\        scene.rigidbody_world.steps_per_second = sps
        \\    if sub is not None:
        \\        scene.rigidbody_world.solver_iterations = sub
        \\    if gx is not None and gy is not None and gz is not None:
        \\        scene.gravity = (gx, gy, gz)
        \\    elif gx is not None or gy is not None or gz is not None:
        \\        g = list(scene.gravity)
        \\        if gx is not None: g[0] = gx
        \\        if gy is not None: g[1] = gy
        \\        if gz is not None: g[2] = gz
        \\        scene.gravity = tuple(g)
        \\    result = {{
        \\        "steps_per_second": scene.rigidbody_world.steps_per_second,
        \\        "substeps": scene.rigidbody_world.solver_iterations,
        \\        "gravity": list(scene.gravity)
        \\    }}
        \\    print(json.dumps(result))
    , .{ steps_str, substeps_str, gx_str, gy_str, gz_str });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}

fn fmtNum(allocator: std.mem.Allocator, val: std.json.Value) []const u8 {
    return switch (val) {
        .integer => |i| std.fmt.allocPrint(allocator, "{d}", .{i}) catch "None",
        .float => |f| std.fmt.allocPrint(allocator, "{d}", .{f}) catch "None",
        .number_string => |s| s,
        else => "None",
    };
}
