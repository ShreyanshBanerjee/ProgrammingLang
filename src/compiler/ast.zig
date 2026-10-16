const std = @import("std");

const core = @import("core.zig");
pub const Loc = core.Loc;
pub const Literal = core.Literal;
pub const Type = core.Type;
pub const TokenKind = core.TokenKind;
pub const Token = core.Token;
pub const CompilationError = core.CompilationError;

// zig fmt: off
pub const UnaryOp = enum { NEGATE, NOT, LIFT };

pub const BinaryOp = union(enum) {
    EQUALS,
    LESS,
    GREATER,
    LESS_EQUALS,
    GREATER_EQUALS,
    NOT_EQUALS,
    ADD,
    SUBS,
    MULT,
    DIV,
    POWER,
    MODULO,
    AND,
    OR
};

//rather than having the ASTData be a recursive type,
//we have it include indices (of type usize) into a list of ASTNode
//we do this for better cache performance, simplicity, and because it makes freeing easier
pub const ASTData = union(enum) {
    Literal: Literal, ListLiteral: usize,
    RangeLiteral: struct { first: usize, second: ?usize, last: usize, inclusive: bool },
    Variable: u32,
    Assignment: struct { id: u32, is_var: bool, type: Type, rhs: usize },
    Unary: struct { op: UnaryOp, lhs: usize },
    Binary: struct { op: BinaryOp, lhs: usize, rhs: usize },
    IndexAccess: struct { collection: usize, index: usize },
    If: struct { 
        if_block: struct { cond: usize, body: usize },
        elif_block: ?std.ArrayList(struct { cond: usize, body: usize }),
        else_block: ?usize
    },
    While: struct { cond: usize, code: usize },
    For: struct { collection: usize, id: u32, code: usize },
    Block: std.ArrayList(usize),
    Break: void,
    Continue: void,
    Function: struct { id: u32, inputs: std.ArrayList(struct { id: u32, type: Type }), output: Type, code: usize },
    Call: struct { id: u32, inputs: std.ArrayList(usize) },
    StructDef: struct {
        id: u32,
        fields: std.ArrayList(struct { id: u32, type: Type }),
        methods: std.ArrayList(
            struct { id: u32, is_static: bool, inputs: std.ArrayList(struct { id: u32, type: Type }),
            output: Type, code: std.ArrayList(usize) }
        )
    },
    FieldAccess: struct { object: usize, field_id: u32 },
    MethodCall: struct { object: usize, id: u32, is_static: bool, inputs: std.ArrayList(usize) },
    StructInit: struct { id: u32, fields: std.ArrayList(struct { id: u32, pair: struct {name: u32, val:std.ArrayList(usize)} }) },
    Return: ?u32
};

// zig fmt: on
pub const ASTNode = struct {
    data: ASTData,
    loc: Loc,

    pub fn new(k: ASTData, l: Loc) ASTNode {
        return .{ .data = k, .loc = l };
    }
};

pub const Ast = struct {
    code: std.ArrayList(usize), //again, we store indices instead of usize
    nodes: std.ArrayList(ASTNode),
    alloc: std.mem.Allocator,
    pub fn deinit(self: *Ast) void {
        self.code.deinit();

        var i = 0;
        while (i < self.nodes.items.len()) : (i += 1) {
            switch (self.nodes.items[i].data) {
                .If => |*v| {
                    v.*.if_block.body.deinit(self.alloc);
                    if (v.*.else_ifs) {
                        v.*.?.else_ifs.deinit(self.alloc);
                    }
                    if (v.*.else_block) {
                        v.*.?.else_block.deinit(self.alloc);
                    }
                },
                .Block => |*v| {
                    v.*.deinit(self.alloc);
                },
                .StructInit => |*v| {
                    v.*.fields.deinit(self.alloc);
                },
                .StructDef => |*v| {
                    v.*.fields.deinit(self.alloc);

                    var k = 0;
                    while (k < v.*.methods.len()) : (k += 1) {
                        v.*.methods.items[k].inputs.deinit(self.alloc);
                        v.*.methods.items[k].code.deinit(self.alloc);
                    }
                    v.*.methods.deinit(self.alloc);
                },
                inline else => |*v| {
                    if (@hasField(@TypeOf(v.*), "code")) {
                        v.*.code.deinit(self.alloc);
                    }
                    if (@hasField(@TypeOf(v.*), "inputs")) {
                        v.*.inputs.deinit(self.alloc);
                    }
                },
            }
        }
    }
};

pub const ASTBuilder = struct {
    tokens: std.ArrayList(Token),
    index: usize,
    result: Ast,

    pub fn build(tokens: std.ArrayList(Token), allocator: std.mem.Allocator) ASTBuilder {
        // zig fmt: off
        return ASTBuilder{
            .tokens = tokens,
            .index = 0,
            .result = Ast{ 
                .code = .empty,
                .nodes = .empty,
                .alloc = allocator 
            },
        };
        // zig fmt: on
    }

    pub fn peek(self: ASTBuilder) ?Token {
        if (self.index >= self.tokens.items.len) {
            return null;
        }
        return self.tokens.items[self.index];
    }

    pub fn next(self: *ASTBuilder) ?Token {
        if (self.index >= self.tokens.items.len) {
            return null;
        }

        defer self.index += 1;
        return self.tokens.items[self.index];
    }

    pub fn expect_next(self: *ASTBuilder, val: TokenKind) void {
        std.debug.assert(std.meta.activeTag(self.next().?.kind) == val);
    }

    pub fn binding_power(t: BinaryOp) struct { u8, u8 } {
        return switch (t.kind) {
            .POWER => .{ 70, 69 },
            .MULT, .MODULO, .DIV => .{ 60, 61 },
            .ADD, .SUBS => .{ 50, 51 },

            .LESS, .LESS_EQUALS, .GREATER_EQUALS, .GREATER => .{ 40, 41 },
            .EQUALS, .NOT_EQUALS => .{ 30, 31 },
            .AND => .{ 20, 21 },
            .OR => .{ 10, 11 },
            else => .{ 0, 0 },
        };
    }

    pub fn prefix_binding_power(t: Token) u32 {
        return switch (t.kind) {
            .CARET => 110,
            .MINUS, .EXCLAMATION => 100,
            else => unreachable,
        };
    }

    pub fn add_tok(self: *ASTBuilder, a: ASTNode) usize {
        const clen = self.result.nodes.items.len;
        self.result.nodes.append(self.result.alloc, a) catch unreachable;
        return clen;
    }

    fn parsing_pattern(self: *ASTBuilder, comptime template: anytype) struct { tokens: [template.len]TokenKind, nodes: [template.len]usize } {
        var nodes: [template.len]usize = undefined;
        var tokens: [template.len]usize = undefined;
        var n_nodes = 0;
        var n_tokens = 0;
        inline for (template) |t| {
            if (@typeInfo(@TypeOf(t)) == .TokenKind) {
                self.next().?.kind.expect(t);
                continue;
            } else if (t == next) {
                tokens[n_tokens] = self.next().?.kind;
                n_tokens += 1;
                continue;
            } else if (t == parse_expression) {
                nodes[n_nodes] = self.parse_expression(0);
            } else if (t == parse_statement) {
                nodes[n_nodes] = self.parse_statement();
            }
            n_nodes += 1;
        }
        return .{ .nodes = nodes, .tokens = tokens };
    }

    pub fn nud(self: *ASTBuilder) !usize {
        if (self.peek()) |t| {
            switch (t.kind) {
                .INTERNED => |v| return self.add_tok(ASTNode.new(.{ .Variable = v }, t.loc)),
                .LITERAL => |v| return self.add_tok(ASTNode.new(.{ .Literal = v }, t.loc)),
                .LPAREN => {
                    defer self.expect_next(TokenKind.RPAREN);
                    return self.parse_expression(10);
                },
                .CARET => {
                    const operand = self.parse_expression(ASTBuilder.prefix_binding_power(t.kind));
                    return self.add_tok(ASTNode.new(.{ .op = UnaryOp.Caret, .lhs = operand }));
                },
                .MINUS => {
                    const operand = self.parse_expression(ASTBuilder.prefix_binding_power(t.kind));
                    return self.add_tok(ASTNode.new(.{ .op = UnaryOp.Caret, .lhs = operand }));
                },
                .IF => {
                    self.next().kind.expect(TokenKind.LCURLY);
                    const cond = self.parse_expression(0);
                    self.next().kind.expect(TokenKind.RCURLY);
                    const block = self.parse_block(self.result.alloc);

                    var else_ifs = null;
                    var else_block = null;
                    while (self.peek().?.kind == TokenKind.ELSE) {
                        self.next().kind.expect(TokenKind.ELSE);
                        if (self.peek() == TokenKind.IF) {
                            if (else_ifs == null) {
                                else_ifs = std.ArrayList(usize);
                            }
                            const elseif_cond = self.parse_expression(0);
                            self.next().kind.expect(TokenKind.RPAREN);
                            self.next().kind.expect(TokenKind.LCURLY);
                            else_ifs.append(self.result.alloc, .{ .cond = elseif_cond, .body = self.parse_block(self.result.alloc) });
                            continue;
                        }
                        self.next().kind.expect(TokenKind.LCURLY);
                        else_block = self.parse_block();
                        break;
                    }
                    // zig fmt: off
                    return self.add_tok(ASTNode.new(.{
                        .if_block = .{ .cond = cond, .body = block },
                        .else_ifs = else_ifs,
                        .else_block = else_block
                    }));
                    // zig fmt: on
                },

                else => {
                    unreachable;
                },
            }
        }
        return CompilationError.ExpectedUnaryOp;
    }

    pub fn get_binary_op(self: *ASTBuilder) BinaryOp {
        return switch (self.next().?.kind) {
            .EQEQ => BinaryOp.EQUALS,
            .NEQ => BinaryOp.NOT_EQUALS,
            .LT => BinaryOp.LESS,
            .GT => BinaryOp.GREATER,
            .LTEQ => BinaryOp.LESS_EQUALS,
            .GTEQ => BinaryOp.GREATER_EQUALS,
            .PLUS => BinaryOp.ADD,
            .MINUS => BinaryOp.SUBS,
            .SLASH => BinaryOp.DIV,
            .MULT => BinaryOp.MULT,
            .MULTMULT => BinaryOp.POWER,
            .MODULO => BinaryOp.MODULO,
            .AND => BinaryOp.AND,
            .OR => BinaryOp.OR,
            else => CompilationError.ExpectedBinaryOp,
        };
    }

    pub fn parse_expression(self: *ASTBuilder, right_bp: u8) usize {
        var lhs = self.nud().?;
        while (true) {
            const next_tok = self.peek().? orelse break;
            if (right_bp >= binding_power(next_tok).@"0") {
                break;
            }

            const current_op = self.get_binary_op();
            const current_bp = ASTBuilder.binding_power(current_op).@"1";

            // zig fmt: off
            lhs = self.add_tok(
                ASTNode.new(
                    .{ .op = current_op, .lhs = lhs, .rhs = self.parse_expression(current_bp)}
                )
            );
            // zig fmt: on
        }

        return lhs;
    }

    pub fn parse_statement(self: *ASTBuilder) usize {
        const start = self.index;
        switch (self.peek().kind) {
            TokenKind.VAR | TokenKind.CONST => {
                const is_var = self.next().kind.VAR;
                const t = if (self.peek().?.kind.TYPE) self.next().kind.TYPE else null;
                const result = self.parsing_pattern(next, .EQ, parse_expression, .SEMICOLON);
                // zig fmt: off
                return self.add_tok(ASTNode.new(
                    .{.id=result.tokens[0].IDENT, .is_var=is_var, .type=t, .rhs=result.nodes[0]},
                    .{.start=start, .end=self.index}
                ));
                // zig fmt: on
            },
            TokenKind.FOR => {
                const result = self.parsing_pattern(.FOR, .LPAREN, next, .COLON, parse_expression, .RPAREN, parse_statement);

                return self.add_tok(ASTNode.new(.{ .id = result.tokens[0], .collection = result.nodes[0], .body = result.nodes[1] }));
            },
            TokenKind.WHILE => {
                const result = self.parsing_pattern(.WHILE, .LPAREN, parse_expression, .RPAREN, parse_statement);

                return self.add_tok(ASTNode.new(.{ .id = result.tokens[0], .collection = result.nodes[0], .body = result.nodes[1] }));
            },
            TokenKind.IF => {
                const if_result = self.parsing_pattern(.IF, .LPAREN, parse_expression, .RPAREN, parse_statement).nodes;

                var elif_blocks = null;
                var else_block = null;

                while (self.peek().?.kind == .ELSE) {
                    self.next();
                    if (self.peek().?.kind == .IF) {
                        if (elif_blocks == null) elif_blocks = std.ArrayList(struct { cond: usize, block: usize }).init(self.ast.alloc);
                        const c_result = self.parsing_pattern(.IF, .LPAREN, parse_expression, .RPAREN, parse_statement).nodes;

                        elif_blocks.append(self.result.alloc, .{ .cond = c_result[0], .block = c_result[1] });
                        continue;
                    }
                    else_block = self.parse_statement();
                    break;
                }
                // zig fmt: off
                return self.add_tok(ASTNode.new(.{
                    .if_block=.{.cond=if_result[0], .body=if_result[1]},
                    .elsif_blocks=elif_blocks,
                    .else_block=else_block
                }));
                // zig fmt: on
            },
            TokenKind.LCURLY => {
                var lines = std.ArrayList(usize);
                while (self.peek().?.kind == .LCURLY) {
                    lines.append(self.parse_expression(0));
                }
                self.next().?.kind.expect(TokenKind.RCURLY);
                return self.add_tok(ASTNode.new(.{ .Block = lines }));
            },
        }
    }

    pub fn run(self: *ASTBuilder) Ast {
        while (self.peek() != null) {
            self.result.code.append(self.result.alloc, self.parse_expression(0));
        }
        self.next().?.kind.expect(TokenKind.RCURLY);
        return self.result;
    }
};
