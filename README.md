![](_logo/mailboxes.png)

# Mailbox - the best way for inter-thread communication.          

[![CI](https://github.com/g41797/yazq/actions/workflows/ci.yml/badge.svg)](https://github.com/g41797/yazq/actions/workflows/ci.yml)

## A bit of history, a bit of theory

Mailboxes are one of the fundamental parts of the [actor model originated in **1973**](https://en.wikipedia.org/wiki/Actor_model): 
> An actor is an object that carries out its actions in response to communications it receives.
> Through the mailbox mechanism, actors can decouple the reception of a message from its elaboration.
> A mailbox is nothing more than the data structure (FIFO) that holds messages.

I first encountered MailBox in the late 80s while working om a real-time system: 
> "A **mailbox** is object that can be used for inter-task
communication. When task A wants to send an object to task B, task A
must send the object to the mailbox, and task B must visit the mailbox,
where, if an object isn't there, it has the option of *waiting for any
desired length of time*..." 
> **iRMX 86™ NUCLEUS REFERENCE MANUAL** _Copyright @ 1980, 1981 Intel Corporation.

Since than I have used it in:
- iRMX      - *PL/M-86*
- AIX       - *C*
- Windows   - *C++/C#*
- Linux     - *Golang*

**Now it's Zig time**

## Why?
If your thread runs in "Fire and Forget" mode, you don't need Mailbox.
But in the real multithreaded application, threads communicate with each other as
members of work team.

**Mailbox** provides convenient and simple communication mechanism.
Just try:
- without it
- with it

## Example of usage - 'Echo' 
```zig
    // Mbx is Mailbox with usize letter(data)
    const Mbx = MailBox(usize);

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
                // Exit from the thread if mailbox was closed
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
            _ = try echo.to.close();
            _ = try echo.from.close();
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

    // Stop Echo
    try echo.stop();
```

## Boring details

Mailbox of *[]const u8* 'Letters':
```zig
const Rumors = MailBox([]const u8);
const rmrsMbx : Rumors = .{};
```

**Envelope** is wrapper of actual user defined type **Letter**.
```zig
        pub const Envelope = struct {
            prev: ?*Envelope = null,
            next: ?*Envelope = null,
            letter: Letter,
        };
```
In fact Mailbox is queue(FIFO) of Envelope(s).

MailBox supports following operations:
- send *Envelope* to MailBox (*enqueue*) and wakeup waiting receivers
- receive *Envelope* from Mailbox (*dequeue*) with time-out
- close Mailbox:
  - disables further operations
  - first close returns List of non-processed *Envelope(s)* for free/reuse etc.

Feel free to suggest improvements in doc and code.



## License
[MIT](LICENSE)

## Installation
You finally got to installation:
- add dependency to build.zig.zon
```bash
zig fetch --save-exact  https://github.com/g41797/mailbox/archive/master.tar.gz
```
- add to build.zig:
```zig
exe.addModule("mailbox", b.dependency("mailbox", .{}).module("mailbox"));
```

**Stop reading and start playing!**

## Last warning
First rule of multithreading:
>**If you can do without multithreading - do without.**
 




