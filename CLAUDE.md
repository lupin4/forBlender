# forBlender Development Guide

Copyright (C) The Fantastic Planet 2025 - By David Clabaugh

## Project Overview

forBlender is the **Blender MCP server binary**. It imports forAgent (the shared agent framework library), implements the Blender adapter, registers Blender-specific tools, and produces a single binary that speaks MCP (JSON-RPC 2.0 over stdio) to AI clients and connects to Blender's Python addon socket via TCP.

**This repo contains only Blender-specific code.** Protocol handling, session management, state tracking, and the tool registry framework all live in forAgent.

## Architecture

```
MCP Client (Claude, etc.)
    ↓ JSON-RPC 2.0 over stdio
forBlender (this binary — adapter + tools)
    ↓ imports
forAgent (library — McpServer, Registry, wire protocol, session, state)
    ↓ imports
forNet (.a archive — TCP, HTTP, WebSocket networking)
    ↓ TCP to localhost:9876 (wire protocol)
Blender Python addon (socket server)
```

### Dependency Chain

```
forNet (.a) → forAgent (Zig lib) → forBlender (binary)
```

## Build Commands

```bash
zig build              # Build forBlender binary → zig-out/bin/forBlender
zig build run          # Run the MCP server
zig build test         # Run tests
```

## Zortran Architecture Rules

- **No standalone C** — all code is Zig or calls through Zig dispatch layers
- **Zig dispatch layer** — forBlender is pure Zig, networking goes through forNet's Zig API
- **forNet conventions for TCP** — use forAgent's wire protocol (length-prefixed JSON) for all target communication
- **Static only** — follows forKernels-wide policy. No shared libraries.

## Wire Protocol

Communication with Blender uses forAgent's wire protocol:

```
[4 bytes big-endian length][JSON payload]

Request:  {"id": <int>, "cmd": "exec", "data": "<python script>"}
Response: {"id": <int>, "ok": true/false, "result": <any>, "error": "<msg>"}
```

The Blender addon listens on `localhost:9876`, receives Python scripts, executes them via `exec()`, and returns JSON results.

## Module Responsibilities

| File | Responsibility |
|------|----------------|
| src/main.zig | Entry point — creates registry, adapter, registers tools, runs McpServer |
| src/adapter.zig | BlenderAdapter — TCP connection to Blender, script execution via wire protocol |
| src/tools.zig | Tool registration — registers all tool handlers with forAgent's Registry |
| src/tools/*.zig | Individual tool modules — each builds a Python bpy script, sends via adapter |

## Tool Handler Contract

Every tool follows the forAgent `ToolHandler` signature:

```zig
fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8
```

- `ctx` is a `*BlenderAdapter` (cast from opaque)
- `arguments` contains the MCP tool call parameters
- Returns the raw JSON result string from Blender
- Each tool builds a Python script string, sends it via `adapter.executeScript()`, and returns the response

## Available Tools

| Tool | Description |
|------|-------------|
| scene_info | Get current scene state (objects, camera, frame range, render settings) |
| create_object | Add mesh primitives (cube, sphere, cylinder, plane, cone, torus) |
| setup_rigid_body | Add rigid body physics to objects (active/passive, mass, friction) |
| bake_sim | Bake physics simulation cache for a frame range |
| render_frame | Render a single frame to a file path |
| render_sequence | Render a frame range to an output directory |
| import_usd | Import USD/USDA/USDC/USDZ files |
| configure_sim | Configure simulation parameters (steps, substeps, gravity) |
| set_render_settings | Configure render engine, resolution, samples, output format |

## Adding New Tools

1. Create `src/tools/my_tool.zig` with:
   - `pub const input_schema = ...;` — JSON Schema string for tool parameters
   - `pub fn handle(allocator, arguments, ctx) ![]const u8` — tool handler
2. Add the tool spec to `src/tools.zig` in the `tool_specs` array
3. Import the module in `src/main.zig` test block

## Blender Addon (`addon/`)

The Blender Python addon (`addon/__init__.py`) is the other half of forBlender. It runs inside Blender as an addon and provides the TCP socket server that the Zig binary connects to.

### Installation
1. In Blender: Edit → Preferences → Add-ons → Install
2. Select `addon/__init__.py` (or zip the `addon/` folder)
3. Enable "forBlender MCP Bridge"

### What it does
- Opens a TCP socket server on `localhost:9876` (configurable)
- Speaks the forAgent wire protocol (length-prefixed JSON)
- Receives Python scripts via `{"cmd": "exec", "data": "<script>"}` messages
- Executes scripts in Blender's Python context via `exec()`
- Captures `print()` output as JSON results
- Returns `{"id": N, "ok": true/false, "result": ..., "error": "..."}` responses

### UI
- Panel in View3D → Sidebar → forBlender tab
- Start/Stop server buttons
- Configurable host, port, auto-start on file load

### Auto-start
With auto-start enabled (default), the server starts automatically when:
- The addon is enabled
- A file is loaded

## File Conventions

- **Zig files only** — no Python, no standalone C
- All networking goes through forAgent → forNet
- No MCP protocol code here — that's forAgent's job
- Tool Python scripts are embedded as Zig string literals
