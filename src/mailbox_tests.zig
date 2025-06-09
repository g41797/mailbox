// Copyright (c) 2024 g41797
// SPDX-License-Identifier: MIT

//-----------------------------
test {
    @import("std").testing.refAllDecls(@This());
}
//-----------------------------

//-----------------------------
test "basic MailBox test" {
    const Mbx = mailbox.MailBox(u32);
    var mbox: Mbx = .{};

    try testing.expectError(error.Timeout, mbox.receive(10));

    var one = Mbx.Envelope{ .letter = 1 };
    var two = Mbx.Envelope{ .letter = 2 };
    var three = Mbx.Envelope{ .letter = 3 };
    var four = Mbx.Envelope{ .letter = 4 };
    var five = Mbx.Envelope{ .letter = 5 };

    try mbox.send(&one);
    try mbox.send(&two);
    try mbox.send(&three);
    try mbox.send(&four);
    try mbox.send(&five);

    try testing.expect(mbox.letters() == 5);

    try mbox.interrupt();
    try testing.expectError(error.Interrupted, mbox.receive(10));

    for (1..6) |i| {
        const recv = mbox.receive(1000);

        if (recv) |val| {
            try testing.expect(val.letter == i);
        } else |_| {
            try testing.expect(false);
        }
    }

    try testing.expectError(error.Timeout, mbox.receive(10));

    try mbox.interrupt();
    _ = mbox.close();
    try testing.expectError(error.Closed, mbox.receive(10));
}
//-----------------------------

//-----------------------------
test "Echo mailboxes test" {

    // Mbx is Mailbox with usize letter(data)
    const Mbx = mailbox.MailBox(usize);

    // Echo - runs on own thread
    // It has two mailboxes
    // "TO" and "FROM" - from the client point of the view
    // Receives letter via 'TO' mailbox
    // Replies letter without change (echo) to "FROM" mailbox
    const Echo = struct {
        const Self = @This();

        to: Mbx = undefined,
        from: Mbx = undefined,
        thread: Thread = undefined,

        // Mailboxes creation and start of the thread
        // Pay attention, that client code does not use
        // any thread "API" - all embedded within Echo
        pub fn start(echo: *Self) void {
            echo.to = .{};
            echo.from = .{};
            echo.thread = std.Thread.spawn(.{}, run, .{echo}) catch unreachable;
        }

        // Echo thread function
        fn run(echo: *Self) void {
            // Main loop:
            while (true) {
                // Receive - exit from the thread if mailbox was closed
                const envelope = echo.to.receive(100000000) catch break;
                // Reply to the client
                // Exit from the thread if mailbox was closed or interrupted
                _ = echo.from.send(envelope) catch break;
            }
        }

        // Wait exit from the thread
        pub fn waitFinish(echo: *Self) void {
            echo.thread.join();
        }

        // Close mailboxes
        // As result Echo should stop processing
        // and exit from the thread.
        pub fn stop(echo: *Self) !void {
            _ = echo.to.close();
            _ = echo.from.close();
        }
    };

    var echo = try std.testing.allocator.create(Echo);

    // Start Echo(on own thread)
    echo.start();

    defer {
        // Wait finish of Echo
        echo.waitFinish();
        std.testing.allocator.destroy(echo);
    }

    // because nothing was send to 'TO' mailbox, nothing should be received
    // from 'FROM' mailbox
    try testing.expectError(error.Timeout, echo.from.receive(100));

    // Create wrapper for the data
    const envl = try std.testing.allocator.create(Mbx.Envelope);
    defer std.testing.allocator.destroy(envl);

    // Send/Receive loop
    for (0..6) |indx| {
        // Set value for send [0-5]
        envl.letter = indx;

        // Send to 'TO' mailbox
        try echo.to.send(envl);

        // Wait received data from OUT mailbox
        const back = echo.from.receive(1000000);

        if (back) |val| {
            // Expected value == index [0-5]
            try testing.expect(val.letter == indx);
        } else |_| {
            try testing.expect(false);
        }
    }

    // Stop Echo
    try echo.stop();
}
//  defered:
//      Wait finish of Echo
//          echo.waitFinish();
//      Free allocated memory:
//          std.testing.allocator.destroy(echo);
//          std.testing.allocator.destroy(envl);
//-----------------------------

test "compilation MailBoxIntrusive test" {
    const Mbx = mailbox.MailBoxIntrusive(MsgU32);
    var mbox: Mbx = .{};
    try testing.expectError(error.Timeout, mbox.receive(10));

    try mbox.interrupt();
    try testing.expectError(error.Interrupted, mbox.receive(10));
}

const MsgU32 = struct {
    prev: ?*MsgU32 = null,
    next: ?*MsgU32 = null,
    stuff: u32 = undefined,
};

const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const mailbox = @import("mailbox.zig");
