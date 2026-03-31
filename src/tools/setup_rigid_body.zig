// setup_rigid_body.zig — Add rigid body physics to a Blender object.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the object to add rigid body physics to"},"body_type":{"type":"string","description":"Rigid body type: ACTIVE or PASSIVE","enum":["ACTIVE","PASSIVE"]},"mass":{"type":"number","description":"Mass in kg, defaults to 1.0"},"friction":{"type":"number","description":"Friction coefficient, defaults to 0.5"},"restitution":{"type":"number","description":"Bounciness (restitution), defaults to 0.0"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const body_type = if (args.get("body_type")) |bt| (if (bt == .string) bt.string else "ACTIVE") else "ACTIVE";
    const mass_str = fmtNumOr(allocator, args.get("mass"), "1.0");
    const friction_str = fmtNumOr(allocator, args.get("friction"), "0.5");
    const restitution_str = fmtNumOr(allocator, args.get("restitution"), "0.0");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None:
        \\    print(json.dumps({{"error": "Object not found: {s}"}}))
        \\else:
        \\    bpy.context.view_layer.objects.active = obj
        \\    bpy.ops.rigidbody.object_add(type='{s}')
        \\    obj.rigid_body.mass = {s}
        \\    obj.rigid_body.friction = {s}
        \\    obj.rigid_body.restitution = {s}
        \\    result = {{"name": obj.name, "body_type": obj.rigid_body.type, "mass": obj.rigid_body.mass}}
        \\    print(json.dumps(result))
    , .{ object_name, object_name, body_type, mass_str, friction_str, restitution_str });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}

fn fmtNumOr(allocator: std.mem.Allocator, val: ?std.json.Value, default: []const u8) []const u8 {
    const v = val orelse return default;
    return switch (v) {
        .float => |f| std.fmt.allocPrint(allocator, "{d}", .{f}) catch default,
        .integer => |i| std.fmt.allocPrint(allocator, "{d}", .{i}) catch default,
        else => default,
    };
}
