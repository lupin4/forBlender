// set_render_settings.zig — Configure Blender render settings.

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"engine":{"type":"string","description":"Render engine: CYCLES, BLENDER_EEVEE_NEXT, BLENDER_WORKBENCH"},"resolution_x":{"type":"integer","description":"Horizontal resolution in pixels"},"resolution_y":{"type":"integer","description":"Vertical resolution in pixels"},"samples":{"type":"integer","description":"Render samples"},"output_format":{"type":"string","description":"Output format: PNG, JPEG, OPEN_EXR, TIFF, BMP"},"output_path":{"type":"string","description":"Output directory/file path for renders"}}}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));

    var engine_line: []const u8 = "";
    var resx_line: []const u8 = "";
    var resy_line: []const u8 = "";
    var samples_line: []const u8 = "";
    var format_line: []const u8 = "";
    var path_line: []const u8 = "";

    if (arguments) |a| {
        if (a == .object) {
            if (a.object.get("engine")) |v| {
                if (v == .string) engine_line = std.fmt.allocPrint(allocator,
                    "scene.render.engine = '{s}'", .{v.string}) catch "";
            }
            if (a.object.get("resolution_x")) |v| {
                if (v == .integer) resx_line = std.fmt.allocPrint(allocator,
                    "scene.render.resolution_x = {d}", .{v.integer}) catch "";
            }
            if (a.object.get("resolution_y")) |v| {
                if (v == .integer) resy_line = std.fmt.allocPrint(allocator,
                    "scene.render.resolution_y = {d}", .{v.integer}) catch "";
            }
            if (a.object.get("samples")) |v| {
                if (v == .integer) samples_line = std.fmt.allocPrint(allocator,
                    \\if scene.render.engine == 'CYCLES':
                    \\    scene.cycles.samples = {d}
                    \\elif scene.render.engine == 'BLENDER_EEVEE_NEXT':
                    \\    scene.eevee.taa_render_samples = {d}
                , .{ v.integer, v.integer }) catch "";
            }
            if (a.object.get("output_format")) |v| {
                if (v == .string) format_line = std.fmt.allocPrint(allocator,
                    "scene.render.image_settings.file_format = '{s}'", .{v.string}) catch "";
            }
            if (a.object.get("output_path")) |v| {
                if (v == .string) path_line = std.fmt.allocPrint(allocator,
                    "scene.render.filepath = r'{s}'", .{v.string}) catch "";
            }
        }
    }

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json
        \\scene = bpy.context.scene
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\{s}
        \\result = {{
        \\    "engine": scene.render.engine,
        \\    "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        \\    "output_format": scene.render.image_settings.file_format,
        \\    "output_path": scene.render.filepath
        \\}}
        \\print(json.dumps(result))
    , .{ engine_line, resx_line, resy_line, samples_line, format_line, path_line });
    defer allocator.free(script);

    return adapter.executeScript(allocator, script);
}
