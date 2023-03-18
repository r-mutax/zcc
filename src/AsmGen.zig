const std = @import("std");
const stdout = std.io.getStdOut().writer();

cil: CilGen,

pub fn init(cil: CilGen) AsmGen {
    return AsmGen {
        .cil = cil,
    };
}

pub fn generate(a: *AsmGen) !void {

    _ = try stdout.writeAll(".intel_syntax noprefix\n");
    _ = try stdout.writeAll(".global main\n");
    _ = try stdout.writeAll("main:\n");

    try a.genAsm();

    _ = try stdout.writeAll("  pop rax\n");
    _ = try stdout.writeAll("  ret\n");
}

pub fn genAsm(a: *AsmGen) !void {

    var idx: usize = 0;
    const num: usize = a.cil.getCilSize();
    while(idx < num) : (idx += 1) {
        const cil = a.cil.getCil(idx);
        
        switch(cil.tag){
            Cil.Tag.cil_push_imm => {
                _ = try stdout.print("  push {}\n", .{cil.lhs});
            },
            Cil.Tag.cil_add => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  add rax, rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
        }
    }
}

const CilGen = @import("./CIlGen.zig");
const Cil = CilGen.Cil;
const AsmGen = @This();