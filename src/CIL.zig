
ast: Ast = undefined,


pub fn generate(ast: Ast) !Cil {

    return Cil {
        .ast = ast,
    };
}

pub const IL = struct{
    pub const Tag = enum {
        il_push_imm,
            // push immidiate
        il_add,
            // add lhs, rhs
        il_sub,
            // sub lhs, rhs
        il_return,
            // return
    };

    pub const register = struct {
        pub const Type = enum {
            local,
            global,
            immidiate,
        };

        tag: Tag,
        data: u32,
    };
    tag: Tag,
    lhs: register,
    rhs: register,
};

const std = @import("std");
const Cil = @This();
const Ast = @import("./AST.zig");

const Allocator = std.mem.Allocator;
