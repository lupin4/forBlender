// sph_fluid.zig — SPH fluid simulation via forSim (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"emitter_name":{"type":"string","description":"Name of the emitter mesh object (particle source)"},"frames":{"type":"integer","description":"Number of simulation frames (default 100)"},"dt":{"type":"number","description":"Time step in seconds (default 0.016)"},"particle_count":{"type":"integer","description":"Number of fluid particles (default 5000)"},"rest_density":{"type":"number","description":"Rest density of the fluid (default 1000.0)"},"viscosity":{"type":"number","description":"Fluid viscosity (default 0.01)"}},"required":["emitter_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const emitter_name = if (args.get("emitter_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const frames_str = fmtIntOr(allocator, args.get("frames"), "100");
    const dt_str = fmtNumOr(allocator, args.get("dt"), "0.016");
    const count_str = fmtIntOr(allocator, args.get("particle_count"), "5000");
    const density_str = fmtNumOr(allocator, args.get("rest_density"), "1000.0");
    const viscosity_str = fmtNumOr(allocator, args.get("viscosity"), "0.01");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json, numpy as np, ctypes
        \\import forsim
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None:
        \\    print(json.dumps({{"error": "Emitter object not found: {s}"}}))
        \\else:
        \\    lib = forsim.load_library()
        \\    n_particles = {s}
        \\    frames = {s}
        \\    dt = {s}
        \\    # Initialize particle positions near emitter center
        \\    center = np.array(obj.location[:], dtype=np.float64)
        \\    positions = np.random.randn(n_particles, 3).astype(np.float64) * 0.5 + center
        \\    velocities = np.zeros((n_particles, 3), dtype=np.float64)
        \\    pos_flat = positions.flatten()
        \\    vel_flat = velocities.flatten()
        \\    # Create SPH context
        \\    ctx = lib.fs_sph_pipeline_create(
        \\        pos_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
        \\        vel_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)),
        \\        n_particles,
        \\        ctypes.c_double({s}),
        \\        ctypes.c_double({s})
        \\    )
        \\    if ctx:
        \\        for _ in range(frames):
        \\            lib.fs_sph_pipeline_step(ctx, ctypes.c_double(dt))
        \\        out = np.zeros(n_particles * 3, dtype=np.float64)
        \\        lib.fs_sph_pipeline_get_positions(ctx, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n_particles)
        \\        lib.fs_sph_pipeline_destroy(ctx)
        \\        out = out.reshape(n_particles, 3)
        \\        # Create point cloud mesh from final particle positions
        \\        mesh = bpy.data.meshes.new("{s}_fluid")
        \\        mesh.vertices.add(n_particles)
        \\        for i in range(n_particles):
        \\            mesh.vertices[i].co = out[i]
        \\        mesh.update()
        \\        fluid_obj = bpy.data.objects.new("{s}_fluid", mesh)
        \\        bpy.context.collection.objects.link(fluid_obj)
        \\        print(json.dumps({{"emitter": obj.name, "fluid_object": fluid_obj.name, "particles": n_particles, "frames": frames}}))
        \\    else:
        \\        print(json.dumps({{"error": "Failed to create SPH simulation context"}}))
    , .{ emitter_name, emitter_name, count_str, frames_str, dt_str, density_str, viscosity_str, emitter_name, emitter_name });
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
