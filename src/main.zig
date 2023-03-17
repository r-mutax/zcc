const std = @import("std");


pub fn main() !void {
    const args = std.os.argv;
    if (args.len != 2) {
    }
    var src = args[1][0..countChars(args[1]) : 0];

    // generate AST
    var ast = try Ast.parse(src, std.heap.page_allocator);
    defer ast.deinit();

    // generate C Intermediate Language
    var cil = try CilGen.init(ast, std.heap.page_allocator);
    defer cil.deinit();

    try cil.generate();

    // generate Asmmbuler
    var asmgen = AsmGen.init(cil);
    try asmgen.generate();
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
const CilGen = @import("./CIlGen.zig");
const AsmGen = @import("./AsmGen.zig");
