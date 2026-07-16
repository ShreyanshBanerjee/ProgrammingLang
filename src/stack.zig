const std = @import("std");
const core = @import("core.zig");

pub const Stack = struct{
    data: [1024]?Frame,
    len: usize,

    pub fn build() {
        var s = Stack{
            .regs=
        }
    }
}

pub const Frame = struct{
    start: usize,
    end: usize,
    returnTo: usize,

    fId: usize
}
