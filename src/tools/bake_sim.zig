// bake_sim.zig — Bake physics simulation cache.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"frame_start":{"type":"integer","description":"Start frame for baking, defaults to scene start"},"frame_end":{"type":"integer","description":"End frame for baking, defaults to scene end"}}}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));

    var start_str: []const u8 = "None";
    var end_str: []const u8 = "None";

    if (arguments) |a| {
        if (a == .object) {
            if (a.object.get("frame_start")) |fs| {
                if (fs == .integer) start_str = std.fmt.allocPrint(allocator, "{d}", .{fs.integer}) catch "None";
            }
            if (a.object.get("frame_end")) |fe| {
                if (fe == .integer) end_str = std.fmt.allocPrint(allocator, "{d}", .{fe.integer}) catch "None";
            }
        }
    }

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\scene = bpy.context.scene
        \\pc = scene.rigidbody_world.point_cache if scene.rigidbody_world else None
        \\if pc is None:
        \\    print(json.dumps({{"error": "No rigid body world found"}}))
        \\else:
        \\    fs = {s}
        \\    fe = {s}
        \\    if fs is not None:
        \\        pc.frame_start = fs
        \\    if fe is not None:
        \\        pc.frame_end = fe
        \\    bpy.ops.ptcache.bake({{"point_cache_index": 0}}, bake=True)
        \\    print(json.dumps({{"frame_start": pc.frame_start, "frame_end": pc.frame_end, "baked": True}}))
    , .{ start_str, end_str });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}
