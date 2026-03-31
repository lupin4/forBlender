// mesh_decimate.zig — Decimate mesh via for3D QEM simplification (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to decimate"},"target_faces":{"type":"integer","description":"Target number of output faces"},"target_ratio":{"type":"number","description":"Ratio of faces to keep (0.0-1.0), used if target_faces not set"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const faces_str = fmtIntOr(allocator, args.get("target_faces"), "None");
    const ratio_str = fmtNumOr(allocator, args.get("target_ratio"), "0.5");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\from for3d_shim import decimate_mesh, as_np_vertices, as_np_faces, apply_vertices
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    verts = as_np_vertices(obj)
        \\    faces = as_np_faces(obj)
        \\    nf_orig = len(faces)
        \\    target = {s}
        \\    if target is None:
        \\        target = max(1, int(nf_orig * {s}))
        \\    new_v, new_f = decimate_mesh(verts, faces, target)
        \\    apply_vertices(obj, new_v)
        \\    print(json.dumps({{"object": obj.name, "original_faces": nf_orig, "decimated_faces": len(new_f), "target": target}}))
    , .{ object_name, object_name, faces_str, ratio_str });
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
