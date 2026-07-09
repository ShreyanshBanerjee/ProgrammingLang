pub const Value = union(enum) {
    int: i32,
    float: f32,
    ptr: usize,
    nan: void
};

pub const ArgKind = enum(u1) {
    register,
    constant
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
    add: struct{ dst: usize, lhs: Arg, rhs: Arg },
    sub: struct{ dst: usize, lhs: Arg, rhs: Arg },
    mult: struct{ dst: usize, lhs: Arg, rhs: Arg }, div: struct{ dst: usize, lhs: Arg, rhs: Arg },
    
    mod: struct{ dst: usize, lhs: Arg, rhs: Arg },
    pow: struct{ dst: usize, lhs: Arg, rhs: Arg },

    neg: struct{ dst: usize, lhs: Arg},
    
    log_or: struct{ dst: usize, lhs: Arg, rhs: Arg },
    log_xor: struct{ dst: usize, lhs: Arg, rhs: Arg },
    log_and: struct{ dst: usize, lhs: Arg, rhs: Arg },
    log_not: struct{ dst: usize, lhs: Arg },
    
    eqeq: struct{ dst: usize, lhs: Arg, rhs: Arg },
    neq: struct{ dst: usize, lhs: Arg, rhs: Arg },
    lt: struct{ dst: usize, lhs: Arg, rhs: Arg },
    lteq: struct{ dst: usize, lhs: Arg, rhs: Arg },
    gt: struct{ dst: usize, lhs: Arg, rhs: Arg },
    gteq: struct{ dst: usize, lhs: Arg, rhs: Arg },

    load: struct{ dst: Arg, lhs: Arg },
    
    alloc: struct{ dst: Arg, size: usize},

    jump: usize,
    jumpif: struct { lhs: Arg, line: usize },
    
    print: Arg,
    print_ascii: Arg,
    
    halt: void
};

 const VMError = error{
    JumpOutOfBounds,
    InvalidRegIndex,
    InvalidConstPoolIndex,
    UnexpectedToken,
    
    OutOfHeapSpace,

    InternalError
};
