pub const Loc = struct {
    start: usize,
    end: usize,
};

pub const Literal = union(enum) {
    INT: i64,
    FLOAT: f64,
    LIST: *Literal,
    STR: []const u8
};

pub const TokenKind = union(enum) {
    IDENT: []const u8,
    
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
    
    INT: void,
    FLOAT: void,
    STR: void,
    LIST: void,
    LITERAL: Literal,
    INVALID: void
};

pub const Token = struct {
    kind: TokenKind,
    loc: Loc
};

