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

    try c.gen(c.ast.root);
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

fn addCil(c: *CilGen, cil: Cil) !void {
    try c.cils.append(c.gpa, cil);
}

fn getLabelNo(c: *CilGen) u32 {
    const result = c.label;
    c.label += 1;
    return result;
} 

fn gen(c: *CilGen, node: usize) !void {

    switch(c.ast.getNodeTag(node)){
        .nd_num => {
            try c.addCil(Cil{
                .tag = .cil_push_imm,
                .lhs = @intCast(u32, c.ast.getNodeNumValue(node)),
            });
            return;
        },
        .nd_negation => {
            try c.addCil(Cil{
                .tag = .cil_push_imm,
                .lhs = 0,
            });

            const extra = c.ast.getNodeExtra(node, Node.Data);
            try c.gen(extra.lhs);
            try c.addCil(Cil{
                .tag = .cil_sub,
            });
            return;
        },
        .nd_logic_and => {
            const l_false = c.getLabelNo();
            const l_end = c.getLabelNo();

            const extra = c.ast.getNodeExtra(node, Node.Data);
            
            // eval lhs
            try c.gen(extra.lhs);
            try c.addCil(Cil{
                .tag = .cil_jz,
                .lhs = l_false,
            });

            // eval rhs
            try c.gen(extra.rhs);
            try c.addCil(Cil{
                .tag = .cil_jz,
                .lhs = l_false,
            });

            // write result
            try c.addCil(Cil{
                .tag = .cil_push_imm,
                .lhs = 1,
            });
            try c.addCil(Cil{
                .tag = .cil_jmp,
                .lhs = l_end,
            });
            try c.addCil(Cil{
                .tag = .cil_label,
                .lhs = l_false,
            });
            try c.addCil(Cil{
                .tag = .cil_push_imm,
                .lhs = 0,
            });
            try c.addCil(Cil{
                .tag = .cil_label,
                .lhs = l_end,
            });
            return;
        },
        else => { },
    }

    const extra = c.ast.getNodeExtra(node, Node.Data);
    try c.gen(extra.lhs);
    try c.gen(extra.rhs);

    switch(c.ast.getNodeTag(node)){
        Node.Tag.nd_add => {
            try c.addCil(Cil{
                .tag = .cil_add,
            });
        },
        Node.Tag.nd_sub => {
            try c.addCil(Cil{
                .tag = .cil_sub,
            });
        },
        Node.Tag.nd_mul => {
            try c.addCil(Cil{
                .tag = .cil_mul,
            });
        },
        Node.Tag.nd_div => {
            try c.addCil(Cil{
                .tag = .cil_div,
            });
        },
        Node.Tag.nd_equal => {
            try c.addCil(Cil{.tag = .cil_equal});
        },
        Node.Tag.nd_not_equal => {
            try c.addCil(Cil{.tag = .cil_not_equal});
        },
        Node.Tag.nd_gt => {
            try c.addCil(Cil{.tag = .cil_gt});
        },
        Node.Tag.nd_ge => {
            try c.addCil(Cil{.tag = .cil_ge});
        },
        Node.Tag.nd_bit_and => {
            try c.addCil(Cil{.tag = .cil_bit_and});
        },
        Node.Tag.nd_bit_xor => {
            try c.addCil(Cil{.tag = .cil_bit_xor});
        },
        Node.Tag.nd_bit_or => {
            try c.addCil(Cil{.tag = .cil_bit_or});
        },
        else => {},
    }
}

pub const Cil = struct{
    pub const Tag = enum {
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
        cil_jmp,
            // jmp to lhs
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