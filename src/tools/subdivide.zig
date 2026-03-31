// subdivide.zig — Loop subdivision via for3D (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to subdivide"},"levels":{"type":"integer","description":"Number of subdivision levels (default 1)"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const levels_str = fmtIntOr(allocator, args.get("levels"), "1");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\from for3d_shim import as_np_vertices, as_np_faces, subdivide_mesh, apply_vertices
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    verts = as_np_vertices(obj)
        \\    faces = as_np_faces(obj)
        \\    nv_orig = len(verts)
        \\    nf_orig = len(faces)
        \\    levels = {s}
        \\    for _ in range(levels):
        \\        verts, faces = subdivide_mesh(verts, faces)
        \\    # Rebuild mesh with subdivided geometry
        \\    mesh = obj.data
        \\    mesh.clear_geometry()
        \\    mesh.from_pydata(verts.tolist(), [], faces.tolist())
        \\    mesh.update()
        \\    print(json.dumps({{"object": obj.name, "original_verts": nv_orig, "original_faces": nf_orig, "subdivided_verts": len(verts), "subdivided_faces": len(faces), "levels": levels}}))
    , .{ object_name, object_name, levels_str });
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
