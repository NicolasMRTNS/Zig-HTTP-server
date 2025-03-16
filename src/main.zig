const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const Router = std.StringHashMap(fn (*std.net.Stream) anyerror!void);

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Logs from your program will appear here!\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var router = Router.init(allocator);
    defer router.deinit();

    try router.put("/", handleRoot);

    const address = try net.Address.resolveIp("127.0.0.1", 4221);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    while (true) {
        const connection = try listener.accept();
        try stdout.print("client connected!", .{});

        defer connection.stream.close();
        handleRequest(&connection.stream, &router) catch |err| {
            std.debug.print("Error handling request: {}\n", .{err});
        };
    }
}

fn handleRequest(stream: *std.net.Stream, router: *Router) !void {
    var buffer: [1024]u8 = undefined;
    const bytes_read = try stream.reader().read(&buffer);
    const request = buffer[0..bytes_read];

    var path: []const u8 = "/";
    if (std.mem.indexOf(u8, request, "GET ")) |start| {
        if (std.mem.indexOf(u8, request[start..], " HTTP")) |end| {
            path = request[start + 4 .. start + end];
        }
    }

    if (router.get(path)) |handler| {
        try handler(stream);
    } else {
        try handleNotFound(stream);
    }
}

fn handleRoot(stream: *std.net.Stream) anyerror!void {
    try stream.writer().writeAll("HTTP/1.1 200 OK\r\n\r\n");
}

fn handleNotFound(stream: *std.net.Stream) anyerror!void {
    try stream.writer().writeAll("HTTP/1.1 404 Not Found\r\n\r\n");
}
