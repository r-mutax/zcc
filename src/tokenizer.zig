const std = @import("std");
const Tokenizer = @This();

const expect = std.testing.expect;

pub const TokenError = error {
    UnexpectedToken,
};

pub const Token = struct {
    pub const Tag = enum {
        tk_add,                     // +
        tk_sub,                     // -
        tk_mul,                     // *
        tk_div,                     // /
        tk_num,
        tk_eof,
        tk_invalid,
        tk_l_paren,                 // (
        tk_r_paren,                 // )
        tk_incr,                    // ++
        tk_decr,                    // --
        tk_equal,                   // ==
        tk_assign,                  // =
        tk_not_equal,               // !=
        tk_l_angle_bracket,         // <
        tk_l_angle_bracket_equal,   // <=
        tk_r_angle_bracket,         // >
        tk_r_angle_bracket_equal,   // >=
        tk_l_brace,                 // {
        tk_r_brace,                 // }
        tk_identifier, 
        tk_semicoron,               // ;
        tk_return,                  // return
        tk_if,                      // if
        tk_else,                    // else
        tk_while,                   // while
        tk_for,                     // for
        tk_canma,                   // ,
        tk_and,                     // &
        tk_and_and,                 // &&
        tk_pipe,                    // |
        tk_pipe_pipe,               // ||
        tk_hat,                     // ~
        tk_question,                // ?
        tk_coron,                   // :
    };
    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Token.Tag, .{
        .{ "return", .tk_return },
        .{ "if", .tk_if },
        .{ "else", .tk_else },
        .{ "while", .tk_while },
        .{ "for", .tk_for },
    });

    fn getKeywords(keyword: [] const u8) ?Token.Tag {
        return keywords.get(keyword);
    }

    tag: Tag,
    loc: Loc,
};

buffer: [:0] const u8,
index: usize,

pub fn init(buffer: [:0]const u8) Tokenizer {
    return Tokenizer {
        .buffer = buffer,
        .index = 0,
    };
}

const State = enum {
    start,
    plus,
    minus,
    multiple,
    division,
    int,
    l_paren,
    r_paren,
    l_brace,
    r_brace,
    equal,
    exclamation,
    l_angle_bracket,
    r_angle_bracket,
    identifier,
    semicoron,
    canma,
    ampersand,
    pipe,
    hat,
    question,
    coron,
};

pub fn next(self: *Tokenizer) Token {
    var result = Token{
        .tag = .tk_eof,
        .loc = .{
            .start = self.index,
            .end = undefined,
        },
    };

    var state : State = .start;
    while(true) : (self.index += 1){
        const c = self.buffer[self.index];
        switch(state) {
            .start => switch(c){
                0 => {
                    break;
                },
                ' ', '\n', '\t', '\r' => {
                    result.loc.start = self.index + 1;
                },
                '+' => {
                    state = .plus;
                },
                '-' => {
                    state = .minus;
                },
                '*' => {
                    state = .multiple;
                },
                '/' => {
                    state = .division;
                },
                '(' => {
                    state = .l_paren;
                },
                ')' => {
                    state = .r_paren;
                },
                '{' => {
                    state = .l_brace;
                },
                '}' => {
                    state = .r_brace;
                },
                '=' => {
                    state = .equal;
                },
                '!' => {
                    state = .exclamation;
                },
                '<' => {
                    state = .l_angle_bracket;
                },
                '>' => {
                    state = .r_angle_bracket;
                },
                ';' => {
                    state = .semicoron;
                },
                ',' => {
                    state = .canma;
                },
                '&' => {
                    state = .ampersand;
                },
                '|' => {
                    state = .pipe;
                },
                '^' => {
                    state = .hat;
                },
                ':' => {
                    state = .coron;
                },
                '?' => {
                    state = .question;
                },
                '0'...'9' => {
                    state = .int;
                    result.tag = .tk_num;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    state = .identifier;
                    result.tag = .tk_identifier;
                },
                else => {
                    result.tag = .tk_invalid;
                    result.loc.end = self.index;
                    self.index += 1;
                    return result;
                },
            },
            .identifier => {
                switch(c) {
                    'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                    else => {
                        if(Token.getKeywords(self.buffer[result.loc.start..self.index])) |tag| {
                            result.tag = tag;
                        }
                        break;
                    }
                }
            },
            .plus => {
                switch(c){
                    '+' => {
                        result.tag = .tk_incr;
                    },
                    else => {
                        result.tag = .tk_add;
                    }
                }
                break;
            },
            .minus => {
                switch(c){
                    '+' => {
                        result.tag = .tk_decr;
                    },
                    else => {
                        result.tag = .tk_sub;
                    }
                }
                break;
            },
            .multiple => {
                result.tag = .tk_mul;
                break;
            },
            .division => {
                result.tag = .tk_div;
                break;
            },
            .int => {
                switch(c){
                    '0' ... '9' => {},
                    else => break,
                }
            },
            .l_paren => {
                result.tag = .tk_l_paren;
                break;
            },
            .r_paren => {
                result.tag = .tk_r_paren;
                break;
            },
            .l_brace => {
                result.tag = .tk_l_brace;
                break;
            },
            .r_brace => {
                result.tag = .tk_r_brace;
                break;
            },
            .canma => {
                result.tag = .tk_canma;
                break;
            },
            .equal => {
                switch(c){
                    '=' => {
                        result.tag = .tk_equal;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .tk_assign;
                    },
                }
                break;
            },
            .exclamation => {
                switch(c) {
                    '=' => {
                        result.tag = .tk_not_equal;
                        self.index += 1;
                        break;
                    },
                    else => break,
                }
            },
            .l_angle_bracket => {
                switch(c){
                    '=' => {
                        result.tag = .tk_l_angle_bracket_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .tk_l_angle_bracket;
                        break;
                    }
                }
            },
            .r_angle_bracket => {
                switch(c){
                    '=' => {
                        result.tag = .tk_r_angle_bracket_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .tk_r_angle_bracket;
                        break;
                    }
                }
            },
            .semicoron => {
                result.tag = .tk_semicoron;
                break;
            },
            .ampersand => {
                switch(c){
                    '&' => {
                        result.tag = .tk_and_and;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .tk_and;
                        break;
                    }
                }
            },
            .pipe => {
                switch(c){
                    '|' => {
                        result.tag = .tk_pipe_pipe;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .tk_pipe;
                        break;
                    }
                }
            },
            .hat => {
                result.tag = .tk_hat;
                break;
            },
            .question => {
                result.tag = .tk_question;
                break;
            },
            .coron => {
                result.tag = .tk_coron;
                break;
            },
        }
    }

    result.loc.end = self.index;
    return result;
}

pub fn getNumValue(self: *Tokenizer, start: usize) u32 {
    // TODO : add error handling

    self.index = start;
    const token = self.next();
    const val = std.fmt.parseUnsigned(u32, self.buffer[token.loc.start..token.loc.end], 10) catch unreachable;
    return val;
}

pub fn getSlice(self: *Tokenizer, start: usize) [] const u8 {
    self.index = start;
    const token = self.next();
    return self.buffer[token.loc.start..token.loc.end];
}

pub fn getLine(self: *Tokenizer, start: usize) [] const u8 {
    self.index = start;

    while(true) : (self.index += 1){
        const c = self.buffer[self.index];
        switch(c){
            '\n', 'r' => {
                break;
            },
            else => {},
        }
    }

    return self.buffer[start..self.index];
}

test "tokenizer test" {
    try testTokenize("+ +-- 323 * /a return", &.{ .tk_add, .tk_add, .tk_sub, .tk_sub, .tk_num, .tk_mul, .tk_div, .tk_identifier, .tk_return});
}


fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for(expected_token_tags) |expected_token_tag| {
        const token = tokenizer.next();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
    const last_token = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.tk_eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}
