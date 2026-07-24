const std = @import("std");

const core = @import("core.zig");
const Value = core.Value;
const FuncData = core.FuncData;

pub const CallStack = struct{
    frame_depth: usize, //number of additional frames besides base
    frames: [256]Frame,

    pub fn build(n_main_regs: usize) CallStack {
        var s = CallStack{
            .frame_depth=0,
            .frames=[_]Frame{ undefined } ** 256,
        };
        
        s.frames[0]=Frame{.fp=0, .regs=n_main_regs, .returnTo=0, .args=[_]?usize{null}**3};
        return s;
    }
    
    
    pub fn push(self: *CallStack, f: FuncData, args: [3]?usize, c_line: usize) void {
        std.debug.assert(self.frame_depth + 1 < self.frames.len);
 
        const prev = self.frames[self.frame_depth];
        
        self.frame_depth+=1;
        
        self.frames[self.frame_depth] = Frame{
            .fp=prev.fp + prev.regs,
            .regs=f.n_regs,
            .returnTo=c_line+1,
            
            .args=args
        };
    }

    pub fn pop(self: *CallStack) Frame {
        std.debug.assert(self.frame_depth > 0);
        
        defer {
            self.frame_depth-=1;
        }

        return self.frames[self.frame_depth];
    }
};

pub const Frame = struct{
    fp: usize,
    regs: usize,
    returnTo: usize,
    
    args: [3]?usize,
};
