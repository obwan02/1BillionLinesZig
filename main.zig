const std = @import("std");

pub const ResultEntry = struct { min: i64, max: i64, total: i64, count: i64 };

pub const Result = struct {
    places: std.StringHashMap(ResultEntry),

    pub fn init(allocator: std.mem.Allocator) Result {
        return Result{ .places = std.StringHashMap(ResultEntry).init(allocator) };
    }
};

var STRING_ALLOC_BUFFER: [1024 * 1024 * 12]u8 = undefined;

pub fn main() !void {
    if (std.os.argv.len <= 1) {
        try std.io.getStdOut().writer().print("usage: {s} <FILE_NAME>", .{std.os.argv[0]});
        return;
    }

    const file_arg = std.os.argv[1][0..std.mem.len(std.os.argv[1])];
    const dir = std.fs.cwd();
    var file = try dir.openFile(file_arg, .{ .mode = .read_only });

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = false,
    }){};
    var sa = std.heap.FixedBufferAllocator.init(&STRING_ALLOC_BUFFER);
    const allocator = gpa.allocator();
    const string_allocator = sa.allocator();

    var result = Result.init(allocator);
    var chunk: [1024 * 1024]u8 = undefined; // 1MB buffer

    while (true) {
        const bytes_read = try file.read(&chunk);
        var slice = chunk[0..bytes_read];
        if (slice.len == 0) break;

        // Resize the chunk to not include partial lines
        {
            var nl_offset_from_end: usize = 0;
            while (slice[slice.len - 1 - nl_offset_from_end] != '\n') : (nl_offset_from_end += 1) {}

            try file.seekBy(-@as(i64, @intCast(nl_offset_from_end)));
            slice.len -= nl_offset_from_end;
        }

        // Hold the current number and station as references
        // to the `slice` array.
        var number_buffer: ?[]u8 = null;
        var current_station: []u8 = slice;
        current_station.len = 0;

        var slice_i: usize = 0;
        while (slice_i < slice.len) : (slice_i += 1) {
            const char = slice[slice_i];
            switch (char) {
                '\n' => {
                    const nb = number_buffer orelse return error.BadFormat;
                    const current_number: i64 = parseNumber(nb);

                    const perm_string = try string_allocator.alloc(u8, current_station.len);
                    @memcpy(perm_string, current_station);
                    var value = try result.places.getOrPut(perm_string);

                    if (value.found_existing) {
                        string_allocator.free(perm_string);
                        if (current_number < value.value_ptr.min) {
                            value.value_ptr.min = current_number;
                        } else if (current_number > value.value_ptr.max) {
                            value.value_ptr.max = current_number;
                        }
                        value.value_ptr.total += @intCast(current_number);
                        value.value_ptr.count += 1;
                    } else {
                        value.value_ptr.* = ResultEntry{ .count = 1, .total = current_number, .min = current_number, .max = current_number };
                    }

                    number_buffer = null;
                    current_station = slice[slice_i + 1 ..];
                    current_station.len = 0;
                },

                ';' => {
                    number_buffer = slice[slice_i + 1 ..];
                    (number_buffer orelse unreachable).len = 0;
                },
                else => if (number_buffer) |*nb| {
                    nb.len += 1;
                } else {
                    current_station.len += 1;
                },
            }
        }
    }

    var stdout = std.io.getStdOut().writer();
    var iter = result.places.iterator();
    while (iter.next()) |entry| {
        const mean = @divFloor(entry.value_ptr.total, entry.value_ptr.count);
        try stdout.print("{s}: {}/{}/{}\n", .{ entry.key_ptr.*, entry.value_ptr.min, mean, entry.value_ptr.max });
    }
}

pub fn parseNumber(str: []u8) i64 {
    if (str.len == 0) return 0;

    var number: i64 = 0;
    if (str[0] == '-') {
        for (str[1..]) |char| {
            if (char == '.') continue;
            number *= 10;
            number += char - 48;
        }

        return number * -1;
    } else {
        for (str[0..]) |char| {
            if (char == '.') continue;
            number *= 10;
            number += char - 48;
        }
    }

    return number;
}
