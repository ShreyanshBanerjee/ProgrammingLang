const std = @import("std");
const core = @import("core.zig");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var trie = try lexer.trie_init(allocator);
    defer _ = trie.deinit(allocator);

    const code = "var x: list[int] = [1, 1, 1+1, 1*2+1];";
    var l = lexer.Lexer.build(code);

    var result = try l.run(allocator, trie);
    defer _ = result.deinit(allocator);

    var astbuilder = ast.ASTBuilder.build(result, allocator);
    defer _ = astbuilder.deinit(allocator);

    const tree = astbuilder.run();
    defer _ = tree.deinit();

    for (tree.code) |i| {
        std.debug.print("{:?}", i);
    }
}
