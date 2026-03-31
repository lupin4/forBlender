// tools.zig — Tool registration for all Blender MCP tools.
//
// Registers each Blender tool with forAgent's Registry using the standard
// ToolHandler signature. Each tool module provides a handler function and
// an input schema JSON string.

const std = @import("std");
const foragent = @import("foragent");
const scene_info = @import("tools/scene_info.zig");
const create_object = @import("tools/create_object.zig");
const setup_rigid_body = @import("tools/setup_rigid_body.zig");
const bake_sim = @import("tools/bake_sim.zig");
const render_frame = @import("tools/render_frame.zig");
const render_sequence = @import("tools/render_sequence.zig");
const import_usd = @import("tools/import_usd.zig");
const configure_sim = @import("tools/configure_sim.zig");
const set_render_settings = @import("tools/set_render_settings.zig");

const ToolSpec = struct {
    name: []const u8,
    description: []const u8,
    input_schema: []const u8,
    handler: foragent.ToolHandler,
};

const tool_specs = [_]ToolSpec{
    .{
        .name = "scene_info",
        .description = "Get current Blender scene state: objects, active camera, frame range, render settings",
        .input_schema = scene_info.input_schema,
        .handler = &scene_info.handle,
    },
    .{
        .name = "create_object",
        .description = "Add a mesh primitive (cube, sphere, cylinder, plane, cone, torus) to the scene",
        .input_schema = create_object.input_schema,
        .handler = &create_object.handle,
    },
    .{
        .name = "setup_rigid_body",
        .description = "Add rigid body physics to a named object (active or passive, with mass, friction, restitution)",
        .input_schema = setup_rigid_body.input_schema,
        .handler = &setup_rigid_body.handle,
    },
    .{
        .name = "bake_sim",
        .description = "Bake physics simulation cache for a frame range",
        .input_schema = bake_sim.input_schema,
        .handler = &bake_sim.handle,
    },
    .{
        .name = "render_frame",
        .description = "Render a single frame to an output file path",
        .input_schema = render_frame.input_schema,
        .handler = &render_frame.handle,
    },
    .{
        .name = "render_sequence",
        .description = "Render a frame range sequence to an output directory",
        .input_schema = render_sequence.input_schema,
        .handler = &render_sequence.handle,
    },
    .{
        .name = "import_usd",
        .description = "Import a USD/USDA/USDC/USDZ file into the current scene",
        .input_schema = import_usd.input_schema,
        .handler = &import_usd.handle,
    },
    .{
        .name = "configure_sim",
        .description = "Configure physics simulation parameters: steps per second, substeps, gravity vector",
        .input_schema = configure_sim.input_schema,
        .handler = &configure_sim.handle,
    },
    .{
        .name = "set_render_settings",
        .description = "Configure render settings: engine, resolution, samples, output format, output path",
        .input_schema = set_render_settings.input_schema,
        .handler = &set_render_settings.handle,
    },
};

/// Register all Blender tools with the forAgent registry.
pub fn registerAll(registry: *foragent.Registry, ctx: ?*anyopaque) !void {
    for (tool_specs) |spec| {
        try registry.register(
            .{
                .name = spec.name,
                .description = spec.description,
                .input_schema = spec.input_schema,
            },
            spec.handler,
            ctx,
        );
    }
}

test "tool_specs has 9 entries" {
    try std.testing.expectEqual(@as(usize, 9), tool_specs.len);
}
