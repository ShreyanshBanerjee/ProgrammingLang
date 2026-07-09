const std = @import("std");

const core = @import("core.zig");
pub const Value = core.Value;
pub const ArgKind = core.ArgKind;
pub const Arg = core.Arg;
pub const Op = core.Op;

const ops = @import("ops.zig");

pub const VirtualMachine = struct {
    mem: [256]Value,
    constants_pool: []const Value,
    program: []const Op,
    ic: usize,

    pub fn build(program: []const Op, const_pool: []const Value) VirtualMachine {
        return VirtualMachine {
            .mem = [_]Value{ Value{.nan={}} } ** 256,
            .heap = [_]Value{ Value{.nan={}} } ** 256,
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
                .log_and => |data| { self.binary_bool_op(data.dst, data.lhs, data.rhs, ops._and); },
                .log_or => |data| { self.binary_bool_op(data.dst, data.lhs, data.rhs, ops._or); },
                .log_xor => |data| { self.binary_bool_op(data.dst, data.lhs, data.rhs, ops._xor); },
                
                //does the boilerplate ever stop? me thinks not
                .add => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.add_i, ops.add_f); },
                .sub => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.sub_i, ops.sub_f); },
                .mult => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.mult_i, ops.mult_f); },
                .div => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.div_i, ops.div_f); },
                .mod => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.mod_i, ops.mod_f); },
                .pow => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.pow_i, ops.pow_f); },

                .lt => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.lt_i, ops.lt_f); },
                .lteq => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.lteq_i, ops.lteq_f); },
                .gt => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.gt_i, ops.gt_f); },
                .gteq => |data| { self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.gteq_i, ops.gteq_f); },
                
                .eqeq => |data| { self.binary_generic_op(data.dst, data.lhs, data.rhs, ops.eqeq); },
                .neq => |data| { self.binary_generic_op(data.dst, data.lhs, data.rhs, ops.neq); },

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


