// fracture.zig — Fracture mesh into pieces via forSim fracture module (Zig prebuilt).

const std = @import("std");
const BlenderAdapter = @import("../adapter.zig").BlenderAdapter;

pub const input_schema =
    \\{"type":"object","properties":{"object_name":{"type":"string","description":"Name of the mesh object to fracture"},"num_pieces":{"type":"integer","description":"Number of fracture pieces (default 10)"},"seed":{"type":"integer","description":"Random seed for fracture pattern (default 42)"}},"required":["object_name"]}
;

pub fn handle(allocator: std.mem.Allocator, arguments: ?std.json.Value, ctx: ?*anyopaque) ![]const u8 {
    const adapter: *BlenderAdapter = @ptrCast(@alignCast(ctx orelse return error.MissingContext));
    const args = if (arguments) |a| (if (a == .object) a.object else return error.InvalidParams) else return error.InvalidParams;

    const object_name = if (args.get("object_name")) |v| (if (v == .string) v.string else return error.InvalidParams) else return error.InvalidParams;
    const pieces_str = fmtIntOr(allocator, args.get("num_pieces"), "10");
    const seed_str = fmtIntOr(allocator, args.get("seed"), "42");

    const script = try std.fmt.allocPrint(allocator,
        \\import bpy, json, numpy as np, ctypes
        \\import forsim
        \\
        \\obj = bpy.data.objects.get("{s}")
        \\if obj is None or obj.type != 'MESH':
        \\    print(json.dumps({{"error": "Mesh object not found: {s}"}}))
        \\else:
        \\    lib = forsim.load_library()
        \\    mesh = obj.data
        \\    mesh.calc_loop_triangles()
        \\    nv = len(mesh.vertices)
        \\    nf = len(mesh.loop_triangles)
        \\    verts = np.array([v.co[:] for v in mesh.vertices], dtype=np.float64).flatten()
        \\    faces = np.array([t.vertices[:] for t in mesh.loop_triangles], dtype=np.int32).flatten()
        \\    n_pieces = {s}
        \\    seed = {s}
        \\    # Allocate output: piece labels per face
        \\    labels = np.zeros(nf, dtype=np.int32)
        \\    rc = lib.fs_fracture_voronoi(
        \\        verts.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nv,
        \\        faces.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), nf,
        \\        n_pieces, seed,
        \\        labels.ctypes.data_as(ctypes.POINTER(ctypes.c_int))
        \\    )
        \\    if rc == 0:
        \\        # Separate into distinct objects per label
        \\        unique_labels = np.unique(labels)
        \\        created = []
        \\        for lbl in unique_labels:
        \\            mask = labels == lbl
        \\            piece_tris = np.array([mesh.loop_triangles[i].vertices[:] for i in range(nf) if mask[i]])
        \\            if len(piece_tris) == 0:
        \\                continue
        \\            used_v = np.unique(piece_tris)
        \\            v_map = {{old: new for new, old in enumerate(used_v)}}
        \\            piece_v = np.array([mesh.vertices[i].co[:] for i in used_v], dtype=np.float32)
        \\            piece_f = np.vectorize(v_map.get)(piece_tris)
        \\            new_mesh = bpy.data.meshes.new(f"{s}_piece_{{lbl}}")
        \\            new_mesh.from_pydata(piece_v.tolist(), [], piece_f.tolist())
        \\            new_mesh.update()
        \\            new_obj = bpy.data.objects.new(new_mesh.name, new_mesh)
        \\            bpy.context.collection.objects.link(new_obj)
        \\            created.append(new_obj.name)
        \\        print(json.dumps({{"source": obj.name, "pieces": len(created), "objects": created}}))
        \\    else:
        \\        print(json.dumps({{"error": "Fracture failed", "code": rc}}))
    , .{ object_name, object_name, pieces_str, seed_str, object_name });
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
