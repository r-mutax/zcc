const Ast = @This();

pub const NodeList = std.MultiArrayList(Ast.Node);
pub const ExtraDataList = std.ArrayList(usize);

pub const TokenList = std.MultiArrayList(struct {
    tag: Tokenizer.Token.Tag,
    start: usize,
});

source: [:0]const u8,
tokens: TokenList.Slice,
nodes: NodeList.Slice,
extras: ExtraDataList.Slice,
root: usize,

pub fn deinit(ast: *Ast, gpa: Allocator) void {
    ast.tokens.deinit(gpa);
    ast.nodes.deinit(gpa);
    gpa.free(ast.extra_data);
    ast.* = undefined;
}

pub fn parse(source: [:0]const u8, gpa: Allocator) !Ast {
    var tokens = Ast.TokenList{};
    defer tokens.deinit(gpa);

    const tokenizer = Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(gpa, .{
            .tag = token.tag,
            .start = @intCast(u32, token.loc.start),
        });
        if (token.tag == .tk_eof) break;
    }

    var parser = Parser{
        .source = source,
        .tokens = tokens,
        .tkidx = 0,
        .nodes = NodeList{},
        .extras = ExtraDataList{},
    };
    defer parser.deinit();
    
    parser.parse();

    return Ast {
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extras = parser.extras.toOwnedSlice(),
    };
}

pub const Node = struct {
    tag: Tag,
    main_token: usize,
    data: usize,

    const Data = struct {
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
        nd_then_else,
            // if statement and then block and else block
        nd_while,
            // while statement
        nd_for,
            // for statement
        nd_block,
            // block statement
        nd_call_function_noargs,
            // function call
        nd_call_function_have_args,
            // function call with argument
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
    };
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const Tokenizer = @import("./tokenizer.zig");
const Parser = @import("./parser.zig");
