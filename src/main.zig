const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const HashMap = std.StringHashMap(fn (*std.net.Stream) void);

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Logs from your program will appear here!\n", .{});
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("127.0.0.1", 4221);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    while (true) {
        const connection = try listener.accept();
        try stdout.print("client connected!", .{});

        try connection.stream.writeAll("HTTP/1.1 200 OK\r\n\r\n");
        defer connection.stream.close();
        handleRequest(&connection.stream) catch |err| {
            std.debug.print("Error handling request: {}\n", .{err});
        };
    }
}

fn handleRequest(stream: *std.net.Stream) !void {
    var buffer: [1024]u8 = undefined;
    const bytes_read = try stream.reader().read(&buffer);
    const request = buffer[0..bytes_read];

    if (std.mem.indexOf(u8, request, "GET / ") != null or std.mem.indexOf(u8, request, "GET / HTTP") != null) {
        try stream.writer().writeAll("HTTP/1.1 200 OK\r\n\r\n");
    } else {
        try stream.writer().writeAll("HTTP/1.1 404 Not Found\r\n\r\n");
    }
}
