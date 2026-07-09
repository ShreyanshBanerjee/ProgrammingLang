const std = @import("std");

const core = @import("core.zig");
pub const Value = core.Value;
pub const Arg = core.Arg;
pub const Op = core.Op;
pub const vmerr = core.VMError;

const Data = union(enum) {
    header: struct{ refs: usize, size: usize },
    free: struct{ size: usize, next: ?usize },
    value: Value,
};

pub const Heap = struct{
    mem: [256]Data,
    free: usize?

    pub fn build() Heap { 
        var h = Heap {
            .mem = [_]Data{ .value={ Value{ .nan={} }}} ** 256,
            .free = 0
        };

        h.mem[0] = Data{ .free={ .size=255, .next=null}};

        return h;
    }

    pub fn alloc(self: *Heap, bits: usize) !usize {
        var child = &self.free;

        while (child.*) |i| {
            var node = self.mem[i];
            if (!node.free) {
                return vmerr.InternalError;
            }
            
            if (node.free.size == bits) {
                self.child.* = self.mem[i].free.next;

                self.mem[i] = Data{ .header{.refs=1, .size=bits} };
                return i;
            }

            if (node.free.size > bits) {
                self.child.* = i + bits + 1;
                
                self.mem[i] = Data{ .header{.refs=1, size=bits}};
                self.mem[i+bits+1] = Data{ .free{ .size=node.free.size-bits-1, node.free.next } };

                return i;
            }

            child = &c_node.free.next;
        }
        return vmerr.OutOfHeapSpace;
    }

    pub fn alloc(self: *Heap, size: usize) !usize {
        var child = &self.free;

        while (child.*) |i| {
            var node = self.mem[i];
            
            if (!node.free) {
                return vmerr.InternalError;
            }
            
            if (node.free.size == size+1) {
                child.* = node.free.next;

                self.mem[i] = Data{ .header={ .size=size, .refs=1 } };

                return i;
            }

            if (node.free.size > size+1) {
                child.* = child.* + size + 1;
                
                self.mem[child.*] = Data { .free={ .size=(self.mem[i].free.size - 1 - size), .next=self.mem[i].free.next } }
                
                self.mem[i] = Data{ .header={ .size=size, .refs=1 } };
            }
        }
        
        return vmerr.OutOfHeapSpace;
    }

    pub fn dealloc(self: *Heap, ptr: usize) {
        var child = &self.free;
        var to_free = &self.mem[ptr];
        
        while (child.*) |i| {
            var node = self.mem[i];

            if (!node.free) {
                return vmerr.InternalError;
            }
            
            if (node.free.next == null or node.free.next.? > ptr) {
                to_free.* = Data { .free{ .size=to_free.*.header.size, node.free.next } }
            }

            child = &c_node.free.next;
        }

        return vmerr.InternalError;
    }

    pub fn recombine(self: *Heap, i: usize) !usize {
        if (!self.mem[i].free) {
            return vmerr.InternalError;
        }

        const c_block = self.mem[i].free;

        if (c_block.next == null) {
            return i;
        }

        if (i + 1 + c_block.size == c_block.next.?) {
            self.mem[i] = Data { 
                .free={
                    .size=c_block.size + self.mem[c_block.next.?].free.size + 1,
                    .next=self.mem[c_block.next.?].free.next
                }
            };
            return try self.recombine(i);
        }

        self.mem[i].free.next = try self.recombine(c_block.next.?);
        
        return i;
    };
}
