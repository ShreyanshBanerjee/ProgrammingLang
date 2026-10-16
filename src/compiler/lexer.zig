const std = @import("std");

const core = @import("core.zig");
pub const Loc = core.Loc;
pub const Literal = core.Literal;
pub const TokenKind = core.TokenKind;
pub const Token = core.Token;
pub const Type = core.Type;

pub const TokenMapping = [_]struct { []const u8, TokenKind }{
    .{ "=", TokenKind.EQ },
    .{ "==", TokenKind.EQEQ },
    .{ "<", TokenKind.LT },
    .{ "=<", TokenKind.LTEQ },
    .{ ">", TokenKind.GT },
    .{ ">=", TokenKind.GTEQ },

    .{ "*", TokenKind.MULT },
    .{ "**", TokenKind.MULTMULT },
    .{ "/", TokenKind.SLASH },
    .{ "+", TokenKind.PLUS },
    .{ "-", TokenKind.MINUS },
    .{ "%", TokenKind.PERCENT },
    .{ "^", TokenKind.CARET },

    .{ "{", TokenKind.LCURLY },
    .{ "}", TokenKind.RCURLY },
    .{ "[", TokenKind.LBRACK },
    .{ "]", TokenKind.RBRACK },
    .{ "(", TokenKind.LCURLY },
    .{ ")", TokenKind.RCURLY },

    .{ ",", TokenKind.COMMA },
    .{ ";", TokenKind.SEMICOLON },
    .{ ":", TokenKind.COLON },
    .{ ".", TokenKind.DOT },
    .{ "...", TokenKind.ELLIPSES },

    .{ "for", TokenKind.FOR },
    .{ "in", TokenKind.IN },
    .{ "while", TokenKind.WHILE },
    .{ "var", TokenKind.VAR },
    .{ "const", TokenKind.CONST },
    .{ "fn", TokenKind.FUNC },
    .{ "if", TokenKind.IF },
    .{ "else", TokenKind.ELSE },

    .{ "break", TokenKind.BREAK },
    .{ "continue", TokenKind.CONTINUE },
    .{ "return", TokenKind.RETURN },

    .{ "num", TokenKind.NUM },
    .{ "str", TokenKind.STR },
    .{ "list", TokenKind.LIST },
};

pub const TrieNode = struct { kind: TokenKind, children: [256]?usize };

pub fn trie_init(allocator: std.mem.Allocator) !std.ArrayList(TrieNode) {
    var trie = try std.ArrayList(TrieNode).initCapacity(allocator, 128);

    try trie.append(allocator, .{ .kind = TokenKind.INVALID, .children = @splat(null) });

    for (TokenMapping) |pair| {
        var c_node: usize = 0;
        for (pair[0]) |c| {
            const value = trie
                .items[c_node]
                .children[@as(usize, c)];

            if (value == null) {
                const new_index = trie.items.len;
                try trie.append(allocator, .{ .kind = TokenKind.INVALID, .children = @splat(null) });

                trie.items[c_node].children[@as(usize, c)] = new_index;
                c_node = new_index;
            } else {
                c_node = value.?;
            }
        }
        trie.items[c_node].kind = pair[1];
    }
    return trie;
}

pub fn isAlphaNumericOr_(c: u8) bool {
    if (std.ascii.isAlphanumeric(c)) {
        return true;
    }
    return c == '_';
}

pub const Lexer = struct {
    data: []const u8,
    index: usize,

    pub fn build(text: []const u8) Lexer {
        return Lexer{ .data = text, .index = 0 };
    }

    pub fn take(self: *Lexer) ?u8 {
        if (self.index > self.data.len) {
            return null;
        }
        defer self.index += 1;
        return self.data[self.index];
    }

    pub fn peek(self: *Lexer) ?u8 {
        if (self.index >= self.data.len) {
            return null;
        }
        return self.data[self.index];
    }

    pub fn take_num(self: *Lexer) !Token {
        const start = self.index;
        var periods: usize = 0;
        while (periods < 2 and self.peek() != null) {
            if (self.peek().? == '.') {
                _ = self.take();
                periods += 1;
            } else if (std.ascii.isDigit(self.peek().?)) {
                _ = self.take();
            } else {
                break;
            }
        }

        return .{ .kind = .{ .LITERAL = .{ .NUM = try std.fmt.parseFloat(f64, self.data[start..self.index]) } }, .loc = .{ .start = start, .end = self.index } };
    }

    pub fn take_str(self: *Lexer) Token {
        const start = self.index;
        const start_char = self.take();

        while (self.peek()) |c| {
            _ = self.take();

            if (c == start_char) {
                _ = self.take();
                return .{ .kind = .{ .LITERAL = .{ .STR = self.data[start + 1 .. self.index - 1] } }, .loc = .{ .start = start, .end = self.index } };
            }
            if (c == '\\') {
                _ = self.take();
            }
        }

        unreachable;
    }

    pub fn scan(self: *Lexer, trie: std.ArrayList(TrieNode)) Token {
        const start = self.index;
        const alpha_start = std.ascii.isAlphabetic(self.data[self.index]);

        var c_node: usize = 0;
        while (self.peek()) |v| {
            if (trie.items[c_node].children[@as(usize, v)]) |n| {
                _ = self.take();
                c_node = n;
            } else {
                break;
            }
        }

        if (alpha_start and ((self.peek() != null and isAlphaNumericOr_(self.peek().?)) or (trie.items[c_node].kind == TokenKind.INVALID))) {
            while (self.peek() != null and isAlphaNumericOr_(self.peek().?)) {
                _ = self.take();
            }

            return .{ .kind = .{ .IDENT = self.data[start..self.index] }, .loc = .{ .start = start, .end = self.index } };
        }

        return .{ .kind = trie.items[c_node].kind, .loc = .{ .start = start, .end = self.index } };
    }

    pub fn run(self: *Lexer, allocator: std.mem.Allocator, trie: std.ArrayList(TrieNode)) !std.ArrayList(Token) {
        var result: std.ArrayList(Token) = .empty;

        while (self.peek()) |i| {
            if (i == '\'' or i == '\"') {
                try result.append(allocator, self.take_str());
                continue;
            }

            if (std.ascii.isDigit(i)) {
                try result.append(allocator, try self.take_num());
                continue;
            }

            if (std.ascii.isWhitespace(i)) {
                _ = self.take();
                continue;
            }

            try result.append(allocator, self.scan(trie));
        }
        return result;
    }

    pub fn intern(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator) !std.StringHashMap(u32) {
        var ident_mapping: std.StringHashMap(u32) = .init(allocator);

        var i = 0;
        while (i < tokens.*.items.len) : (i += 1) {
            if (tokens.*.items[i] != .IDENT) {
                continue;
            }

            const ident = ident_mapping.get(tokens.*.items[i].IDENT);

            if (ident) |id| {
                tokens.*.items[i] = .{ .INTERNED = id };
            } else {
                tokens.*.items[i] = .{ .INTERNED = ident_mapping.count() };
                try ident_mapping.put(ident_mapping.count());
            }
        }

        return ident_mapping;
    }
};
//func fibonacci(int a) int c =
//      if a==1 {1}
//      else { fibonacci(a) + fibonacci(a-1) }
