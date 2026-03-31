# forBlender Addon — Socket server for the forBlender MCP server.
#
# This addon opens a TCP socket on localhost:9876 and listens for commands
# from the forBlender Zig binary. It receives Python scripts via the forAgent
# wire protocol (length-prefixed JSON), executes them in Blender's context,
# and returns JSON results.
#
# Wire protocol:
#   [4 bytes big-endian length][JSON payload]
#   Request:  {"id": <int>, "cmd": "exec", "data": "<python script>"}
#   Response: {"id": <int>, "ok": true/false, "result": <any>, "error": "<msg>"}
#
# Copyright (C) The Fantastic Planet 2025 - By David Clabaugh

bl_info = {
    "name": "forBlender MCP Bridge",
    "author": "The Fantastic Planet",
    "version": (0, 1, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > forBlender",
    "description": "Socket server bridging MCP tools to Blender via forAgent wire protocol",
    "category": "System",
}

import bpy
import json
import struct
import threading
import socket
import traceback
import io
from contextlib import redirect_stdout

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

_server_thread = None
_server_socket = None
_running = False

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9876
MAX_MESSAGE_SIZE = 16 * 1024 * 1024  # 16 MB, matches forAgent wire.zig
HEADER_SIZE = 4


# ---------------------------------------------------------------------------
# Wire protocol helpers
# ---------------------------------------------------------------------------

def recv_exact(sock, n):
    """Read exactly n bytes from socket."""
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("Connection closed")
        buf.extend(chunk)
    return bytes(buf)


def read_message(sock):
    """Read one wire protocol message: [4-byte big-endian length][JSON payload]."""
    header = recv_exact(sock, HEADER_SIZE)
    length = struct.unpack(">I", header)[0]
    if length > MAX_MESSAGE_SIZE:
        raise ValueError(f"Message too large: {length} bytes")
    payload = recv_exact(sock, length)
    return json.loads(payload.decode("utf-8"))


def write_message(sock, obj):
    """Write one wire protocol message."""
    payload = json.dumps(obj).encode("utf-8")
    header = struct.pack(">I", len(payload))
    sock.sendall(header + payload)


# ---------------------------------------------------------------------------
# Script execution
# ---------------------------------------------------------------------------

def execute_script(script_text):
    """Execute a Python script in Blender's context and capture print output.

    The script is expected to print a JSON result as its last output line.
    We capture stdout to get that result. If the script raises, we return
    an error response.
    """
    capture = io.StringIO()
    local_ns = {}

    try:
        with redirect_stdout(capture):
            exec(script_text, {"__builtins__": __builtins__}, local_ns)

        output = capture.getvalue().strip()
        if output:
            # Take the last line as the JSON result
            last_line = output.strip().split("\n")[-1]
            try:
                return True, json.loads(last_line)
            except json.JSONDecodeError:
                return True, output
        else:
            return True, None

    except Exception as e:
        tb = traceback.format_exc()
        return False, f"{type(e).__name__}: {e}\n{tb}"


# ---------------------------------------------------------------------------
# Client handler
# ---------------------------------------------------------------------------

def handle_client(conn, addr):
    """Handle a single client connection."""
    try:
        while _running:
            try:
                msg = read_message(conn)
            except (ConnectionError, OSError):
                break

            msg_id = msg.get("id", 0)
            cmd = msg.get("cmd", "")
            data = msg.get("data", "")

            if cmd == "exec":
                ok, result = execute_script(data)
                response = {
                    "id": msg_id,
                    "ok": ok,
                    "result": result,
                }
                if not ok:
                    response["error"] = str(result)
            elif cmd == "ping":
                response = {"id": msg_id, "ok": True, "result": "pong"}
            else:
                response = {
                    "id": msg_id,
                    "ok": False,
                    "error": f"Unknown command: {cmd}",
                }

            try:
                write_message(conn, response)
            except (ConnectionError, OSError):
                break

    finally:
        try:
            conn.close()
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

def server_loop(host, port):
    """Main server loop — accepts connections and spawns handler threads."""
    global _server_socket, _running

    _server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    _server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    _server_socket.settimeout(1.0)

    try:
        _server_socket.bind((host, port))
        _server_socket.listen(5)
        print(f"[forBlender] Server listening on {host}:{port}")

        while _running:
            try:
                conn, addr = _server_socket.accept()
                conn.settimeout(None)
                t = threading.Thread(
                    target=handle_client,
                    args=(conn, addr),
                    daemon=True,
                )
                t.start()
            except socket.timeout:
                continue
            except OSError:
                if _running:
                    raise
                break

    except Exception as e:
        print(f"[forBlender] Server error: {e}")
    finally:
        try:
            _server_socket.close()
        except OSError:
            pass
        _server_socket = None
        print("[forBlender] Server stopped")


def start_server(host=DEFAULT_HOST, port=DEFAULT_PORT):
    """Start the socket server in a background thread."""
    global _server_thread, _running

    if _running:
        print("[forBlender] Server already running")
        return

    _running = True
    _server_thread = threading.Thread(
        target=server_loop,
        args=(host, port),
        daemon=True,
    )
    _server_thread.start()


def stop_server():
    """Stop the socket server."""
    global _running, _server_socket, _server_thread

    if not _running:
        return

    _running = False

    # Close the socket to unblock accept()
    if _server_socket:
        try:
            _server_socket.close()
        except OSError:
            pass

    if _server_thread:
        _server_thread.join(timeout=3.0)
        _server_thread = None

    print("[forBlender] Server stopped")


# ---------------------------------------------------------------------------
# Blender Operators
# ---------------------------------------------------------------------------

class FORBLENDER_OT_start_server(bpy.types.Operator):
    bl_idname = "forblender.start_server"
    bl_label = "Start forBlender Server"
    bl_description = "Start the MCP bridge socket server"

    def execute(self, context):
        prefs = context.scene.forblender_settings
        start_server(prefs.host, prefs.port)
        self.report({"INFO"}, f"forBlender server started on {prefs.host}:{prefs.port}")
        return {"FINISHED"}


class FORBLENDER_OT_stop_server(bpy.types.Operator):
    bl_idname = "forblender.stop_server"
    bl_label = "Stop forBlender Server"
    bl_description = "Stop the MCP bridge socket server"

    def execute(self, context):
        stop_server()
        self.report({"INFO"}, "forBlender server stopped")
        return {"FINISHED"}


# ---------------------------------------------------------------------------
# UI Panel
# ---------------------------------------------------------------------------

class FORBLENDER_PT_panel(bpy.types.Panel):
    bl_label = "forBlender"
    bl_idname = "FORBLENDER_PT_panel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "forBlender"

    def draw(self, context):
        layout = self.layout
        prefs = context.scene.forblender_settings

        box = layout.box()
        box.label(text="MCP Bridge Server", icon="LINKED")

        row = box.row(align=True)
        row.prop(prefs, "host", text="Host")
        row.prop(prefs, "port", text="Port")

        row = box.row(align=True)
        if _running:
            row.operator("forblender.stop_server", text="Stop Server", icon="PAUSE")
            box.label(text="Status: Running", icon="CHECKMARK")
        else:
            row.operator("forblender.start_server", text="Start Server", icon="PLAY")
            box.label(text="Status: Stopped", icon="X")

        if prefs.auto_start:
            box.label(text="Auto-start enabled", icon="INFO")

        box.prop(prefs, "auto_start", text="Auto-start on file load")


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

class ForBlenderSettings(bpy.types.PropertyGroup):
    host: bpy.props.StringProperty(
        name="Host",
        default=DEFAULT_HOST,
        description="Server bind address",
    )
    port: bpy.props.IntProperty(
        name="Port",
        default=DEFAULT_PORT,
        min=1024,
        max=65535,
        description="Server port",
    )
    auto_start: bpy.props.BoolProperty(
        name="Auto Start",
        default=True,
        description="Automatically start the server when Blender opens",
    )


# ---------------------------------------------------------------------------
# App handlers
# ---------------------------------------------------------------------------

@bpy.app.handlers.persistent
def on_load_post(_):
    """Auto-start server on file load if enabled."""
    # Use a small delay to avoid startup race conditions
    if hasattr(bpy.context, "scene") and hasattr(bpy.context.scene, "forblender_settings"):
        prefs = bpy.context.scene.forblender_settings
        if prefs.auto_start and not _running:
            start_server(prefs.host, prefs.port)


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

classes = (
    ForBlenderSettings,
    FORBLENDER_OT_start_server,
    FORBLENDER_OT_stop_server,
    FORBLENDER_PT_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.forblender_settings = bpy.props.PointerProperty(
        type=ForBlenderSettings,
    )
    bpy.app.handlers.load_post.append(on_load_post)

    # Auto-start on addon enable
    start_server()


def unregister():
    stop_server()

    if on_load_post in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.remove(on_load_post)

    del bpy.types.Scene.forblender_settings
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
