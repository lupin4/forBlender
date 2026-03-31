// mesh_smooth.zig — Laplacian smoothing via for3D kernels (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to smooth"},"iterations":{"type":"integer","description":"Number of smoothing passes (default 1)"},"factor":{"type":"number","description":"Smoothing strength 0.0-1.0 (default 0.5)"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const iters_str = fmtIntOr(allocator, args.get("iterations"), "1");
    const factor_str = fmtNumOr(allocator, args.get("factor"), "0.5");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\from for3d_shim import as_np_vertices, as_np_faces, apply_vertices
        \\import numpy as np
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    # Use Blender's built-in smooth with for3D vertex data path
        \\    verts = as_np_vertices(obj)
        \\    faces = as_np_faces(obj)
        \\    nv = len(verts)
        \\    iters = {s}
        \\    factor = {s}
        \\    # Laplacian smooth: for each iteration, average neighbors
        \\    from for3d_shim import compute_vertex_normals, compute_face_areas
        \\    for _ in range(iters):
        \\        new_verts = verts.copy()
        \\        # Build adjacency and smooth
        \\        adj = [[] for _ in range(nv)]
        \\        for f in faces:
        \\            for i in range(3):
        \\                adj[f[i]].append(f[(i+1)%3])
        \\                adj[f[i]].append(f[(i+2)%3])
        \\        for i in range(nv):
        \\            if adj[i]:
        \\                neighbors = np.array([verts[j] for j in set(adj[i])], dtype=np.float32)
        \\                avg = neighbors.mean(axis=0)
        \\                new_verts[i] = verts[i] * (1.0 - factor) + avg * factor
        \\        verts = new_verts
        \\    apply_vertices(obj, verts)
        \\    print(json.dumps({{"object": obj.name, "vertices": nv, "iterations": iters, "factor": factor}}))
    , .{ object_name, object_name, iters_str, factor_str });
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
