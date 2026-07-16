//this VM is currently configured to calculate fibonacci numbers
//modify the number below and run the code!
const fib_number = 46;
const benchmarking_mode = true;

//--------------------------------------------------------------
const std = @import("std");

const core = @import("core.zig");
pub const Value = core.Value;
pub const Arg = core.Arg;
pub const Op = core.Op;
pub const CONST = core.CONST;
pub const REG = core.REG;

const vm = @import("vm.zig");

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
        .{.load   =.{ .dst  =REG(0), .lhs=CONST(1)              }},
        .{.load   =.{ .dst  =REG(1), .lhs=CONST(0)              }},
        .{.load   =.{ .dst  =REG(2), .lhs=CONST(1)              }},
        .{.add    =.{ .dst  =REG(3), .lhs=REG(1), .rhs=REG(2)   }},
        .{.load   =.{ .dst  =REG(1), .lhs=REG(2)                }},
        .{.load   =.{ .dst  =REG(2), .lhs=REG(3)                }},
        .{.add    =.{ .dst  =REG(0), .lhs=REG(0), .rhs=CONST(1) }},
        .{.lt     =.{ .dst  =REG(4), .lhs=REG(0), .rhs=CONST(2) }},
        .{.jumpif =.{ .lhs  =REG(4), .line=3                    }},
        .{.print            =REG(2)                             },
        .{.halt             ={}                                 }
    };
    
    var instance = vm.VirtualMachine.build(&code, &const_pool);
    try stdout.print("VM: Computing Fibonacci #{d}...\n", .{fib_number});

    if (benchmarking_mode) { 
        try stdout.print("VM: BENCHMARK - 1mil iters", .{});
        
        //warmup
        for (0..1000) |_| {
            try instance.run(io, stdout, true);
        } 

        const start_time = std.Io.Clock.awake.now(io);
        for (0..1000000) |_| {
            try instance.run(io, stdout, true);
        }
        const elapsed = start_time.untilNow(io, std.Io.Clock.awake);
        try stdout.print("\nExecution finished ({} ns)\n", .{elapsed.toNanoseconds()}); 
    }
    else {
        try instance.run(io, stdout, false);
    }
    try stdout.flush();
}
