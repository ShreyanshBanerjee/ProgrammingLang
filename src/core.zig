pub const Value = union(enum) {
    int: i32,
    float: f32,
    ptr: usize,
    subptr: usize,
    nan: void
};

pub const ArgKind = enum(u2) {
    register,
    constant,
    deref
};

pub const Arg = struct {
    kind: ArgKind,
    index: usize
};

pub fn REG(i: usize) Arg {
    return Arg{.kind=.register, .index=i};
}

pub fn CONST(i: usize) Arg {
    return Arg{.kind=.constant, .index=i};
}

pub const Op = union(enum) {
    add: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    sub: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    mult: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    div: struct{ dst: Arg, lhs: Arg, rhs: Arg },

    mod: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    pow: struct{ dst: Arg, lhs: Arg, rhs: Arg },

    neg: struct{ dst: Arg, lhs: Arg},
    
    log_or: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    log_xor: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    log_and: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    log_not: struct{ dst: Arg, lhs: Arg },
    
    eqeq: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    neq: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    lt: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    lteq: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    gt: struct{ dst: Arg, lhs: Arg, rhs: Arg },
    gteq: struct{ dst: Arg, lhs: Arg, rhs: Arg },

    load: struct{ dst: Arg, lhs: Arg },
    loado: struct{ dst: Arg, src: Arg, offset: Arg },
    storeo: struct{ dst: Arg, src: Arg, offset: Arg },
    
    alloc: struct{ dst: Arg, size: Arg },
    lea: struct{ dst: Arg, lhs: Arg, rhs: Arg },
   
    jump: usize,
    jumpif: struct { lhs: Arg, line: usize },
    
    print: Arg,
    print_ascii: Arg,
    
    halt: void
};

pub const VMError = error{
    JumpOutOfBounds,
    InvalidRegIndex,
    InvalidConstPoolIndex,
    UnexpectedToken,
    
    OutOfHeapSpace,

    InternalError
};
