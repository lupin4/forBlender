# forBlender
Zig-native MCP server for Blender automation. Exposes simulation setup, physics baking, and render dispatch as tools callable by Claude Code and any MCP client. Connects to Blender's Python runtime over TCP via forNet. No Python middleware — single binary, JSON-RPC over stdio. Built on the Zortran architecture for the forKernels ecosystem.
