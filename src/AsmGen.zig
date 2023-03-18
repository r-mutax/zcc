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
            Cil.Tag.cil_sub => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  sub rax, rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            Cil.Tag.cil_mul => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  imul rax, rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            Cil.Tag.cil_div => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cqo\n");
                _ = try stdout.writeAll("  idiv rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_equal => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  sete al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_not_equal => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  setne al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_gt => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  setl al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_ge => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, rdi\n");
                _ = try stdout.writeAll("  setle al\n");
                _ = try stdout.writeAll("  movzb rax, al\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_bit_and => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  and rax, rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_bit_xor => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  xor rax, rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_bit_or => {
                _ = try stdout.writeAll("  pop rdi\n");
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  or rax, rdi\n");
                _ = try stdout.writeAll("  push rax\n");
            },
            .cil_label => {
                _ = try stdout.print(".L{}:\n", .{cil.lhs});
            },
            .cil_jmp => {
                _ = try stdout.print("  jmp .L{}\n", .{cil.lhs});
            },
            .cil_jz => {
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  je .L{}\n", .{cil.lhs});
            },
            .cil_jnz => {
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  cmp rax, 0\n");
                _ = try stdout.print("  jne .L{}\n", .{cil.lhs});
            }
        }
    }
}

const CilGen = @import("./CIlGen.zig");
const Cil = CilGen.Cil;
const AsmGen = @This();