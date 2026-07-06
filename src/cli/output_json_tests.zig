const std = @import("std");
const Io = std.Io;
const output_json = @import("output_json.zig");
const test_manifest = @import("test_manifest.zig");

const TestSuiteSummary = test_manifest.TestSuiteSummary;

test "writeJsonString uses std json escaping" {
    var buffer: [128]u8 = undefined;
    var writer = Io.Writer.fixed(&buffer);

    try output_json.writeJsonString(&writer, "quote\" slash\\ line\n tab\t");

    try std.testing.expectEqualStrings(
        "\"quote\\\" slash\\\\ line\\n tab\\t\"",
        writer.buffered(),
    );
}

test "field value json preserves compact float formatting" {
    var buffer: [128]u8 = undefined;
    var writer = Io.Writer.fixed(&buffer);

    try output_json.printExpectedFieldValueJson(&writer, .{ .vec3 = .{ 0.016666668, 1.5, -2.0 } });

    try std.testing.expectEqualStrings("[0.016666668,1.5,-2]", writer.buffered());
}

test "test discovery errors are emitted through the json output module" {
    var buffer: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buffer);

    try output_json.printTestDiscoveryFailureJson(&writer, "tests/projects", error.AccessDenied);

    try std.testing.expectEqualStrings(
        "{\"ok\":false,\"error\":\"AccessDenied\",\"root\":\"tests/projects\"}\n",
        writer.buffered(),
    );
}

test "test suite envelope json remains streamable" {
    var buffer: [256]u8 = undefined;
    var writer = Io.Writer.fixed(&buffer);
    const summary = TestSuiteSummary{
        .cases = 2,
        .passed_cases = 1,
        .failed_cases = 1,
        .assertions = 3,
        .failed_assertions = 1,
    };

    try output_json.printTestSuiteStartJson(&writer);
    try writer.writeAll("{\"name\":\"first\"}");
    try output_json.printTestSuiteSeparatorJson(&writer);
    try writer.writeAll("{\"name\":\"second\"}");
    try output_json.printTestSuiteEndJson(&writer, summary);

    try std.testing.expectEqualStrings(
        "{\"tests\":[{\"name\":\"first\"},{\"name\":\"second\"}],\"summary\":{\"cases\":2,\"passed\":1,\"failed\":1,\"assertions\":3,\"failed_assertions\":1},\"ok\":false}\n",
        writer.buffered(),
    );
}
