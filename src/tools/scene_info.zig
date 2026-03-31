// scene_info.zig — Get current Blender scene state.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{}}
;

const script =
    \\import bpy, json
    \\scene = bpy.context.scene
    \\objects = [{"name": o.name, "type": o.type, "location": list(o.location)} for o in scene.objects]
    \\camera = scene.camera.name if scene.camera else None
    \\result = {
    \\    "scene_name": scene.name,
    \\    "objects": objects,
    \\    "active_camera": camera,
    \\    "frame_start": scene.frame_start,
    \\    "frame_end": scene.frame_end,
    \\    "frame_current": scene.frame_current,
    \\    "render_engine": scene.render.engine,
    \\    "resolution_x": scene.render.resolution_x,
    \\    "resolution_y": scene.render.resolution_y,
    \\}
    \\print(json.dumps(result))
;

pub fn handle(allocator: std.mem.Allocator, _: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    return adapter.executeScript(allocator, script);
}

test "input_schema is valid JSON" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, input_schema, .{ .allocate = .alloc_always });
    defer parsed.deinit();
}
