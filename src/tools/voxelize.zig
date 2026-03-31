// voxelize.zig — Compute SDF and mesh via for3D voxel module (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to voxelize"},"resolution":{"type":"integer","description":"Voxel grid resolution per axis (default 32)"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const res_str = fmtIntOr(allocator, args.get("resolution"), "32");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\from for3d_shim import as_np_vertices, as_np_faces, point_sdf
        \\import numpy as np
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    verts = as_np_vertices(obj)
        \\    faces = as_np_faces(obj)
        \\    res = {s}
        \\    # Build grid points over bounding box
        \\    bb_min = verts.min(axis=0) - 0.1
        \\    bb_max = verts.max(axis=0) + 0.1
        \\    x = np.linspace(bb_min[0], bb_max[0], res)
        \\    y = np.linspace(bb_min[1], bb_max[1], res)
        \\    z = np.linspace(bb_min[2], bb_max[2], res)
        \\    grid = np.stack(np.meshgrid(x, y, z, indexing='ij'), axis=-1).reshape(-1, 3).astype(np.float32, order='F')
        \\    sdf = point_sdf(verts, faces, grid)
        \\    # Create a volume object placeholder — SDF computed
        \\    n_inside = int((sdf <= 0).sum())
        \\    print(json.dumps({{"object": obj.name, "resolution": res, "grid_points": len(grid), "inside_points": n_inside, "sdf_range": [float(sdf.min()), float(sdf.max())]}}))
    , .{ object_name, object_name, res_str });
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
