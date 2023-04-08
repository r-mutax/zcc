// CIlGen is C Intermediate Language.

pub const CilList = std.MultiArrayList(CilGen.Cil);
pub const IdentList = std.MultiArrayList(CilGen.Ident);
pub const ScopeList = std.MultiArrayList(CilGen.Scope);

ast: Ast = undefined,
gpa: Allocator,
cils: CilList = undefined,
cilidx: usize = 0,
label: u32 = 0,
idents: IdentList = undefined,
scopes: ScopeList = undefined,
scpidx: usize = 0,
memory: u32 = 0,

pub fn init(ast: Ast, gpa: Allocator) !CilGen {
    return CilGen{
        .ast = ast,
        .gpa = gpa,
    };
}

pub fn deinit(c: *CilGen) void {
    c.cils.deinit(c.gpa);
}

pub fn generate(c: *CilGen) !void {
    c.cils = CilList{};
    c.idents = IdentList{};
    c.scopes = ScopeList{};

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

fn addCil(c: *CilGen, tag: Cil.Tag, lhs: u32, rhs: u32, size: usize) !void {
    try c.cils.append(c.gpa, Cil{
        .tag = tag,
        .lhs = lhs,
        .rhs = rhs,
        .size = size,
    });
}

fn getLabelNo(c: *CilGen) u32 {
    const result = c.label;
    c.label += 1;
    return result;
}

fn startScope(c: *CilGen) !void {
    c.scpidx = c.scopes.len;
    try c.scopes.append(c.gpa, .{
        .identmap = IdentMap.init(c.gpa),
    });
}

fn endScope(c: *CilGen) !void {
    _ = c.scopes.pop();
    c.scpidx -= 1;
}

fn searchIdent(c: *CilGen, ident: []const u8) !Ident {
    var idx: usize = 0;
    while (idx <= c.scpidx) : (idx += 1) {
        var scope = c.scopes.get(c.scpidx - idx);
        const i = scope.identmap.get(ident);
        if (i) |p| {
            const result = c.idents.get(p);
            return result;
        }
    }

    // not found ident
    c.memory += 8;
    const pos = c.idents.len;
    try c.idents.append(c.gpa, .{
        .tag = .local,
        .size = 8,
        .offset = c.memory,
    });
    var scope = c.scopes.get(c.scpidx);
    try scope.identmap.put(ident, pos);
    c.scopes.set(c.scpidx, scope);

    return c.idents.get(pos);
}

pub fn getIdent(c: *CilGen, ino: usize) !Ident {
    return c.idents.get(ino);
}

pub fn getMemorySize(c: *CilGen) u32 {
    return c.memory;
}

pub fn appendIdent(c: *CilGen, ident: []const u8, data: Ident) !usize {
    const pos = c.idents.len;
    try c.idents.append(c.gpa, data);
    if (data.tag != .func) {
        c.memory += data.size;
    }
    try c.scopes.items(.identmap)[c.scpidx].put(ident, pos);
    return pos;
}

fn gen_program(c: *CilGen, node: usize) !void {
    try c.startScope();
    const extra = c.ast.getNodeExtra(node, Node.Range);
    const rng = c.ast.getNodeExtraList(extra.start, extra.end);
    for (rng) |idx| {
        try c.gen_function(idx);
        try c.addCil(.cil_pop, @enumToInt(CilRegister.rax), 0, 0);
    }
}

fn gen_function(c: *CilGen, node: usize) !void {
    c.memory = 0;

    const pos = c.cils.len;
    try c.addCil(.cil_fn_start, @intCast(u32, node), c.memory, 0);

    try c.startScope();

    // argument parse
    const extra = c.ast.getNodeExtra(node, Node.Function);
    if (extra.args_s != extra.args_e) {
        const rng = c.ast.getNodeExtraList(extra.args_s, extra.args_e);
        var i: u32 = 0;
        for (rng) |r| {
            const ident = c.ast.getNodeToken(r);
            _ = try c.appendIdent(ident, Ident{
                .tag = .local,
                .size = 8,
                .offset = c.memory + 8,
            });
            try c.addCil(.cil_store_arg, i + 1, c.memory, 0);
            i += 1;
        }
    }

    try c.gen_stmt(extra.body);
    try c.endScope();

    c.cils.items(.rhs)[pos] = c.memory;
    try c.addCil(.cil_fn_end, 0, 0, 0);
}

fn gen_stmt(c: *CilGen, node: usize) !void {
    switch (c.ast.getNodeTag(node)) {
        .nd_return => {
            const extra = c.ast.getNodeExtra(node, Node.Data);
            try c.gen(extra.lhs);
            try c.addCil(.cil_return, 0, 0, 0);
        },
        .nd_if => {
            const extra = c.ast.getNodeExtra(node, Node.If);

            const l_end = c.getLabelNo();
            try c.gen(extra.cond_expr);
            try c.addCil(.cil_jz, l_end, 0, 0);
            try c.gen_stmt(extra.then_stmt);
            try c.addCil(.cil_label, l_end, 0, 0);
        },
        .nd_if_else => {
            const extra = c.ast.getNodeExtra(node, Node.IfElse);

            const l_else = c.getLabelNo();
            const l_end = c.getLabelNo();

            try c.gen(extra.cond_expr);
            try c.addCil(.cil_jz, l_else, 0, 0);
            try c.gen_stmt(extra.then_stmt);
            try c.addCil(.cil_jmp, l_end, 0, 0);

            try c.addCil(.cil_label, l_else, 0, 0);
            try c.gen_stmt(extra.else_stmt);
            try c.addCil(.cil_label, l_end, 0, 0);
        },
        .nd_while => {
            const extra = c.ast.getNodeExtra(node, Node.While);

            const l_start = c.getLabelNo();
            const l_end = c.getLabelNo();

            try c.addCil(.cil_label, l_start, 0, 0);
            try c.gen(extra.cond_expr);
            try c.addCil(.cil_jz, l_end, 0, 0);
            try c.gen(extra.body_stmt);
            try c.addCil(.cil_jmp, l_start, 0, 0);
            try c.addCil(.cil_label, l_end, 0, 0);
        },
        .nd_for => {
            const extra = c.ast.getNodeExtra(node, Node.For);

            const l_start = c.getLabelNo();
            const l_end = c.getLabelNo();

            try c.gen(extra.init_expr);
            try c.addCil(.cil_label, l_start, 0, 0);
            try c.gen(extra.cond_expr);
            try c.addCil(.cil_jz, l_end, 0, 0);
            try c.gen(extra.body_stmt);
            try c.gen(extra.itr_expr);
            try c.addCil(.cil_jmp, l_start, 0, 0);
            try c.addCil(.cil_label, l_end, 0, 0);
        },
        .nd_block => {
            const extra = c.ast.getNodeExtra(node, Node.Range);
            const rng = c.ast.getNodeExtraList(extra.start, extra.end);
            try c.startScope();
            for (rng) |idx| {
                try c.gen_stmt(idx);
                try c.addCil(.cil_pop, @enumToInt(CilRegister.rax), 0, 0);
            }
            try c.endScope();
        },
        .nd_blank_stmt => {
            return;
        },
        else => try c.gen(node),
    }
}

fn gen(c: *CilGen, node: usize) !void {
    switch (c.ast.getNodeTag(node)) {
        .nd_num => {
            try c.addCil(.cil_push_imm, @intCast(u32, c.ast.getNodeNumValue(node)), 0, 0);
            return;
        },
        .nd_lvar => {
            const ident = c.ast.getNodeToken(node);
            const i = try c.searchIdent(ident);
            try c.addCil(.cil_load_lvar, @intCast(u32, i.offset), 0, @intCast(u32, i.size));
            return;
        },
        .nd_address => {
            const extra = c.ast.getNodeExtra(node, Node.Data);
            const target = extra.lhs;
            const ident = c.ast.getNodeToken(target);
            const i = try c.searchIdent(ident);

            try c.addCil(.cil_store_lvar_addr, @intCast(u32, i.offset), 0, @intCast(u32, i.size));
            return;
        },
        .nd_call_function => {
            try c.addCil(.cil_fn_call_noargs, @intCast(u32, node), 0, 0);
            return;
        },
        .nd_call_fn_with_params => {
            const extra = c.ast.getNodeExtra(node, Node.Range);

            // push to stack paramater expr
            const rng = c.ast.getNodeExtraList(extra.start, extra.end);
            for (rng) |idx| {
                try c.gen(idx);
            }

            // stack to argument
            for (rng, 0..) |_, idx| {
                try c.addCil(.cil_pop, @intCast(u32, rng.len - idx), 0, 8);
            }

            try c.addCil(.cil_fn_call_noargs, @intCast(u32, node), 0, 0);
            return;
        },
        .nd_assign => {
            const extra = c.ast.getNodeExtra(node, Node.Data);
            try c.gen(extra.rhs);

            const ident = c.ast.getNodeToken(extra.lhs);
            const i = try c.searchIdent(ident);

            try c.addCil(.cil_store_lvar, @intCast(u32, i.offset), @intCast(u32, i.size), 0);
            return;
        },
        .nd_negation => {
            try c.addCil(.cil_push_imm, 0, 0, 0);

            const extra = c.ast.getNodeExtra(node, Node.Data);
            try c.gen(extra.lhs);
            try c.addCil(.cil_sub, 0, 0, 0);
            return;
        },
        .nd_logic_and => {
            const l_false = c.getLabelNo();
            const l_end = c.getLabelNo();

            const extra = c.ast.getNodeExtra(node, Node.Data);

            // eval lhs
            try c.gen(extra.lhs);
            try c.addCil(.cil_jz, l_false, 0, 0);

            // eval rhs
            try c.gen(extra.rhs);
            try c.addCil(.cil_jz, l_false, 0, 0);

            // write result
            try c.addCil(.cil_push_imm, 1, 0, 0);
            try c.addCil(.cil_jmp, l_end, 0, 0);
            try c.addCil(.cil_label, l_false, 0, 0);
            try c.addCil(.cil_push_imm, 0, 0, 0);
            try c.addCil(.cil_label, l_end, 0, 0);
            return;
        },
        .nd_logic_or => {
            const l_true = c.getLabelNo();
            const l_end = c.getLabelNo();

            const extra = c.ast.getNodeExtra(node, Node.Data);

            // eval lhs
            try c.gen(extra.lhs);
            try c.addCil(.cil_jnz, l_true, 0, 0);

            // eval rhs
            try c.gen(extra.rhs);
            try c.addCil(.cil_jnz, l_true, 0, 0);

            // write result
            try c.addCil(.cil_push_imm, 0, 0, 0);
            try c.addCil(.cil_jmp, l_end, 0, 0);
            try c.addCil(.cil_label, l_true, 0, 0);
            try c.addCil(.cil_push_imm, 1, 0, 0);
            try c.addCil(.cil_label, l_end, 0, 0);
            return;
        },
        else => {},
    }

    const extra = c.ast.getNodeExtra(node, Node.Data);
    try c.gen(extra.lhs);
    try c.gen(extra.rhs);

    switch (c.ast.getNodeTag(node)) {
        Node.Tag.nd_add => {
            try c.addCil(.cil_add, 0, 0, 0);
        },
        Node.Tag.nd_sub => {
            try c.addCil(.cil_sub, 0, 0, 0);
        },
        Node.Tag.nd_mul => {
            try c.addCil(.cil_mul, 0, 0, 0);
        },
        Node.Tag.nd_div => {
            try c.addCil(.cil_div, 0, 0, 0);
        },
        Node.Tag.nd_equal => {
            try c.addCil(.cil_equal, 0, 0, 0);
        },
        Node.Tag.nd_not_equal => {
            try c.addCil(.cil_not_equal, 0, 0, 0);
        },
        Node.Tag.nd_gt => {
            try c.addCil(.cil_gt, 0, 0, 0);
        },
        Node.Tag.nd_ge => {
            try c.addCil(.cil_ge, 0, 0, 0);
        },
        Node.Tag.nd_bit_and => {
            try c.addCil(.cil_bit_and, 0, 0, 0);
        },
        Node.Tag.nd_bit_xor => {
            try c.addCil(.cil_bit_xor, 0, 0, 0);
        },
        Node.Tag.nd_bit_or => {
            try c.addCil(.cil_bit_or, 0, 0, 0);
        },
        else => {},
    }
}

pub const CilRegister = enum(u32) { rax, rdi, rsi, rdx, rcx, r8, r9 };

pub const Cil = struct {
    pub const Tag = enum {
        cil_pop,
        // pop
        //  to register...
        //      lhs : 0  rax
        //            1  rdi
        //            2  rsi
        //            3  rdx
        //            4  rcx
        //            5  r8
        //            6  r9

        cil_push,
        // push register...
        //      lhs : 0  rax
        //            1  rdi
        //            2  rsi
        //            3  rdx
        //            4  rcx
        //            5  r8
        //            6  r9

        cil_store_arg,
        // lhs : argno, rhs : offset

        cil_load_lvar,
        // load to stack lvar
        // lhs : offset
        // rhs : size

        cil_store_lvar,
        // store to lvar from stack
        // lhs : offset
        // rhs : size

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

        cil_jz,
        // if stack top is 0, then jamp to lhs

        cil_jnz,
        // if stack top is none zero, then jamp to lhs

        cil_jmp,
        // jmp to lhs

        cil_return,
        // return stack top value

        cil_label,
        // file scope label

        cil_fn_start,
        cil_fn_end,
        // identify label(lhs = token idx)

        cil_fn_call_noargs,
        // calling function(lhs = token idx of func name)

        cil_store_lvar_addr,
        // store local variable address

    };

    tag: Tag,
    lhs: u32 = undefined,
    rhs: u32 = undefined,
    size: usize = 0,
};

pub const Ident = struct {
    pub const Tag = enum {
        local,
        func,
    };
    tag: Tag,
    size: u32,
    offset: u32,
};

pub const Scope = struct {
    identmap: IdentMap,
};

const std = @import("std");
const CilGen = @This();
const Ast = @import("./AST.zig");
const Node = Ast.Node;
const IdentMap = std.StringHashMap(usize);

const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();

test "Code gen" {
    _ = try stdout.writeAll("\n");

    var ast = try Ast.parse("0", std.heap.page_allocator);
    _ = try stdout.print("{}\n", .{ast.getNodeTag(ast.root)});

    var cil = try CilGen.init(ast, std.heap.page_allocator);
    try cil.generate();

    for (cil.cils.items(.tag)) |a| {
        _ = try stdout.print("{}\n", .{a});
    }
}
