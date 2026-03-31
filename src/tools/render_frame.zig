// render_frame.zig — Render a single frame to an output path.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"frame":{"type":"integer","description":"Frame number to render, defaults to current frame"},"output_path":{"type":"string","description":"Output file path for the rendered image"},"engine":{"type":"string","description":"Render engine: CYCLES, BLENDER_EEVEE_NEXT, BLENDER_WORKBENCH"}},"required":["output_path"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const output_path = if (args.get("output_path")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;

    const frame_str = if (args.get("frame")) |f| blk: {
        if (f == .integer) break :blk std.fmt.allocPrint(allocator, "{d}", .{f.integer}) catch "None";
        break :blk "None";
    } else "None";

    const engine_line = if (args.get("engine")) |e| blk: {
        if (e == .string) break :blk std.fmt.allocPrint(allocator, "scene.render.engine = '{s}'", .{e.string}) catch "";
        break :blk "";
    } else "";

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\scene = bpy.context.scene
        \\{s}
        \\frame = {s}
        \\if frame is not None:
        \\    scene.frame_set(frame)
        \\scene.render.filepath = "{s}"
        \\bpy.ops.render.render(write_still=True)
        \\print(json.dumps({{"frame": scene.frame_current, "output_path": scene.render.filepath, "engine": scene.render.engine}}))
    , .{ engine_line, frame_str, output_path });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}
