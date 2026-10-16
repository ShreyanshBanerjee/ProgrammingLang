pub const Loc = struct {
    start: usize,
    end: usize,
};

// zig fmt: off
pub const Literal = union(enum) {
    NUM: f64,
    LIST: *Literal,
    STR: []const u8
};

pub const Type = union(enum) {
    NUM,
    LIST: *Type,
    STR,
    STRUCT: u32
};

pub const TokenKind = union(enum) {
    IDENT: []const u8,
    INTERNED: u32,

    PLUS: void,
    MINUS: void,
    MULT: void,
    MULTMULT: void,
    SLASH: void,
    PERCENT: void,
    CARET: void,
    
    EQ: void,
    EQEQ: void,
    NEQ: void,
    LT: void,
    LTEQ: void,
    GT: void,
    GTEQ: void,
    
    LPAREN: void,
    RPAREN: void,
    LBRACK: void,
    RBRACK: void,
    LCURLY: void,
    RCURLY: void,
    
    EXCLAMATION: void,
    QUESTION: void,
    
    COMMA: void,
    COLON: void,
    SEMICOLON: void,
    DOT: void,
    ELLIPSES: void,

    FOR: void,
    IN: void,
    WHILE: void,
    VAR: void,
    CONST: void,
    FUNC: void,

    IF: void,
    ELSE: void,
    AND: void,
    OR: void,

    BREAK: void,
    CONTINUE: void,
    RETURN: void,
    
    SELF: void,

    NUM: void,
    LIST: void,
    STR: void,
    
    STRUCT: void,

    TYPE: Type,
    LITERAL: Literal,
    INVALID: void
};

pub const CompilationError = error {
    ExpectedUnaryOp,
    ExpectedBinaryOp,
    ExpectedStatementTerminator
};

// zig fmt: on
pub const Token = struct { kind: TokenKind, loc: Loc };
