const std = @import("std");


pub fn main() !void {
    const args = std.os.argv;
    if (args.len != 2) {
    }
    var src = args[1][0..countChars(args[1]) : 0];

    const ast = try Ast.parse(src, std.heap.page_allocator);
    const il = try Cil.generate(ast);
    _ = il;
}

fn countChars(chars: [*:0]u8) usize {
    var i: usize = 0;
    while(true){
        if(chars[i] == 0){
            return i;
        }
        i += 1;
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

const Ast = @import("./AST.zig");
const Cil = @import("./CIL.zig");
