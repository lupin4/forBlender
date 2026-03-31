// create_object.zig — Add a mesh primitive to the Blender scene.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"primitive_type":{"type":"string","description":"Mesh primitive type","enum":["cube","sphere","cylinder","plane","cone","torus"]},"name":{"type":"string","description":"Optional name for the new object"},"location":{"type":"array","description":"XYZ location [x, y, z], defaults to [0, 0, 0]"},"size":{"type":"number","description":"Size/scale of the primitive, defaults to 1.0"}},"required":["primitive_type"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const ptype = if (args.get("primitive_type")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const op = mapPrimitiveOp(ptype) orelse return error.InvalidParams;

    const size_str = fmtNum(allocator, args.get("size"), "1.0");
    var loc_x: []const u8 = "0";
    var loc_y: []const u8 = "0";
    var loc_z: []const u8 = "0";
    if (args.get("location")) |l| {
        if (l == .array and l.array.items.len >= 3) {
            loc_x = fmtVal(allocator, l.array.items[0]);
            loc_y = fmtVal(allocator, l.array.items[1]);
            loc_z = fmtVal(allocator, l.array.items[2]);
        }
    }

    const name_line = if (args.get("name")) |n| blk: {
        if (n == .string) break :blk std.fmt.allocPrint(allocator, "obj.name = \"{s}\"", .{n.string}) catch "";
        break :blk "";
    } else "";

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\bpy.ops.mesh.primitive_{s}_add(size={s}, location=({s}, {s}, {s}))
        \\obj = bpy.context.active_object
        \\{s}
        \\result = {{"name": obj.name, "type": obj.type, "location": list(obj.location)}}
        \\print(json.dumps(result))
    , .{ op, size_str, loc_x, loc_y, loc_z, name_line });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}

fn mapPrimitiveOp(ptype: []const u8) ?[]const u8 {
    const map = .{
        .{ "cube", "cube" },
        .{ "sphere", "uv_sphere" },
        .{ "cylinder", "cylinder" },
        .{ "plane", "plane" },
        .{ "cone", "cone" },
        .{ "torus", "torus" },
    };
    inline for (map) |entry| {
        if (std.mem.eql(u8, ptype, entry[0])) return entry[1];
    }
    return null;
}

fn fmtNum(allocator: std.mem.Allocator, val: ?std.json.Value, default: []const u8) []const u8 {
    const v = val orelse return default;
    return fmtVal(allocator, v);
}

fn fmtVal(allocator: std.mem.Allocator, val: std.json.Value) []const u8 {
    return switch (val) {
        .float => |f| std.fmt.allocPrint(allocator, "{d}", .{f}) catch "0",
        .integer => |i| std.fmt.allocPrint(allocator, "{d}", .{i}) catch "0",
        else => "0",
    };
}

test "mapPrimitiveOp" {
    try std.testing.expectEqualStrings("cube", mapPrimitiveOp("cube").?);
    try std.testing.expectEqualStrings("uv_sphere", mapPrimitiveOp("sphere").?);
    try std.testing.expect(mapPrimitiveOp("banana") == null);
}
