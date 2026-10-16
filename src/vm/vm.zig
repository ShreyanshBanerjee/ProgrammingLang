const std = @import("std");

const core = @import("core.zig");
pub const Value = core.Value;
pub const ArgKind = core.ArgKind;
pub const Arg = core.Arg;
pub const Op = core.Op;
const FuncData = core.FuncData;

const ops = @import("ops.zig");
const Heap = @import("heap.zig").Heap;
const CallStack = @import("stack.zig").CallStack;

pub const VirtualMachine = struct {
    callstack: CallStack,
    func_table: []const FuncData,

    heap: Heap,

    mem: [256]Value,
    memview: []Value,

    constants_pool: []const Value,
    program: []const Op,

    pub fn build(program: []const Op, const_pool: []const Value, func_table: []const FuncData, n_main_regs: usize) VirtualMachine {
        var v = VirtualMachine{ .callstack = CallStack.build(n_main_regs), .func_table = func_table, .heap = Heap.build(), .mem = @splat(undefined), .memview = &.{}, .constants_pool = const_pool, .program = program };
        v.update_view();

        return v;
    }

    inline fn update_view(self: *VirtualMachine) void {
        const c_frame = self.callstack.frames[self.callstack.frame_depth];
        self.memview = self.mem[c_frame.fp .. c_frame.fp + c_frame.regs];
    }

    inline fn binary_bool_op(self: *VirtualMachine, dst: Arg, a: Arg, b: Arg, comptime f: fn (i32, i32) Value) void {
        const arg1 = self.unwrap(a);
        const arg2 = self.unwrap(b);

        std.debug.assert(arg1 != .int and arg2 != .int);

        self.set(dst, f(arg1.int, arg2.int));
    }

    fn binary_numeric_op(self: *VirtualMachine, dst: Arg, a: Arg, b: Arg, comptime f_int: fn (i32, i32) Value, comptime f_float: fn (f32, f32) Value) void {
        const arg1 = self.unwrap(a);
        const arg2 = self.unwrap(b);

        if (arg1 == .int and arg2 == .int) {
            self.set(dst, f_int(arg1.int, arg2.int));
            return;
        }

        const arg1f: f32 = if (arg1 == .int) @floatFromInt(arg1.int) else arg1.float;
        const arg2f: f32 = if (arg2 == .int) @floatFromInt(arg2.int) else arg2.float;

        self.set(dst, f_float(arg1f, arg2f));
    }

    inline fn binary_generic_op(self: *VirtualMachine, dst: Arg, a: Arg, b: Arg, comptime f: fn (Value, Value) Value) void {
        const arg1 = self.unwrap(a);
        const arg2 = self.unwrap(b);

        self.set(dst, f(arg1, arg2));
    }

    inline fn unwrap(self: *VirtualMachine, a: Arg) Value {
        if (a.kind == .register) {
            return self.memview[a.index];
        }
        if (a.kind == .deref) {
            const address = self.memview[a.index];
            if (address == .ptr) {
                return self.heap.mem[address.ptr + 1].value;
            }
            if (address == .subptr) {
                return self.heap.mem[address.subptr].value;
            }
        }
        return self.constants_pool[a.index];
    }

    inline fn set(self: *VirtualMachine, dst: Arg, src: Value) void {
        if (src == .ptr) {
            self.heap.increment(src.ptr);
        }

        if (dst.kind == .deref) {
            const dst_unwrapped = self.unwrap(dst);

            if (dst_unwrapped == .ptr) {
                self.heap.decrement(dst_unwrapped.ptr);
                self.heap.mem[dst_unwrapped.ptr + 1] = .{ .value = src };
            }
            if (dst_unwrapped == .subptr) {
                self.heap.mem[dst_unwrapped.subptr] = .{ .value = src };
            }
        }
        if (dst.kind == .register) {
            if (self.memview[dst.index] == .ptr) {
                self.heap.decrement(self.memview[dst.index].ptr);
            }
            self.memview[dst.index] = src;
        }
    }

    pub fn run(self: *VirtualMachine, io: std.Io, stdout: *std.Io.Writer, comptime benchmark: bool) !void {
        var start_time: ?std.Io.Timestamp = null;

        if (!benchmark) {
            start_time = std.Io.Clock.awake.now(io);
        }

        var ic: usize = 0;
        const prg = self.program;

        while (ic < prg.len) {
            switch (prg[ic]) {
                .print => |data| {
                    if (benchmark) {
                        ic = ic + 1;
                        continue;
                    }
                    const arg1 = self.unwrap(data);
                    switch (arg1) {
                        .int => |i| {
                            try stdout.print("{d}", .{i});
                        },
                        .float => |f| {
                            try stdout.print("{d}", .{f});
                        },
                        else => {
                            @panic("unsupported value for printing");
                        },
                    }
                },

                .log_and => |data| {
                    self.binary_bool_op(data.dst, data.lhs, data.rhs, ops._and);
                },
                .log_or => |data| {
                    self.binary_bool_op(data.dst, data.lhs, data.rhs, ops._or);
                },
                .log_xor => |data| {
                    self.binary_bool_op(data.dst, data.lhs, data.rhs, ops._xor);
                },

                //does the boilerplate ever stop? me thinks not
                .add => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.add_i, ops.add_f);
                },
                .sub => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.sub_i, ops.sub_f);
                },
                .mult => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.mult_i, ops.mult_f);
                },
                .div => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.div_i, ops.div_f);
                },
                .mod => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.mod_i, ops.mod_f);
                },
                .pow => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.pow_i, ops.pow_f);
                },

                .lt => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.lt_i, ops.lt_f);
                },
                .lteq => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.lteq_i, ops.lteq_f);
                },
                .gt => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.gt_i, ops.gt_f);
                },
                .gteq => |data| {
                    self.binary_numeric_op(data.dst, data.lhs, data.rhs, ops.gteq_i, ops.gteq_f);
                },

                .eqeq => |data| {
                    self.binary_generic_op(data.dst, data.lhs, data.rhs, ops.eqeq);
                },
                .neq => |data| {
                    self.binary_generic_op(data.dst, data.lhs, data.rhs, ops.neq);
                },

                .load => |data| {
                    self.set(data.dst, self.unwrap(data.lhs));
                },
                .alloc => |data| {
                    const size: usize = @intCast(self.unwrap(data.size).int);
                    self.memview[data.dst.index] = Value{ .ptr = try self.heap.alloc(size) };
                },
                .lea => |data| {
                    const boxed_ptr = self.unwrap(data.lhs);
                    const boxed_offset = self.unwrap(data.rhs);

                    const ptr: usize = if (boxed_ptr == .ptr) (boxed_ptr.ptr + 1) else boxed_ptr.subptr;
                    const offset: usize = if (boxed_offset == .float) @intFromFloat(@round(boxed_offset.float)) else @intCast(boxed_offset.int);
                    self.memview[data.dst.index] = Value{ .subptr = ptr + offset };
                },
                .jump => |line| {
                    ic = line;
                    continue;
                },
                .jumpif => |data| {
                    const flag = self.unwrap(data.lhs);
                    if (flag == .int and flag.int != 0) {
                        ic = data.line;
                        continue;
                    }
                },
                .call => |data| {
                    const f = self.func_table[data.func_id];
                    self.callstack.push(
                        f,
                        data.args,
                        ic,
                    );

                    const new_fp = self.callstack.frames[self.callstack.frame_depth].fp;
                    if (data.args[0] != null) {
                        self.mem[new_fp] = self.memview[data.args[0].?];
                        if (data.args[1] != null) {
                            self.mem[new_fp + 1] = self.memview[data.args[1].?];
                            if (data.args[2] != null) {
                                self.mem[new_fp + 2] = self.memview[data.args[2].?];
                            }
                        }
                    }
                    self.update_view();

                    ic = f.line_no;

                    continue;
                },
                .ret => {
                    const c_frame = self.callstack.pop();
                    self.update_view();

                    const prev_fp = c_frame.fp;
                    const args = c_frame.args;

                    if (c_frame.args[0] != null) {
                        self.memview[args[0].?] = self.mem[prev_fp];
                        if (args[1] != null) {
                            self.memview[args[1].?] = self.mem[prev_fp + 1];
                            if (args[2] != null) {
                                self.memview[args[2].?] = self.mem[prev_fp + 2];
                            }
                        }
                    }
                    ic = c_frame.returnTo;

                    continue;
                },
                .halt => {
                    if (benchmark) {
                        return;
                    }
                    try stdout.print("\n[Halted]", .{});
                    ic = ic + 1;
                    break;
                },
                else => {
                    @panic("unsupported op");
                },
            }
            ic = ic + 1;
        }

        if (benchmark) {
            return;
        }

        if (ic >= prg.len) {
            try stdout.print("\n[End of Program]", .{});
        }

        const elapsed = start_time.?.untilNow(io, std.Io.Clock.awake);
        try stdout.print("\nExecution finished ({} ns)\n", .{elapsed.toNanoseconds()});
    }
};
