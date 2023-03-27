pub const Parser = @This();
pub const Error = TokenError || Allocator.Error;

gpa: Allocator,
source: [:0] const u8,
tokens: TokenList = undefined,
tkidx: usize,                       // index of TokenList.
nodes: NodeList = undefined,
extras: ExtraDataList = undefined,
root: usize = 0,

pub fn deinit(p: *Parser) void {
    p.tokens.deinit(p.gpa);
    p.nodes.deinit(p.gpa);
    p.extras.deinit();
    p.* = undefined;
}

fn currentTokenTag(p: *Parser) Token.Tag {
    return p.tokens.items(.tag)[p.tkidx];
}

fn expectToken(p: *Parser, tag: Token.Tag) !void{
    if(p.currentTokenTag() != tag){
        return TokenError.UnexpectedToken;
    }
    _ = p.nextToken();
    return;
}

fn nextToken(self: *Parser) usize {
    const result = self.tkidx;
    self.tkidx += 1;
    return result;
}


fn addNode(p:*Parser, node: Node) !usize {
    const idx = p.nodes.len;
    try p.nodes.append(p.gpa, node);
    return idx;
}

fn addExtra(p: *Parser, extra: anytype) Allocator.Error!usize {
    const fields = std.meta.fields(@TypeOf(extra));
    try p.extras.ensureUnusedCapacity(fields.len);

    const result = @intCast(u32, p.extras.items.len);
    inline for(fields) | field | {
        p.extras.appendAssumeCapacity(@field(extra, field.name));
    }
    return result;
}

fn addExtraList(p: *Parser, list: []const usize) !Node.Range {
    try p.extras.appendSlice(list);
    return Node.Range {
        .start = p.extras.items.len - list.len,
        .end = p.extras.items.len,
    };
}

// program = stmt*
// stmt = expr ";" |
//          "return" expr ";"
// expr = logicOr
// logicOr = logicAnd ("||" logicAnd)*
// logicAnd = bitOr ("&&" bitOr)*
// bitOr = bitXor ("|" bitXor)*
// bitXor = bitAnd ( "^" bitAnd )*
// bitAnd = equality ( '&' equality )*
// equality = relational ("==" relational | "!=" relational )*
// relational = add ("<" add | "<=" add | ">" add | ">=" add)*
// add = multiple ( '+' multiple | `-` multiple )*
// multiple = unary ( '*' unary | `/` unary )*
// unary = ( "+" | "-" )? primary
// primary = num | ident | '(' expr ')`

pub fn parse(p: *Parser) void {
    p.root = p.parseProgram() catch unreachable;
}

fn parseProgram(p: *Parser) Error!usize {
    var stmts = std.ArrayList(usize).init(p.gpa);
    defer stmts.deinit();

    while (p.currentTokenTag() != .tk_eof) {
        try stmts.append(try p.parseStmt());
    }
    const rng = try p.addExtraList(try stmts.toOwnedSlice());
    const root = try p.addNode(.{
        .tag = .nd_program,
        .main_token = 0,
        .data = try p.addExtra(rng),
    });

    return root;
}

fn parseStmt(p: *Parser) !usize {
    return switch(p.currentTokenTag()){
        .tk_return => try p.parseReturnStatement(),
        else => {
            const lhs = try p.parseExpr();
            try p.expectToken(.tk_semicoron);
            return lhs;
        },
    };
}

fn parseReturnStatement(p: *Parser) !usize {
    const lhs = try p.addNode(.{
        .tag = .nd_return,
        .main_token = p.nextToken(),
        .data = try p.addExtra(Node.Data{
            .lhs = try p.parseExpr(),
            .rhs = 0,
        }),
    });
    try p.expectToken(.tk_semicoron);
    return lhs;
}

fn parseExpr(p: *Parser) !usize {
    return try p.parseLogicOr();
}

fn parseLogicOr(p: *Parser) !usize {
    var lhs = try p.parseLogicAnd();

    while(true){
        if(p.currentTokenTag() == .tk_pipe_pipe){
            lhs = try p.addNode(.{
                .tag = .nd_logic_or,
                .main_token = p.nextToken(),
                .data = try p.addExtra(Node.Data{
                    .lhs = lhs,
                    .rhs = try p.parseLogicAnd(),
                }),
            });
        } else {
            return lhs;
        }
    }
}

fn parseLogicAnd(p: *Parser) !usize {
    var lhs = try p.parsebitOr();

    while(true){
        if(p.currentTokenTag() == .tk_and_and){
            lhs = try p.addNode(.{
                .tag = .nd_logic_and,
                .main_token = p.nextToken(),
                .data = try p.addExtra(Node.Data{
                    .lhs = lhs,
                    .rhs = try p.parsebitOr(),
                }),
            });
        } else {
            return lhs;
        }
    }
}

fn parsebitOr(p: *Parser) !usize {
    var lhs = try p.parsebitXor();

    while(true){
        if(p.currentTokenTag() == .tk_pipe){
            lhs = try p.addNode(.{
                .tag = .nd_bit_or,
                .main_token = p.nextToken(),
                .data = try p.addExtra(Node.Data{
                    .lhs = lhs,
                    .rhs = try p.parsebitXor(),
                }),
            });
        } else {
            return lhs;
        }
    }
}

fn parsebitXor(p: *Parser) !usize {
    var lhs = try p.parsebitAnd();

    while(true){
        if(p.currentTokenTag() == .tk_hat){
            lhs = try p.addNode(.{
                .tag = .nd_bit_xor,
                .main_token = p.nextToken(),
                .data = try p.addExtra(Node.Data{
                    .lhs = lhs,
                    .rhs = try p.parsebitAnd(),
                }),
            });
        } else {
            return lhs;
        }
    }
}

fn parsebitAnd(p: *Parser) !usize {
    var lhs = try p.parseEquality();

    while(true){
        if(p.currentTokenTag() == .tk_and){
            lhs = try p.addNode(.{
                .tag = .nd_bit_and,
                .main_token = p.nextToken(),
                .data = try p.addExtra(Node.Data{
                    .lhs = lhs,
                    .rhs = try p.parseEquality(),
                }),
            });
        } else {
            return lhs;
        }
    }
}

fn parseEquality(p: *Parser) !usize {
    var lhs = try p.parseRelational();

    while(true){
        switch(p.currentTokenTag()){
            .tk_equal => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_equal,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseRelational(),
                    }),
                });
            },
            .tk_not_equal =>{
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_not_equal,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseRelational(),
                    }),
                });
            },
            else => { return lhs; },
        }
    }
}

fn parseRelational(p: *Parser) !usize {
    var lhs = try p.parseAdd();

    while(true){
        switch(p.currentTokenTag()){
            .tk_l_angle_bracket => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_gt,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseAdd(),
                    }),
                });
            },
            .tk_l_angle_bracket_equal => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_ge,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseAdd(),
                    }),
                });
            },
            .tk_r_angle_bracket => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_gt,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = try p.parseAdd(),
                        .rhs = lhs,
                    }),
                });
            },
            .tk_r_angle_bracket_equal => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_ge,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = try p.parseAdd(),
                        .rhs = lhs,
                    }),
                });
            },
            else => { return lhs; },
        }
    }
}

fn parseAdd(p: *Parser) !usize {
    var lhs = try p.parseMultiple();

    while(true) {
        switch(p.currentTokenTag()){
            Token.Tag.tk_add => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_add,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseMultiple(),
                    }),
                });
            },
            Token.Tag.tk_sub => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_sub,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseMultiple(),
                    }),
                });
            },
            else => {
                return lhs;
            },
        }
    }
}

fn parseMultiple(p: *Parser) !usize {
    var lhs = try p.parseUnary();

    while(true){
        switch(p.currentTokenTag()){
            .tk_mul => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_mul,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseUnary(),
                    }),
                });
            },
            .tk_div => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_div,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parseUnary(),
                    }),
                });
            },
            else => { return lhs; },
        }
    }
}

fn parseUnary(p: *Parser) Error!usize {
    switch(p.currentTokenTag()){
        .tk_add => {
            _ = p.nextToken();
            return try p.parsePrimary();
        },
        .tk_sub => {
            return p.addNode(.{
                .tag = .nd_negation,
                .main_token = p.nextToken(),
                .data = try p.addExtra(Node.Data{
                    .lhs = try p.parsePrimary(),
                    .rhs = 0,
                }),
            });
        },
        else => {
            return try p.parsePrimary();
        },
    }
}

fn parsePrimary(p: *Parser) Error!usize {
    
    switch(p.currentTokenTag()){
        .tk_num => {
            return try p.addNode(.{
                .tag = .nd_num,
                .main_token = p.nextToken(),
                .data = 0,
            });
        },
        .tk_l_paren => {
            _ = p.nextToken();
            const node = p.parseExpr();
            try p.expectToken(Token.Tag.tk_r_paren);
            return node;
        },
        .tk_identifier => {
            return try p.addNode(.{
                .tag = .nd_lvar,
                .main_token = p.nextToken(),
                .data = 0,
            });
        },
        else => {
            return TokenError.UnexpectedToken;
        },
    }
}

const std = @import("std");
const Ast = @import("./AST.zig");
const Tokenizer = @import("./tokenizer.zig");
const Allocator = std.mem.Allocator;
const Node = Ast.Node;
const Token = Tokenizer.Token;
const TokenList = Ast.TokenList;
const NodeList = Ast.NodeList;
const ExtraDataList = Ast.ExtraDataList;

const TokenError = Tokenizer.TokenError;

test "Parser test" {
}
