const std = @import("std");

const Allocation = @import("Allocation.zig");
const ParserError = @import("Parser.zig").ParserError;
const Token = @import("Token.zig");

pub const Node = union(enum) {
    program: *Program,
    statement: *Statement,
    expression: *Expression,

    pub fn string(self: Node, writer: *std.Io.Writer) anyerror!void {
        switch (self) {
            inline else => |x| try x.string(writer),
        }
    }
};

pub const Program = struct {
    statements: std.ArrayList(*Statement),

    pub fn init(allocator: std.mem.Allocator) anyerror!*Node {
        var prg = try Allocation.createProgram(allocator);
        prg.statements = .empty;

        const node = try Allocation.createNode(allocator);
        node.* = Node{ .program = prg };
        return node;
    }

    pub fn tokenLiteral(self: Program) []const u8 {
        return if (self.statements.items.len > 0) self.statements[0].tokenLiteral() else "";
    }

    pub fn string(self: Program, writer: *std.Io.Writer) anyerror!void {
        for (self.statements.items) |stmt| {
            switch (stmt.*) {
                .@"error" => {},
                inline else => |x| try x.string(writer),
            }
        }
    }
};

// Statements

pub const Statement = union(enum(u8)) {
    @"error": ParserError,
    let_statement: *LetStatement,
    return_statement: *ReturnStatement,
    expression_statement: *ExpressionStatement,
    block_statement: *BlockStatement,

    pub fn tokenLiteral(self: Statement) []const u8 {
        return switch (self) {
            .@"error" => "",
            inline else => |x| x.tokenLiteral(),
        };
    }

    pub fn string(self: Statement, writer: *std.Io.Writer) anyerror!void {
        return switch (self) {
            .@"error" => {},
            inline else => |x| x.string(writer),
        };
    }
};

pub const LetStatement = struct {
    token: Token,
    name: *Identifier,
    value: *Expression,

    pub fn init(allocator: std.mem.Allocator, token: Token) anyerror!*LetStatement {
        const ls = try Allocation.createLetStatement(allocator);
        ls.token = token;
        return ls;
    }

    pub fn tokenLiteral(self: LetStatement) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: LetStatement, writer: *std.Io.Writer) anyerror!void {
        try writer.print("{s} ", .{self.tokenLiteral()});
        try self.name.string(writer);
        _ = try writer.write(" = ");
        try self.value.string(writer);
        _ = try writer.write(";");
    }
};

pub const ReturnStatement = struct {
    token: Token,
    return_value: *Expression,

    pub fn init(allocator: std.mem.Allocator, token: Token) anyerror!*ReturnStatement {
        const rs = try Allocation.createReturnStatement(allocator);
        rs.token = token;
        return rs;
    }

    pub fn tokenLiteral(self: ReturnStatement) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: ReturnStatement, writer: *std.Io.Writer) anyerror!void {
        try writer.print("{s} ", .{self.tokenLiteral()});
        try self.return_value.string(writer);
        _ = try writer.write(";");
    }
};

pub const ExpressionStatement = struct {
    token: Token,
    expression: *Expression,

    pub fn init(allocator: std.mem.Allocator, token: Token) anyerror!*ExpressionStatement {
        const es = try Allocation.createExpressionStatement(allocator);
        es.token = token;
        return es;
    }

    pub fn tokenLiteral(self: ExpressionStatement) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: ExpressionStatement, writer: *std.Io.Writer) anyerror!void {
        try self.expression.string(writer);
    }
};

pub const BlockStatement = struct {
    token: Token,
    statements: std.ArrayList(*Statement),

    pub fn init(allocator: std.mem.Allocator, token: Token) anyerror!*BlockStatement {
        const bs = try Allocation.createBlockStatement(allocator);
        bs.token = token;
        bs.statements = .empty;
        return bs;
    }

    pub fn tokenLiteral(self: BlockStatement) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: BlockStatement, writer: *std.Io.Writer) anyerror!void {
        for (self.statements.items) |stmt| {
            try stmt.string(writer);
        }
    }
};

// Expressions

pub const Expression = union(enum(u8)) {
    @"error": ParserError,
    identifier: *Identifier,
    integer_literal: *IntegerLiteral,
    prefix_expression: *PrefixExpression,
    infix_expression: *InfixExpression,
    boolean: *BooleanExpression,
    if_expression: *IfExpression,
    function_literal: *FunctionLiteral,
    call_expression: *CallExpression,
    string_literal: *StringLiteral,
    array_literal: *ArrayLiteral,
    index_expression: *IndexExpression,
    hash_literal: *HashLiteral,

    pub fn tokenLiteral(self: Expression) []const u8 {
        return switch (self) {
            .@"error" => "",
            inline else => |x| x.tokenLiteral(),
        };
    }

    pub fn string(self: Expression, writer: *std.Io.Writer) anyerror!void {
        return switch (self) {
            .@"error" => {},
            inline else => |x| x.string(writer),
        };
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn tokenLiteral(self: Identifier) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: Identifier, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll(self.value);
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,

    pub fn tokenLiteral(self: IntegerLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: IntegerLiteral, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll(self.token.literal);
    }
};

pub const PrefixExpression = struct {
    token: Token,
    operator: []const u8,
    right: *Expression,

    pub fn tokenLiteral(self: PrefixExpression) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: PrefixExpression, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("(");
        try writer.writeAll(self.operator);
        try self.right.string(writer);
        try writer.writeAll(")");
    }
};

pub const InfixExpression = struct {
    token: Token,
    left: *Expression,
    operator: []const u8,
    right: *Expression,

    pub fn tokenLiteral(self: InfixExpression) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: InfixExpression, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("(");
        try self.left.string(writer);
        try writer.print(" {s} ", .{self.operator});
        try self.right.string(writer);
        try writer.writeAll(")");
    }
};

pub const BooleanExpression = struct {
    token: Token,
    value: bool,

    pub fn tokenLiteral(self: BooleanExpression) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: BooleanExpression, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll(self.token.literal);
    }
};

pub const IfExpression = struct {
    token: Token,
    condition: *Expression,
    consequence: *BlockStatement,
    alternative: ?*BlockStatement,

    pub fn tokenLiteral(self: IfExpression) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: IfExpression, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("if");
        try self.condition.string(writer);
        try writer.writeAll(" ");
        try self.consequence.string(writer);

        if (self.alternative) |alternative| {
            try writer.writeAll("else ");
            try alternative.string(writer);
        }
    }
};

pub const FunctionLiteral = struct {
    token: Token,
    parameters: std.ArrayList(*Identifier),
    body: *BlockStatement,

    pub fn init(allocator: std.mem.Allocator, token: Token) anyerror!*FunctionLiteral {
        const f = try Allocation.createFunctionLiteral(allocator);
        f.token = token;
        f.parameters = .empty;
        f.body = undefined;
        return f;
    }

    pub fn tokenLiteral(self: FunctionLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: FunctionLiteral, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("fn");
        try writer.writeAll("(");
        const size = self.parameters.items.len;
        for (self.parameters.items, 0..) |param, i| {
            try param.string(writer);
            if (i < size - 1) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll(") {\n");
        try self.body.string(writer);
        try writer.writeAll("\n}");
    }
};

pub const CallExpression = struct {
    token: Token,
    function: *Expression,
    arguments: std.ArrayList(*Expression),

    pub fn init(allocator: std.mem.Allocator, token: Token, function: *Expression) anyerror!*CallExpression {
        const ce = try Allocation.createCallExpression(allocator);
        ce.token = token;
        ce.function = function;
        ce.arguments = .empty;
        return ce;
    }

    pub fn tokenLiteral(self: CallExpression) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: CallExpression, writer: *std.Io.Writer) anyerror!void {
        try self.function.string(writer);
        try writer.writeAll("(");
        const size = self.arguments.items.len;
        for (self.arguments.items, 0..) |arg, i| {
            try arg.string(writer);
            if (i < size - 1) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll(")");
    }
};

pub const StringLiteral = struct {
    token: Token,
    value: []const u8,

    pub fn tokenLiteral(self: StringLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: StringLiteral, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll(self.token.literal);
        try writer.flush();
    }
};

pub const ArrayLiteral = struct {
    token: Token,
    elements: std.ArrayList(*Expression),

    pub fn tokenLiteral(self: ArrayLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: ArrayLiteral, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("[");
        const size = self.elements.items.len;
        for (self.elements.items, 0..) |arg, i| {
            try arg.string(writer);
            if (i < size - 1) {
                try writer.writeAll(", ");
            }
        }
        try writer.writeAll("]");
    }
};

pub const IndexExpression = struct {
    token: Token,
    left: *Expression,
    index: *Expression,

    pub fn tokenLiteral(self: IndexExpression) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: IndexExpression, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("(");
        try self.left.string(writer);
        try writer.writeAll("[");
        try self.index.string(writer);
        try writer.writeAll("])");
    }
};

pub const HashLiteral = struct {
    token: Token,
    pairs: std.AutoHashMap(*Expression, *Expression),

    pub fn tokenLiteral(self: HashLiteral) []const u8 {
        return self.token.literal;
    }

    pub fn string(self: HashLiteral, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("{");

        const size = self.pairs.count();
        var i: usize = 0;
        var iterator = self.pairs.iterator();
        while (iterator.next()) |entry| {
            try entry.key_ptr.*.string(writer);
            try writer.writeAll(":");
            try entry.value_ptr.*.string(writer);
            if (i < size - 1) {
                try writer.writeAll(", ");
            }
            i += 1;
        }

        try writer.writeAll("}");
    }
};

test "TestString" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var statements: std.ArrayList(*Statement) = .empty;

    const stmt = try allocator.create(Statement);

    const let_stmt = try allocator.create(LetStatement);

    const ident1 = try allocator.create(Identifier);
    ident1.token = Token{ .type = .ident, .literal = "myVar" };
    ident1.value = "myVar";

    const ident2 = try allocator.create(Identifier);
    ident2.token = Token{ .type = .ident, .literal = "anotherVar" };
    ident2.value = "anotherVar";

    const expr = try allocator.create(Expression);

    expr.* = Expression{ .identifier = ident2 };

    let_stmt.token = Token{ .type = .let, .literal = "let" };
    let_stmt.name = ident1;
    let_stmt.value = expr;

    stmt.* = Statement{ .let_statement = let_stmt };

    try statements.append(allocator, stmt);

    const node = try Program.init(allocator);

    node.program.statements = statements;

    try std.testing.expectEqual(@as(usize, 1), node.program.statements.items.len);

    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try node.string(&writer);
    try std.testing.expectEqualStrings("let myVar = anotherVar;", writer.buffered());
}
