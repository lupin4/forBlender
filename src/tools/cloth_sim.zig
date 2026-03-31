// cloth_sim.zig — Run cloth/XPBD simulation on a mesh via forSim (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to simulate as cloth"},"frames":{"type":"integer","description":"Number of simulation frames to run (default 100)"},"dt":{"type":"number","description":"Time step in seconds (default 0.016)"},"stiffness":{"type":"number","description":"Stretch stiffness (default 1000.0)"},"damping":{"type":"number","description":"Velocity damping (default 0.01)"},"pin_group":{"type":"string","description":"Vertex group name for pinned vertices (optional)"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const frames_str = fmtIntOr(allocator, args.get("frames"), "100");
    const dt_str = fmtNumOr(allocator, args.get("dt"), "0.016");
    const stiffness_str = fmtNumOr(allocator, args.get("stiffness"), "1000.0");
    const damping_str = fmtNumOr(allocator, args.get("damping"), "0.01");
    const pin_group = if (args.get("pin_group")) |v| (if (v == .string) v.string else "") else "";

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json, numpy as np, ctypes
        \\import forsim
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    lib = forsim.load_library()
        \\    mesh = obj.data
        \\    mesh.calc_loop_triangles()
        \\    nv = len(mesh.vertices)
        \\    nf = len(mesh.loop_triangles)
        \\    verts = np.array([v.co[:] for v in mesh.vertices], dtype=np.float64).flatten()
        \\    faces = np.array([t.vertices[:] for t in mesh.loop_triangles], dtype=np.int32).flatten()
        \\    # Pin mask from vertex group
        \\    pin_group = "{s}"
        \\    pin_mask = np.zeros(nv, dtype=np.int32)
        \\    if pin_group and pin_group in obj.vertex_groups:
        \\        gi = obj.vertex_groups[pin_group].index
        \\        for i, v in enumerate(mesh.vertices):
        \\            for g in v.groups:
        \\                if g.group == gi and g.weight > 0.5:
        \\                    pin_mask[i] = 1
        \\    frames = {s}
        \\    dt = {s}
        \\    # Use XPBD pipeline: create, step N times, read back
        \\    ctx = lib.fs_xpbd_pipeline_create(
        \\        verts.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nv,
        \\        faces.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), nf,
        \\        ctypes.c_double({s}), ctypes.c_double({s}),
        \\        pin_mask.ctypes.data_as(ctypes.POINTER(ctypes.c_int))
        \\    )
        \\    if ctx:
        \\        for _ in range(frames):
        \\            lib.fs_xpbd_pipeline_step(ctx, ctypes.c_double(dt))
        \\        out = np.zeros(nv * 3, dtype=np.float64)
        \\        lib.fs_xpbd_pipeline_get_positions(ctx, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nv)
        \\        lib.fs_xpbd_pipeline_destroy(ctx)
        \\        out = out.reshape(nv, 3)
        \\        for i in range(nv):
        \\            mesh.vertices[i].co = out[i]
        \\        mesh.update()
        \\        print(json.dumps({{"object": obj.name, "vertices": nv, "frames": frames, "dt": dt}}))
        \\    else:
        \\        print(json.dumps({{"error": "Failed to create XPBD simulation context"}}))
    , .{ object_name, object_name, pin_group, frames_str, dt_str, stiffness_str, damping_str });
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
