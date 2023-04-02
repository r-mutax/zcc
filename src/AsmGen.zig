const std = @import("std");
const stdout = std.io.getStdOut().writer();

cilgen: CilGen,

pub fn init(cilgen: CilGen) AsmGen {
    return AsmGen {
        .cilgen = cilgen,
    };
}

pub fn generate(a: *AsmGen) !void {

    _ = try stdout.writeAll(".intel_syntax noprefix\n");
    try a.genAsm();
}

pub fn genAsm(a: *AsmGen) !void {
    
    var idx: usize = 0;
    const num: usize = a.cilgen.getCilSize();
    while(idx < num) : (idx += 1) {
        const cil = a.cilgen.getCil(idx);

        switch (cil.tag) {
            Cil.Tag.cil_pop => {
                _ = try stdout.print("  pop {s}\n", .{ getCilRegisterName(@intToEnum(CilRegister, cil.lhs)) });
            },
            Cil.Tag.cil_load_lvar => {
                _ = try stdout.print("  mov rax, [rbp - {}]\n", .{ cil.lhs });
                _ = try stdout.writeAll("  push rax\n");
            },
            Cil.Tag.cil_store_lvar => {
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.print("  mov [rbp - {}], rax\n", .{ cil.lhs });
                _ = try stdout.writeAll("  push rax\n");               
            },
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
            Cil.Tag.cil_fn_start => {
                var cilgen = a.cilgen;
                var ast = cilgen.ast;
                const ident = ast.getNodeToken(cil.lhs);
                _ = try stdout.print(".global {s}\n", .{ ident });
                _ = try stdout.print("{s}:\n", .{ ident });
                _ = try stdout.writeAll("  push rbp\n");
                _ = try stdout.writeAll("  mov rbp, rsp\n");
                _ = try stdout.print("  sub rsp, {}\n", .{ ((cil.rhs + 15) / 16) * 16});
            },
            Cil.Tag.cil_fn_end => {
                _ = try stdout.writeAll("  mov rsp, rbp\n");
                _ = try stdout.writeAll("  pop rbp\n");
                _ = try stdout.writeAll("  ret\n");
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
            },
            .cil_return => {
                _ = try stdout.writeAll("  pop rax\n");
                _ = try stdout.writeAll("  mov rsp, rbp\n");
                _ = try stdout.writeAll("  pop rbp\n");
                _ = try stdout.writeAll("  ret\n");
            }
        }
    }
}

fn getCilRegisterName(reg: CilRegister) [:0]const u8 {
    return switch(reg){
        CilRegister.rax => "rax",
        CilRegister.rdi => "rdi",
        CilRegister.rsi => "rsi",
        CilRegister.rdx => "rdx",
        CilRegister.rcx => "rcx",
        CilRegister.r8 => "r8",
        CilRegister.r9 => "r9",
    };
}

pub const Scope = struct {

};

const CilGen = @import("./CIlGen.zig");
const Cil = CilGen.Cil;
const CilRegister = CilGen.CilRegister;
const AsmGen = @This();