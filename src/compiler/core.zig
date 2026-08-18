pub const Loc = struct {
    start: usize,
    end: usize,
};

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

    BREAK: void,
    CONTINUE: void,
    RETURN: void,
    
    TYPE: Type,
    LITERAL: Literal,
    INVALID: void
};

pub const Token = struct {
    kind: TokenKind,
    loc: Loc
};

