// import_usd.zig — Import USD/USDA/USDC/USDZ files into Blender.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"filepath":{"type":"string","description":"Path to the USD/USDA/USDC/USDZ file to import"}},"required":["filepath"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const filepath = if (args.get("filepath")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\try:
        \\    before = set(bpy.data.objects.keys())
        \\    bpy.ops.wm.usd_import(filepath=r'{s}')
        \\    after = set(bpy.data.objects.keys())
        \\    new_objects = list(after - before)
        \\    print(json.dumps({{"filepath": r'{s}', "imported_objects": new_objects, "count": len(new_objects)}}))
        \\except Exception as e:
        \\    print(json.dumps({{"error": str(e)}}))
    , .{ filepath, filepath });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}
