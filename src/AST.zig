const Ast = @This();

pub const NodeList = std.MultiArrayList(Ast.Node);
pub const ExtraDataList = std.ArrayList(usize);

pub const TokenList = std.MultiArrayList(struct {
    tag: Tokenizer.Token.Tag,
    start: usize,
});

gpa: Allocator,
source: [:0]const u8,
tokens: TokenList.Slice,
nodes: NodeList.Slice,
extras: ExtraDataList.Slice,
root: usize = 0,

pub fn deinit(ast: *Ast) void {
    ast.tokens.deinit(ast.gpa);
    ast.nodes.deinit(ast.gpa);
    ast.gpa.free(ast.extras);
    ast.* = undefined;
}

pub fn parse(source: [:0]const u8, gpa: Allocator) !Ast {
    var tokens = Ast.TokenList{};
    //defer tokens.deinit(gpa);

    var tokenizer = Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(gpa, .{
            .tag = token.tag,
            .start = @intCast(u32, token.loc.start),
        });
        if (token.tag == .tk_eof) break;
    }

    var parser = Parser{
        .gpa = gpa,
        .source = source,
        .tokens = tokens,
        .tkidx = 0,
        .nodes = NodeList{},
        .extras = ExtraDataList.init(gpa),
    };
    //defer parser.deinit();

    parser.parse();

    return Ast{
        .gpa = gpa,
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extras = try parser.extras.toOwnedSlice(),
        .root = parser.root,
    };
}

pub fn getNodeToken(ast: *Ast, idx: usize) []const u8 {
    const main_token = ast.nodes.items(.main_token)[idx];
    const tkidx = ast.tokens.items(.start)[main_token];
    var tokenizer = Tokenizer.init(ast.source);

    return tokenizer.getSlice(tkidx);
}

pub fn getNodeTag(ast: *Ast, idx: usize) Node.Tag {
    return ast.nodes.items(.tag)[idx];
}

pub fn getNodeNumValue(ast: *Ast, idx: usize) usize {
    const main_token = ast.nodes.items(.main_token)[idx];
    const tkidx = ast.tokens.items(.start)[main_token];
    var tokenizer = Tokenizer.init(ast.source);

    return tokenizer.getNumValue(tkidx);
}

pub fn getNodeExtra(ast: *Ast, idx: usize, comptime T: type) T {
    const extra_idx = ast.nodes.items(.data)[idx];
    const fields = std.meta.fields(T);
    var result: T = undefined;
    inline for (fields, 0..) |field, i| {
        @field(result, field.name) = ast.extras[extra_idx + i];
    }
    return result;
}

pub fn getNodeExtraList(ast: *Ast, st: usize, en: usize) []const usize {
    const result = ast.extras[st..en];
    return result;
}

pub const Node = struct {
    tag: Tag,
    main_token: usize,
    data: usize,

    pub const Data = struct {
        lhs: usize,
        rhs: usize,
    };

    pub const Tag = enum {
        nd_program,
        //
        nd_fn_proto,

        nd_add,
        // lhs + rhs
        nd_sub,
        // lhs - rhs
        nd_mul,
        // lhs * rhs
        nd_div,
        // lhs / rhs
        nd_num,
        // lhs
        nd_equal,
        // lhs == rhs
        nd_not_equal,
        // lhs != rhs
        nd_gt,
        // lhs < rhs
        nd_ge,
        // lhs <= rhs
        nd_assign,
        // lhs = rhs
        nd_lvar,
        // local variable
        nd_return,
        // return statement
        nd_if_simple,
        // if statement
        nd_if,
        nd_if_else,
        // if statement and then block and else block
        nd_while,
        // while statement
        nd_for,
        // for statement
        nd_block,
        // block statement
        nd_call_function,
        // function call
        nd_call_fn_with_params,
        nd_args,
        // function arguments
        nd_bit_and,
        // bitand
        nd_bit_xor,
        // bit-xor
        nd_bit_or,
        // bit-or
        nd_logic_and,
        // logic and
        nd_logic_or,
        // logic or
        nd_cond_expr,
        // condition expression
        nd_address,
        // address
        nd_dreference,
        // pointer dereference
        nd_negation,
        // '-' primary
    };

    pub const Range = struct {
        start: usize,
        end: usize,
    };

    pub const Program = struct {
        func_st: usize,
        func_end: usize,
    };

    pub const Function = struct {
        body: usize,
        args_s: usize,
        args_e: usize,
    };

    pub const If = struct {
        cond_expr: usize,
        then_stmt: usize,
    };

    pub const IfElse = struct {
        cond_expr: usize,
        then_stmt: usize,
        else_stmt: usize,
    };

    pub const While = struct {
        cond_expr: usize,
        body_stmt: usize,
    };

    pub const For = struct {
        init_expr: usize,
        cond_expr: usize,
        itr_expr: usize,
        body_stmt: usize,
    };
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const Tokenizer = @import("./tokenizer.zig");
const Parser = @import("./parser.zig");
