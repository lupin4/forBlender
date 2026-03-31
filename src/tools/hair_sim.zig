// hair_sim.zig — Hair/fur dynamics via forSim hair pipeline (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the object with particle hair system"},"frames":{"type":"integer","description":"Number of simulation frames (default 50)"},"dt":{"type":"number","description":"Time step in seconds (default 0.016)"},"stiffness":{"type":"number","description":"Hair bending stiffness (default 100.0)"},"damping":{"type":"number","description":"Velocity damping (default 0.05)"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const frames_str = fmtIntOr(allocator, args.get("frames"), "50");
    const dt_str = fmtNumOr(allocator, args.get("dt"), "0.016");
    const stiffness_str = fmtNumOr(allocator, args.get("stiffness"), "100.0");
    const damping_str = fmtNumOr(allocator, args.get("damping"), "0.05");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json, numpy as np, ctypes
        \\import forsim
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None:
        \\    print(json.dumps({{"error": "Object not found: {s}"}}))
        \\else:
        \\    lib = forsim.load_library()
        \\    # Get particle system hair data
        \\    ps = None
        \\    for mod in obj.modifiers:
        \\        if mod.type == 'PARTICLE_SYSTEM':
        \\            if mod.particle_system.settings.type == 'HAIR':
        \\                ps = mod.particle_system
        \\                break
        \\    if ps is None:
        \\        print(json.dumps({{"error": "No hair particle system found on {s}"}}))
        \\    else:
        \\        n_strands = len(ps.particles)
        \\        n_keys = len(ps.particles[0].hair_keys) if n_strands > 0 else 0
        \\        total_verts = n_strands * n_keys
        \\        positions = np.zeros(total_verts * 3, dtype=np.float64)
        \\        idx = 0
        \\        for p in ps.particles:
        \\            for k in p.hair_keys:
        \\                positions[idx:idx+3] = k.co_local[:]
        \\                idx += 3
        \\        frames = {s}
        \\        dt = {s}
        \\        ctx = lib.fs_hair_pipeline_create(
        \\            positions.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
        \\            n_strands, n_keys,
        \\            ctypes.c_double({s}), ctypes.c_double({s})
        \\        )
        \\        if ctx:
        \\            for _ in range(frames):
        \\                lib.fs_hair_pipeline_step(ctx, ctypes.c_double(dt))
        \\            out = np.zeros(total_verts * 3, dtype=np.float64)
        \\            lib.fs_hair_pipeline_get_positions(ctx, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), total_verts)
        \\            lib.fs_hair_pipeline_destroy(ctx)
        \\            out = out.reshape(total_verts, 3)
        \\            idx = 0
        \\            for p in ps.particles:
        \\                for k in p.hair_keys:
        \\                    k.co_local = out[idx]
        \\                    idx += 1
        \\            print(json.dumps({{"object": obj.name, "strands": n_strands, "keys_per_strand": n_keys, "frames": frames}}))
        \\        else:
        \\            print(json.dumps({{"error": "Failed to create hair simulation context"}}))
    , .{ object_name, object_name, object_name, frames_str, dt_str, stiffness_str, damping_str });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}

fn fmtIntOr(allocator: std.mem.Allocator, val: ?std.json.Value, default: []const u8) []const u8 {
    const v = val orelse return default;
    return switch (v) {
        .integer => |i| std.fmt.allocPrint(allocator, "{d}", .{i}) catch default,
        else => default,
    };
}

fn fmtNumOr(allocator: std.mem.Allocator, val: ?std.json.Value, default: []const u8) []const u8 {
    const v = val orelse return default;
    return switch (v) {
        .float => |f| std.fmt.allocPrint(allocator, "{d}", .{f}) catch default,
        .integer => |i| std.fmt.allocPrint(allocator, "{d}", .{i}) catch default,
        else => default,
    };
}
