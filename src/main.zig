// main.zig — forBlender entry point.
//
// forBlender is the Blender MCP server. It imports the forAgent framework,
// implements the Blender adapter (TCP to Blender's Python addon socket),
// registers Blender-specific tools, and runs the MCP server loop.
//
// Architecture:
//   MCP Client (Claude, etc.)
//       ↓ JSON-RPC 2.0 over stdio
//   forBlender (this binary)
//       ↓ imports
//   forAgent (library — session, state, registry, MCP protocol)
//       ↓ imports
//   forNet (.a — TCP networking)
//       ↓ TCP to localhost:9876
//   Blender Python addon (socket server)

const std = @import("std");
const foragent = @import("foragent");
const adapter_mod = @import("adapter.zig");
const tools = @import("tools.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Set up registry
    var registry = foragent.Registry.init(allocator);
    defer registry.deinit();

    // Set up Blender adapter
    var blender = adapter_mod.BlenderAdapter.init(allocator, "127.0.0.1", 9876);
    _ = &blender;

    // Register all Blender tools
    try tools.registerAll(&registry, @ptrCast(&blender));

    // Run the MCP server (reads from stdin, writes to stdout)
    var mcp = foragent.McpServer.init(allocator, &registry);
    defer mcp.deinit();
    try mcp.run();
}

test {
    _ = @import("adapter.zig");
    _ = @import("tools.zig");
    _ = @import("tools/scene_info.zig");
    _ = @import("tools/create_object.zig");
    _ = @import("tools/setup_rigid_body.zig");
    _ = @import("tools/bake_sim.zig");
    _ = @import("tools/render_frame.zig");
    _ = @import("tools/render_sequence.zig");
    _ = @import("tools/import_usd.zig");
    _ = @import("tools/configure_sim.zig");
    _ = @import("tools/set_render_settings.zig");
    _ = @import("tools/mesh_decimate.zig");
    _ = @import("tools/mesh_smooth.zig");
    _ = @import("tools/compute_normals.zig");
    _ = @import("tools/voxelize.zig");
    _ = @import("tools/auto_uv.zig");
    _ = @import("tools/subdivide.zig");
    _ = @import("tools/cloth_sim.zig");
    _ = @import("tools/sph_fluid.zig");
    _ = @import("tools/fracture.zig");
    _ = @import("tools/hair_sim.zig");
}
