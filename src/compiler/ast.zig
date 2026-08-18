const std = @import("std");

const core = @import("core.zig");
pub const Loc = core.Loc;
pub const Literal = core.Literal;
pub const Type = core.Type;
pub const TokenKind = core.TokenKind;
pub const Token = core.Token;

pub const UnaryOp = enum {
    NEGATE,
    NOT,
    LIFT
}

pub const BinaryOp = union(enum) {
    EQUALS,
    LESS,
    GREATER,
    LESSEQUALS,
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
}


pub const ASTNode = union(enum) {
    Literal: Literal,
    ListLiteral: std.ArrayList(ASTNode),
    RangeLiteral: struct{first: ASTNode, second: ASTNode, last: ASTNode, inclusive: bool},
    Variable: u32,

    Assignment: struct{id: u32, is_var: bool, type: Type, rhs: ASTNode},
    Unary: struct{op: UnaryOp, lhs: ASTNode}, 
    Binary: struct{op: BinaryOp, lhs: ASTNode, rhs: ASTNode},
    
    IndexAccess: struct{collection: ASTNode, index: ASTNode},

    If: struct{if_block: struct{cond:ASTNode, body:std.ArrayList(ASTNode)}, else_ifs: ?std.ArrayList(struct{cond:ASTNode, body:std.ArrayList(ASTNode)}), else: ?std.ArrayList(ASTNode)},
    While: struct{cond: ASTNode, code: std.ArrayList(ASTNode)},
    For: struct{collection: ASTNode, code: std.ArrayList(ASTNode)},
    Block: std.ArrayList(ASTNode),
    Break: ?ASTNode,
    Continue,
    
    Function: struct{id: u32, inputs: std.ArrayList(struct{id:u32, type:Type}), output: Type, code: std.ArrayList(ASTNode)},
    Call: struct{id: u32, inputs: std.ArrayList(ASTNode)},
    
    StructDef: struct{
        id: u32, fields: std.ArrayList(struct{id:u32, type:Type)}),
        methods: std.ArrayList(struct{id: u32, is_static: bool, inputs: std.ArrayList(struct{id:u32, type:Type)}), output: Type, code: std.ArrayList(ASTNode)})
    },
    FieldAccess: struct{object: ASTNode, field_id: u32},
    MethodCall: struct{object: ASTNode, id: u32, is_static: bool, inputs: std.ArrayList(ASTNode)},
    StructInit: struct{id: u32, fields: std.ArrayList(struct{id:u32, val:ASTNode})},
    Return: ?ASTNode,
}
