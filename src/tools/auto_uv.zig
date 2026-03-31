// auto_uv.zig — Automatic UV unwrapping via for3D UV module (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to UV unwrap"},"method":{"type":"string","description":"UV projection method: smart_project, sphere, cylinder (default smart_project)","enum":["smart_project","sphere","cylinder"]}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const method = if (args.get("method")) |m| (if (m == .string) m.string else "smart_project") else "smart_project";

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    bpy.context.view_layer.objects.active = obj
        \\    bpy.ops.object.mode_set(mode='EDIT')
        \\    bpy.ops.mesh.select_all(action='SELECT')
        \\    method = "{s}"
        \\    if method == "smart_project":
        \\        bpy.ops.uv.smart_project()
        \\    elif method == "sphere":
        \\        bpy.ops.uv.sphere_project()
        \\    elif method == "cylinder":
        \\        bpy.ops.uv.cylinder_project()
        \\    bpy.ops.object.mode_set(mode='OBJECT')
        \\    uv_name = obj.data.uv_layers.active.name if obj.data.uv_layers.active else "none"
        \\    print(json.dumps({{"object": obj.name, "method": method, "uv_layer": uv_name, "vertices": len(obj.data.vertices)}}))
    , .{ object_name, object_name, method });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}
