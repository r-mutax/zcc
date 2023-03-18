pub const Parser = @This();

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
    try p.extras.appendSlice(p.gpa, list);
    return Node.Range {
        .start = p.extras.items.len - list.len,
        .end = p.extras.items.len,
    };
}

pub fn parse(p: *Parser) void {
    p.root = p.parseProgram() catch unreachable;
}

fn parseProgram(p: *Parser) !usize {
    return try p.parseAdd();
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
            }
        }
    }
}

fn parseMultiple(p: *Parser) !usize {
    var lhs = try p.parsePrimary();

    while(true){
        switch(p.currentTokenTag()){
            .tk_mul => {
                lhs = try p.addNode(.{
                    .tag = Node.Tag.nd_mul,
                    .main_token = p.nextToken(),
                    .data = try p.addExtra(Node.Data{
                        .lhs = lhs,
                        .rhs = try p.parsePrimary(),
                    }),
                });
            },
            else => { return lhs; }
        }
    }
}

fn parsePrimary(p: *Parser) !usize {
    if(p.currentTokenTag() != Token.Tag.tk_num){
        return TokenError.UnexpectedToken;
    }

    return try p.addNode(.{
        .tag = .nd_num,
        .main_token = p.nextToken(),
        .data = 0,
    });
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
