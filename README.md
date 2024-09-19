![](_logo/mailboxes.png)

# An implementation of Mailbox abstraction in Zig          

[![CI](https://github.com/g41797/yazq/actions/workflows/ci.yml/badge.svg)](https://github.com/g41797/yazq/actions/workflows/ci.yml)

> Mailboxes are one of the fundamental parts of the [actor model originated in **1973**](https://en.wikipedia.org/wiki/Actor_model). 
>
> Through the mailbox mechanism, actors can decouple the reception of a message from its elaboration.
>
> An actor is an object that carries out its actions in response to communications it receives.
>
> A mailbox is nothing more than the data structure (FIFO) that holds messages.
>
> If you send 3 messages to the same actor, it will just execute one at a time.

Useful links for interested:
- [Huan Mailbox](https://github.com/huan/mailbox)
- [Typed Mailboxes in Scala](https://www.baeldung.com/scala/typed-mailboxes)
- [Actors have mailboxes](https://www.brianstorti.com/the-actor-model/)


I first encountered MailBox in the late 80s while working om a real-time system: 

> "A **mailbox** is one of two types of objects that can be used for intertask
communication. When task A wants to send an object to task B, task A
must send the object to the mailbox, and task B must visit the mailbox,
where, if an object isn't there, it has the option of waiting for any
desired length of time. Sending an object in this manner can achieve
various purposes. The object might be a segment that contains data
needed by the waiting task. On the other hand, the segment might be
blank, and sending it might constitute a signal to the waiting task.
Another reason to send an object might be to point out the object to the
receiving task." 
> **iRMX 86™ NUCLEUS REFERENCE MANUAL** _Copyright @ 1980, 1981 Intel Corporation.

Since than I have used it in:
- iRMX      - *PL/M-86*
- AIX       - *C*
- Windows   - *C++/C#*
- Linux     - *Golang*

**Now it's time for Zig**


## Example of in-proc Echo "server"

```zig
    // Mbx is Mailbox with usize letter(data)
    const Mbx = MailBox(usize);

    // Echo "server" - runs on own thread
    // Receives letter via 'TO' mailbox
    // Send letter without change (echo) to "FROM" mailbox
    // "TO"/"FROM" - from the client point of the view
    const Echo = struct {
        const Self = @This();

        to: Mbx = undefined,
        from: Mbx = undefined,
        thread: Thread = undefined,

        // Mailboxes creation and start of the thread
        pub fn start(echo: *Self) void {
            echo.to = Mbx.open();
            echo.from = Mbx.open();
            echo.thread = std.Thread.spawn(.{}, run, .{echo}) catch unreachable;
        }

        // Thread function
        fn run(echo: *Self) void {
            // Main loop:
            while (true) {
                // Receive - exit from the thread if mailbox was closed
                const envelope = echo.to.receive(100000000) catch break;
                // Send  - exit from the thread if mailbox was closed
                _ = echo.from.send(envelope) catch break;
            }
        }

        // Wait exit from the thread
        pub fn waitFinish(echo: *Self) void {
            echo.thread.join();
        }

        // Close mailboxes
        // As result Echo "server" should stop processing
        // and exit from the thread.
        pub fn stop(echo: *Self) !void {
            _ = try echo.to.close();
            _ = try echo.from.close();
        }
    };

    // Echo "client" code:
    var echo = try std.testing.allocator.create(Echo);

    // Start Echo "server" on own thread
    echo.start();

    defer {
        // Wait finish of the thread
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
        envl.*.letter = indx;

        // Send to 'TO' mailbox
        try echo.to.send(envl);

        // Wait received data from OUT mailbox
        const back = echo.from.receive(1000000);

        if (back) |val| {
            // Expected value == index [0-5]
            try testing.expect(val.*.letter == indx);
        } else |_| {
            try testing.expect(false);
        }
    }

    // Stop Echo "server"
    try echo.stop();
}
//  defered:
//      Wait finish of the thread
//          echo.waitFinish();
//      Free allocated memory:
//          std.testing.allocator.destroy(echo);
//          std.testing.allocator.destroy(envl);
```

## Installation

Add dependency to build.zig.zon:
```bash
zig fetch --save-exact  https://github.com/g41797/mailbox/archive/master.tar.gz
```

Add to build.zig:
```zig
exe.addModule("mailbox", b.dependency("mailbox", .{}).module("mailbox"));
```

## Contributing

Feel free to report bugs and suggest improvements.

## License

[MIT](LICENSE)




