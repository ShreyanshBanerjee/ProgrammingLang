//this VM is currently configured to calculate fibonacci numbers
//modify the number below and run the code!
const fib_number = 23;
const benchmarking_mode = false;

//--------------------------------------------------------------
const std = @import("std");

const Value = union(enum) {
    int: i32,
    float: f32,
    nan: void
};

const ArgKind = enum(u1) {
    register,
    constant
};

const Arg = struct {
    kind: ArgKind,
    index: usize
};

pub fn REG(i: usize) Arg {
    return Arg{.kind=.register, .index=i};
}

pub fn CONST(i: usize) Arg {
    return Arg{.kind=.constant, .index=i};
}

const Op = union(enum) {
    add: struct{ dst: usize, lhs: Arg, rhs: Arg },
    sub: struct{ dst: usize, lhs: Arg, rhs: Arg },
    mult: struct{ dst: usize, lhs: Arg, rhs: Arg },
    div: struct{ dst: usize, lhs: Arg, rhs: Arg },
    
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

    load: struct{ dst: usize, lhs: Arg },

    jump: usize,
    jumpif: struct { lhs: Arg, line: usize },
    
    print: Arg,
    print_ascii: Arg,
    halt: void
};

//behold: wall of boilerplate (but what can you do...)
fn and_op(a: i32, b: i32) Value { return Value{.int=(a & b)}; }
fn or_op(a: i32, b: i32) Value { return Value{.int=(a | b)}; }
fn xor_op(a: i32, b: i32) Value { return Value{.int=(a ^ b)}; }

fn add_op_i(a: i32, b: i32) Value { return Value{.int=a+b}; }
fn add_op_f(a: f32, b: f32) Value { return Value{.float=a+b}; }
fn sub_op_i(a: i32, b: i32) Value { return Value{.int=a-b}; }
fn sub_op_f(a: f32, b: f32) Value { return Value{.float=a-b}; }
fn mult_op_i(a: i32, b: i32) Value { return Value{.int=a*b}; }
fn mult_op_f(a: f32, b: f32) Value { return Value{.float=a*b}; }
fn div_op_i(a: i32, b: i32) Value { return Value{.int=@divTrunc(a,b)}; }
fn div_op_f(a: f32, b: f32) Value { return Value{.float=a/b}; }
fn mod_op_i(a: i32, b: i32) Value { return Value{.int=@rem(a,b)}; }
fn mod_op_f(a: f32, b: f32) Value {
    const result = std.math.rem(f32, a, b) catch { return Value{.nan={}}; };
    return Value{.float=result};
}
fn pow_op_i(a: i32, b: i32) Value {
    const result = std.math.powi(i32, a, b) catch return Value{.nan={}};
    return Value{.int=result};
}
fn pow_op_f(a: f32, b: f32) Value { return Value{.float=std.math.pow(f32, a, b)}; }

fn lt_op_i(a: i32, b: i32) Value { return Value{.int=if (a<b) 1 else 0}; }
fn lt_op_f(a: f32, b: f32) Value { return Value{.int=if (a<b) 1 else 0}; }
fn gt_op_i(a: i32, b: i32) Value { return Value{.int=if (a>b) 1 else 0}; }
fn gt_op_f(a: f32, b: f32) Value { return Value{.int=if (a>b) 1 else 0}; }
fn lteq_op_i(a: i32, b: i32) Value { return Value{.int=if (a<=b) 1 else 0}; }
fn lteq_op_f(a: f32, b: f32) Value { return Value{.int=if (a<=b) 1 else 0}; }
fn gteq_op_i(a: i32, b: i32) Value { return Value{.int=if (a>=b) 1 else 0}; }
fn gteq_op_f(a: f32, b: f32) Value { return Value{.int=if (a>=b) 1 else 0}; }

fn eqeq_op(a: Value, b: Value) Value { return Value{.int=if (std.meta.eql(a, b)) 1 else 0}; }
fn neq_op(a: Value, b: Value) Value { return Value{.int=if (std.meta.eql(a, b)) 0 else 1}; }

const VirtualMachine = struct {
    mem: [256]Value,
    constants_pool: []const Value,
    program: []const Op,
    ic: usize,

    pub fn build(program: []const Op, const_pool: []const Value) VirtualMachine {
        return VirtualMachine {
            .mem = [_]Value{ Value{.nan={}} } ** 256,
            .program = program,
            .constants_pool = const_pool,
            .ic = 0
        };
    }

    fn binary_bool_op(self: *VirtualMachine, dst: usize, a: Arg, b: Arg, f: *const fn(i32, i32) Value) void {
        const arg1 = self.unwrap(a);
        const arg2 = self.unwrap(b);
        
        if (arg1 != .int or arg2 != .int) {
            @panic("expected i32");
        }

        self.mem[dst] = f(arg1.int, arg2.int);
    }

    fn binary_numeric_op(self: *VirtualMachine, dst: usize, a: Arg, b: Arg, f_int: *const fn(i32, i32) Value, f_float: *const fn(f32, f32) Value) void {
        const arg1 = self.unwrap(a);
        const arg2 = self.unwrap(b);
        
        if (arg1 == .int and arg2 == .int) {
            self.mem[dst] = f_int(arg1.int, arg2.int);
            return;
        }
        
        const arg1f: f32 = if (arg1==.int) @floatFromInt(arg1.int) else arg1.float;
        const arg2f: f32 = if (arg2==.int) @floatFromInt(arg2.int) else arg2.float;
        
        self.mem[dst] = f_float(arg1f, arg2f);
    }

    fn binary_generic_op(self: *VirtualMachine, dst: usize, a: Arg, b: Arg, f: *const fn(Value, Value) Value) void {
        const arg1 = self.unwrap(a);
        const arg2 = self.unwrap(b);

        self.mem[dst] = f(arg1, arg2);
    }

    fn unwrap(self: *VirtualMachine, a: Arg) Value {
        if (a.kind == .register) {
            return self.mem[a.index];
        }
        return self.constants_pool[a.index];
    }

    pub fn run(self: *VirtualMachine, io: std.Io, stdout: *std.Io.Writer, comptime benchmark: bool) !void {
        
        var start_time: ?std.Io.Timestamp = null;

        if (!benchmark) { start_time = std.Io.Clock.awake.now(io); }

        self.ic = 0;
        while (self.ic < self.program.len) {
            const c_instruction = self.program[self.ic];
        
            switch (c_instruction) {
                .print => |data| {
                    if (benchmark) { self.ic = self.ic + 1; continue; }
                    const arg1 = self.unwrap(data);
                    switch (arg1) {
                        .int => |i| { try stdout.print("{d}", .{i}); },
                        .float => |f| { try stdout.print("{d}", .{f}); },
                        else => { @panic("unsupported value for printing"); }
                    }
                },
                .load => |data| {
                    const dst = data.dst;
                    const arg1 = self.unwrap(data.lhs);
                    
                    self.mem[dst] = arg1;
                },
                .log_and => |data| { self.binary_bool_op(data.dst, data.lhs, data.rhs, and_op); },
                .log_or => |data| { self.binary_bool_op(data.dst, data.lhs, data.rhs, or_op); },
                .log_xor => |data| { self.binary_bool_op(data.dst, data.lhs, data.rhs, xor_op); },
                
                //does the boilerplate ever stop? me thinks not
                .add => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, add_op_i, add_op_f); },
                .sub => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, sub_op_i, sub_op_f); },
                .mult => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, mult_op_i, mult_op_f); },
                .div => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, div_op_i, div_op_f); },
                .mod => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, mod_op_i, mod_op_f); },
                .pow => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, pow_op_i, pow_op_f); },

                .lt => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, lt_op_i, lt_op_f); },
                .lteq => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, lteq_op_i, lteq_op_f); },
                .gt => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, gt_op_i, gt_op_f); },
                .gteq => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, gteq_op_i, gteq_op_f); },
                
                .eqeq => |data| { self.binary_generic_op(data.dst, data.lhs, data.rhs, eqeq_op); },
                .neq => |data| { self.binary_generic_op(data.dst, data.lhs, data.rhs, neq_op); },

                .jump => |line| { self.ic = line; continue; },
                .jumpif => |data| {
                    const flag = self.unwrap(data.lhs);
                    if (flag == .int and flag.int != 0) {
                        self.ic = data.line;
                        continue;
                    }
                },
                
                .halt => {
                    if (benchmark) { return; }
                    try stdout.print("\n[Halted]", .{});
                    self.ic = self.ic + 1;
                    break;
                },
                else => { @panic("unsupported op"); }
            }
            self.ic = self.ic + 1;
        }

        if (benchmark) { return; }

        if (self.ic >= self.program.len) {
            try stdout.print("\n[End of Program]", .{});
        }
        
        const elapsed = start_time.?.untilNow(io, std.Io.Clock.awake);
        try stdout.print("\nExecution finished ({} ns)\n", .{elapsed.toNanoseconds()});
    }
};

pub fn main(init: std.process.Init) !void {
    //initialize stdout
    const io = init.io;
    const terminal = std.Io.File.stdout();
    var buf: [1024]u8 = undefined;
    var writer = terminal.writer(io, &buf);
    const stdout = &writer.interface;

    //bytecode for a simple fibonacci program
    //load    reg(0) <- int(1)         -- this will be our counter
    //load    reg(1) <- int(0)         -- this will hold a
    //load    reg(2) <- int(1)         -- this holds b
    //add     reg(3) <- reg(1), reg(2) -- reg(3) is a temp reg for swapping a & b
    //load    reg(1) <- reg(2)
    //load    reg(2) <- temp           -- a & b have been swapped
    //add     reg(0) <- reg(0), int(1) -- update loop counter
    //gteq    reg(4) <- reg(0), int(n) -- flag to continue looping; n is desired fibonacci number
    //jumpif  reg(4) 3
    //print   reg(2)
    //halt
    
    const const_pool = [_]Value{
        .{.int=0},
        .{.int=1},
        .{.int=fib_number}
    };

    const code = [_]Op{
        .{.load   =.{ .dst  =0,      .lhs=CONST(1)              }},
        .{.load   =.{ .dst  =1,      .lhs=CONST(0)              }},
        .{.load   =.{ .dst  =2,      .lhs=CONST(1)              }},
        .{.add    =.{ .dst  =3,      .lhs=REG(1), .rhs=REG(2)   }},
        .{.load   =.{ .dst  =1,      .lhs=REG(2)                }},
        .{.load   =.{ .dst  =2,      .lhs=REG(3)                }},
        .{.add    =.{ .dst  =0,      .lhs=REG(0), .rhs=CONST(1) }},
        .{.lt     =.{ .dst  =4,      .lhs=REG(0), .rhs=CONST(2) }},
        .{.jumpif =.{ .lhs  =REG(4), .line=3                    }},
        .{.print            =REG(2)                             },
        .{.halt             ={}                                 }
    };
    
    var vm = VirtualMachine.build(&code, &const_pool);
    try stdout.print("VM: Computing Fibonacci #{d}...\n", .{fib_number});

    if (benchmarking_mode) { 
        try stdout.print("VM: BENCHMARK - 1mil iters", .{});
        
        //warmup
        for (0..1000) |_| {
            try vm.run(io, stdout, true);
        } 

        const start_time = std.Io.Clock.awake.now(io);
        for (0..1000000) |_| {
            try vm.run(io, stdout, true);
        }
        const elapsed = start_time.untilNow(io, std.Io.Clock.awake);
        try stdout.print("\nExecution finished ({} ns)\n", .{elapsed.toNanoseconds()}); 
    }
    else {
        try vm.run(io, stdout, false);
    }
    try stdout.flush();
}
