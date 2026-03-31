// render_sequence.zig — Render a frame range to an output directory.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"frame_start":{"type":"integer","description":"Start frame, defaults to scene frame_start"},"frame_end":{"type":"integer","description":"End frame, defaults to scene frame_end"},"output_dir":{"type":"string","description":"Output directory path for rendered frames"},"file_format":{"type":"string","description":"Output format: PNG, JPEG, OPEN_EXR, etc. Defaults to PNG"},"engine":{"type":"string","description":"Render engine override"}},"required":["output_dir"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const output_dir = if (args.get("output_dir")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;

    const start_str = fmtIntOr(allocator, args.get("frame_start"), "None");
    const end_str = fmtIntOr(allocator, args.get("frame_end"), "None");
    const format_str = if (args.get("file_format")) |f| (if (f == .string) f.string else "PNG") else "PNG";
    const engine_line = if (args.get("engine")) |e| blk: {
        if (e == .string) break :blk std.fmt.allocPrint(allocator, "scene.render.engine = '{s}'", .{e.string}) catch "";
        break :blk "";
    } else "";

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json, os
        \\scene = bpy.context.scene
        \\{s}
        \\fs = {s}
        \\fe = {s}
        \\if fs is not None:
        \\    scene.frame_start = fs
        \\if fe is not None:
        \\    scene.frame_end = fe
        \\output_dir = "{s}"
        \\os.makedirs(output_dir, exist_ok=True)
        \\scene.render.filepath = os.path.join(output_dir, "frame_")
        \\scene.render.image_settings.file_format = '{s}'
        \\bpy.ops.render.render(animation=True)
        \\print(json.dumps({{"frame_start": scene.frame_start, "frame_end": scene.frame_end, "output_dir": output_dir, "format": '{s}'}}))
    , .{ engine_line, start_str, end_str, output_dir, format_str, format_str });
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
