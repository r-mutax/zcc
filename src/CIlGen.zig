// CIlGen is C Intermediate Language.

pub const CilList = std.MultiArrayList(CilGen.Cil);

ast: Ast = undefined,
gpa: Allocator,
cils: CilList = undefined,
cilidx: usize = 0,
label: u32 = 0,

pub fn init(ast: Ast, gpa: Allocator) !CilGen {
    return CilGen {
        .ast = ast,
        .gpa = gpa,
    };
}

pub fn deinit(c: *CilGen) void {
    c.cils.deinit(c.gpa);
}

pub fn generate(c: *CilGen) !void {
    c.cils = CilList{};

    try c.gen_program(c.ast.root);
}

pub fn getCil(c: *CilGen, idx: usize) Cil {
    return Cil{
        .tag = c.cils.items(.tag)[idx],
        .lhs = c.cils.items(.lhs)[idx],
        .rhs = c.cils.items(.rhs)[idx],
    };
}

pub fn getCilSize(c: *CilGen) usize {
    return c.cils.slice().len;
}

fn addCil(c: *CilGen, tag: Cil.Tag, lhs: u32, rhs: u32) !void {
    try c.cils.append(c.gpa, Cil{
        .tag = tag,
        .lhs = lhs,
        .rhs = rhs,
    });
}

fn getLabelNo(c: *CilGen) u32 {
    const result = c.label;
    c.label += 1;
    return result;
}

fn gen_program(c: *CilGen, node: usize) !void {
    const rng = c.ast.getNodeExtraList(node);

    for( rng ) | idx | {
        try c.gen_stmt(idx);
        try c.addCil(.cil_pop, @enumToInt(CilRegister.rax), 0);
    }
}

fn gen_stmt(c: *CilGen, node: usize) !void {
    switch(c.ast.getNodeTag(node)){
        .nd_return => {
            const extra = c.ast.getNodeExtra(node, Node.Data);
            try c.gen(extra.lhs);
            try c.addCil(.cil_return, 0, 0);
        },
        else => try c.gen_stmt(node),
    }
}

fn gen(c: *CilGen, node: usize) !void {

    switch(c.ast.getNodeTag(node)){
        .nd_num => {
            try c.addCil(.cil_push_imm, @intCast(u32, c.ast.getNodeNumValue(node)), 0);
            return;
        },
        .nd_negation => {
            try c.addCil( .cil_push_imm, 0, 0);

            const extra = c.ast.getNodeExtra(node, Node.Data);
            try c.gen(extra.lhs);
            try c.addCil(.cil_sub, 0, 0);
            return;
        },
        .nd_logic_and => {
            const l_false = c.getLabelNo();
            const l_end = c.getLabelNo();

            const extra = c.ast.getNodeExtra(node, Node.Data);

            // eval lhs
            try c.gen(extra.lhs);
            try c.addCil(.cil_jz, l_false, 0);

            // eval rhs
            try c.gen(extra.rhs);
            try c.addCil(.cil_jz, l_false, 0);

            // write result
            try c.addCil(.cil_push_imm, 1, 0);
            try c.addCil(.cil_jmp, l_end, 0);
            try c.addCil(.cil_label, l_false, 0);
            try c.addCil(.cil_push_imm, 0, 0);
            try c.addCil(.cil_label, l_end, 0);
            return;
        },
        .nd_logic_or => {
            const l_true = c.getLabelNo();
            const l_end = c.getLabelNo();

            const extra = c.ast.getNodeExtra(node, Node.Data);

            // eval lhs
            try c.gen(extra.lhs);
            try c.addCil(.cil_jnz, l_true, 0);

            // eval rhs
            try c.gen(extra.rhs);
            try c.addCil(.cil_jnz, l_true, 0);

            // write result
            try c.addCil(.cil_push_imm, 0, 0);
            try c.addCil(.cil_jmp, l_end, 0);
            try c.addCil(.cil_label, l_true, 0);
            try c.addCil(.cil_push_imm, 1, 0);
            try c.addCil(.cil_label, l_end, 0);
            return;
        },
        else => { },
    }

    const extra = c.ast.getNodeExtra(node, Node.Data);
    try c.gen(extra.lhs);
    try c.gen(extra.rhs);

    switch(c.ast.getNodeTag(node)){
        Node.Tag.nd_add => {
            try c.addCil(.cil_add, 0, 0);
        },
        Node.Tag.nd_sub => {
            try c.addCil(.cil_sub, 0, 0);
        },
        Node.Tag.nd_mul => {
            try c.addCil(.cil_mul, 0, 0);
        },
        Node.Tag.nd_div => {
            try c.addCil(.cil_div, 0, 0);
        },
        Node.Tag.nd_equal => {
            try c.addCil(.cil_equal, 0, 0);
        },
        Node.Tag.nd_not_equal => {
            try c.addCil(.cil_not_equal, 0, 0);
        },
        Node.Tag.nd_gt => {
            try c.addCil(.cil_gt, 0, 0);
        },
        Node.Tag.nd_ge => {
            try c.addCil(.cil_ge, 0, 0);
        },
        Node.Tag.nd_bit_and => {
            try c.addCil(.cil_bit_and, 0, 0);
        },
        Node.Tag.nd_bit_xor => {
            try c.addCil(.cil_bit_xor, 0, 0);
        },
        Node.Tag.nd_bit_or => {
            try c.addCil(.cil_bit_or, 0, 0);
        },
        else => {},
    }
}

pub const CilRegister = enum(u32) { rax, rdi, rsi, rdx, rcx, r8, r9 };

pub const Cil = struct{
    pub const Tag = enum {
        cil_pop,
        // pop
        //  to register...
        //      lhs : 1
        //      rhs : 0  rax
        //            1  rdi
        //            2  rsi
        //            3  rdx
        //            4  rcx
        //            5  r8
        //            6  r9
        
        cil_push_imm,
        // push immidiate
        
        cil_add,
        // add stack top of 2
        
        cil_sub,
        // sub stack top of 2
        
        cil_mul,
        // multiple stack top of 2
        
        cil_div,
        // divide stack top of 2
        
        cil_equal,
        // if stack top of 2 is equal, push 1
        
        cil_not_equal,
        // if stack top of 2 is not equal, push 1
        
        cil_gt,
        cil_ge,
        cil_bit_and,
        cil_bit_xor,
        cil_bit_or,
        cil_label,
        cil_jz,
        // if stack top is 0, then jamp to lhs
        
        cil_jnz,
        // if stack top is none zero, then jamp to lhs
        
        cil_jmp,
        // jmp to lhs

        cil_return,
        // return stack top value
    };

    tag: Tag,
    lhs: u32 = undefined,
    rhs: u32 = undefined,
};

const std = @import("std");
const CilGen = @This();
const Ast = @import("./AST.zig");
const Node = Ast.Node;

const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();

test "Code gen" {
    _ = try stdout.writeAll("\n");

    var ast = try Ast.parse("0", std.heap.page_allocator);
    _ = try stdout.print("{}\n", .{ast.getNodeTag(ast.root)});

    var cil = try CilGen.init(ast, std.heap.page_allocator);
    try cil.generate();

    for(cil.cils.items(.tag)) |a| {
        _ = try stdout.print("{}\n", .{ a });
    }
}