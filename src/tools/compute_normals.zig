// compute_normals.zig — Recompute vertex normals via for3D (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to recompute normals for"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\from for3d_shim import as_np_vertices, as_np_faces, compute_vertex_normals, compute_face_areas
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    verts = as_np_vertices(obj)
        \\    faces = as_np_faces(obj)
        \\    face_normals = compute_face_areas(verts, faces)
        \\    normals = compute_vertex_normals(verts, faces, face_normals)
        \\    obj.data.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
        \\    obj.data.update()
        \\    print(json.dumps({{"object": obj.name, "vertices": len(verts)}}))
    , .{ object_name, object_name });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}
