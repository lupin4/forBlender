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

// for3D tools (Zig prebuilt → forGeo)
const mesh_decimate = @import("tools/mesh_decimate.zig");
const mesh_smooth = @import("tools/mesh_smooth.zig");
const compute_normals = @import("tools/compute_normals.zig");
const voxelize = @import("tools/voxelize.zig");
const auto_uv = @import("tools/auto_uv.zig");
const subdivide = @import("tools/subdivide.zig");

// forSim tools (Zig prebuilt → Fortran kernels)
const cloth_sim = @import("tools/cloth_sim.zig");
const sph_fluid = @import("tools/sph_fluid.zig");
const fracture = @import("tools/fracture.zig");
const hair_sim = @import("tools/hair_sim.zig");

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
    // for3D tools
    .{
        .name = "mesh_decimate",
        .description = "Decimate a mesh using for3D QEM simplification (reduce face count)",
        .input_schema = mesh_decimate.input_schema,
        .handler = &mesh_decimate.handle,
    },
    .{
        .name = "mesh_smooth",
        .description = "Laplacian smoothing on a mesh via for3D kernels",
        .input_schema = mesh_smooth.input_schema,
        .handler = &mesh_smooth.handle,
    },
    .{
        .name = "compute_normals",
        .description = "Recompute vertex normals via for3D normal computation kernels",
        .input_schema = compute_normals.input_schema,
        .handler = &compute_normals.handle,
    },
    .{
        .name = "voxelize",
        .description = "Compute signed distance field (SDF) of a mesh via for3D",
        .input_schema = voxelize.input_schema,
        .handler = &voxelize.handle,
    },
    .{
        .name = "auto_uv",
        .description = "Automatic UV unwrapping (smart project, sphere, or cylinder projection)",
        .input_schema = auto_uv.input_schema,
        .handler = &auto_uv.handle,
    },
    .{
        .name = "subdivide",
        .description = "Loop subdivision on a mesh via for3D subdivision kernels",
        .input_schema = subdivide.input_schema,
        .handler = &subdivide.handle,
    },
    // forSim tools
    .{
        .name = "cloth_sim",
        .description = "Run XPBD cloth simulation on a mesh via forSim",
        .input_schema = cloth_sim.input_schema,
        .handler = &cloth_sim.handle,
    },
    .{
        .name = "sph_fluid",
        .description = "SPH fluid particle simulation via forSim",
        .input_schema = sph_fluid.input_schema,
        .handler = &sph_fluid.handle,
    },
    .{
        .name = "fracture",
        .description = "Voronoi fracture a mesh into pieces via forSim",
        .input_schema = fracture.input_schema,
        .handler = &fracture.handle,
    },
    .{
        .name = "hair_sim",
        .description = "Hair/fur dynamics simulation via forSim Cosserat rod model",
        .input_schema = hair_sim.input_schema,
        .handler = &hair_sim.handle,
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

test "tool_specs has 19 entries" {
    try std.testing.expectEqual(@as(usize, 19), tool_specs.len);
}
