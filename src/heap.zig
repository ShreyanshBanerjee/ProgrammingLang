const std = @import("std");
const core = @import("core.zig");

pub const Value = core.Value;
pub const Arg = core.Arg;
pub const Op = core.Op;
pub const vmerr = core.VMError;

const MemorySlot = union(enum) {
    header: struct{ size: usize, refs: usize },
    free: struct{ size: usize, next: ?usize },
    value: Value,
};

pub const Heap = struct{
    mem: [256]MemorySlot, free: ?usize,

    pub fn build() Heap { 
        var h = Heap {
            .mem = [_]MemorySlot{ .{.value=Value{ .nan={} }} } ** 256,
            .free = 0
        };

        h.mem[0] = MemorySlot{ .free=.{ .size=15, .next=null } };

        return h;
    }

    pub fn alloc(self: *Heap, bits: usize) !usize {
        const child = &self.free;

        while (child.*) |i| {
            const node = self.mem[i];
            
            if (node != .free) {
                return vmerr.InternalError;
            }
            
            if (node.free.size == bits+1) {
                child.* = node.free.next;

                self.mem[i] = .{ .header=.{ .size=bits, .refs=1 } };

                return i;
            }

            if (node.free.size > bits+1) {
                child.* = child.*.? + bits + 1;
                
                self.mem[child.*.?] = MemorySlot { .free=.{ .size=(self.mem[i].free.size - 1 - bits), .next=self.mem[i].free.next } };
                
                self.mem[i] = MemorySlot{ .header=.{ .size=bits, .refs=1 } };

                return i;
            }
        }
        
        return vmerr.OutOfHeapSpace;
    }

    pub fn dealloc(self: *Heap, ptr: usize) void {
        var child = &self.free;
        const to_free = &self.mem[ptr];

        
        if (child.* != null and child.*.? > ptr) {
            to_free.* = MemorySlot{ .free=.{ .size=to_free.*.header.size, .next=child.* } };
            child.* = ptr;

            return;
        }

        while (child.*) |i| {
            var node = self.mem[i];

            if (node != .free) {
                @panic("heap state invalid");
            }
            
            if (node.free.next == null or node.free.next.? > ptr) {
                to_free.* = MemorySlot{ .free=.{ .size=to_free.*.header.size, .next=node.free.next } };
            }

            child = &node.free.next;
        }
        
        @panic("tried to dealloc invalid ptr");

    }

    pub fn recombine(self: *Heap, i: usize) usize {
        if (self.mem[i] != .free) {
            @panic("heap state invalid");
        }

        const c_block = self.mem[i].free;

        if (c_block.next == null) {
            return i;
        }

        if (i + 1 + c_block.size == c_block.next.?) {
            self.mem[i] = MemorySlot { 
                .free=.{
                    .size=(c_block.size + self.mem[c_block.next.?].free.size + 1),
                    .next=self.mem[c_block.next.?].free.next
                }
            };
            return self.recombine(i);
        }

        self.mem[i].free.next = self.recombine(c_block.next.?);
        
        return i;
    }

    pub fn increment(self: *Heap, what: usize) void {
        self.mem[what].header.refs += 1;
    }

    pub fn decrement(self: *Heap, what: usize) void {
        self.mem[what].header.refs -= 1; if (self.mem[what].header.refs == 0) {
            self.dealloc(what);
            _ = self.recombine(self.free.?);
        }
    }

    pub fn pretty_print(self: *Heap) void {
        
        std.debug.print("Heap Object:\n", .{});
        for (self.mem) |obj| {
            std.debug.print("{any}\n", .{obj});
        }
 }
};
