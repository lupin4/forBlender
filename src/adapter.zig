// adapter.zig — Blender adapter implementation.
//
// Connects via TCP to Blender's Python addon socket (default localhost:9876)
// using the forAgent wire protocol (length-prefixed JSON).
//
// Wire protocol:
//   Send: [4 bytes big-endian length]{"id": N, "cmd": "exec", "data": "<python script>"}
//   Recv: [4 bytes big-endian length]{"id": N, "ok": true/false, "result": ..., "error": "..."}

const std = @import("std");
const foragent = @import("foragent");

pub const BlenderAdapter = struct {
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
    next_id: u32 = 1,

    pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) BlenderAdapter {
        return .{
            .allocator = allocator,
            .host = host,
            .port = port,
        };
    }

    /// Send a Python script to Blender via TCP using wire protocol, return the raw JSON result.
    pub fn executeScript(self: *BlenderAdapter, allocator: std.mem.Allocator, script: []const u8) ![]const u8 {
        const id = self.next_id;
        self.next_id +%= 1;

        // Encode the script into a wire message
        const msg = try foragent.wire.encodeScript(allocator, id, script);
        defer allocator.free(msg);

        // Connect to Blender using std.net (same pattern as forAgent's TcpTransport)
        const address = try std.net.Address.resolveIp(self.host, self.port);
        const stream = try std.net.tcpConnectToAddress(address);
        defer stream.close();

        // Send the full message
        var written: usize = 0;
        while (written < msg.len) {
            const n = stream.write(msg[written..]) catch return error.BrokenPipe;
            if (n == 0) return error.BrokenPipe;
            written += n;
        }

        // Read response: first 4 bytes = length header
        var header_buf: [4]u8 = undefined;
        try readAll(&stream, &header_buf);

        const payload_len = std.mem.readInt(u32, &header_buf, .big);
        if (payload_len > foragent.wire.max_message_size) return error.MessageTooLarge;

        // Read payload
        const payload = try allocator.alloc(u8, payload_len);
        errdefer allocator.free(payload);
        try readAll(&stream, payload);

        return payload;
    }

    /// Read exactly `buf.len` bytes from a stream.
    fn readAll(stream: *const std.net.Stream, buf: []u8) !void {
        var total: usize = 0;
        while (total < buf.len) {
            const n = stream.read(buf[total..]) catch return error.EndOfStream;
            if (n == 0) return error.EndOfStream;
            total += n;
        }
    }
};
