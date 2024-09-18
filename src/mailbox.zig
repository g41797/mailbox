//-----------------------------
const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;

const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
//-----------------------------

pub fn MailBox(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Envelope inside FIFO wrapping the actual letter.
        pub const Envelope = struct {
            prev: ?*Envelope = null,
            next: ?*Envelope = null,
            letter: T,
        };

        first: ?*Envelope = null,
        last: ?*Envelope = null,
        len: usize = 0,
        closed: bool = true,
        mutex: Mutex = .{},
        cond: Condition = .{},

        /// Set mailbox to ready mode
        pub fn open() Self { // Add alloc: std.mem.Allocator
            return Self{
                .closed = false,
            };
        }

        /// Append a new Envelope to the tail
        /// and wake-up waiting on receive threads.
        /// Arguments:
        ///     new_Envelope: Pointer to the new Envelope to append.
        /// If mailbox was closed - returns error.Closed
        pub fn send(mbox: *Self, new_Envelope: *Envelope) error{Closed}!void {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) {
                return error.Closed;
            }

            mbox.enqueue(new_Envelope);

            mbox.cond.signal();
        }

        /// Blocks thread  maximum timeout_ns till Envelope in head of FIFO will be available.
        /// If not available - returns error.Timeout.
        /// Otherwise removes Envelope from the head and returns it to the caller.
        /// If mailbox was closed - returns error.Closed
        pub fn receive(mbox: *Self, timeout_ns: u64) error{ Timeout, Closed }!*Envelope {
            var timeout_timer = std.time.Timer.start() catch unreachable;

            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) {
                return error.Closed;
            }

            while (mbox.len == 0) {
                const elapsed = timeout_timer.read();
                if (elapsed > timeout_ns)
                    return error.Timeout;

                const local_timeout_ns = timeout_ns - elapsed;
                try mbox.cond.timedWait(&mbox.mutex, local_timeout_ns);
            }

            const first = mbox.dequeue();

            if (first) |firstEnvelope| {
                defer mbox.cond.signal();
                return firstEnvelope;
            } else {
                return error.Timeout;
            }
        }

        /// # of letters in internal queue.
        /// May be called also on closed mailbox.
        pub fn letters(mbox: *Self) usize {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            return mbox.len;
        }

        /// First close disabled further client calls and returns head of Envelopes
        /// for de-allocation
        pub fn close(mbox: *Self) error{Closed}!?*Envelope {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) {
                return error.Closed;
            }

            mbox.closed = true;

            const head = mbox.first;

            mbox.first = null;

            return head;
        }

        fn enqueue(fifo: *Self, new_Envelope: *Envelope) void {
            new_Envelope.prev = null;
            new_Envelope.next = null;

            if (fifo.last) |last| {
                last.next = new_Envelope;
                new_Envelope.prev = last;
            } else {
                fifo.first = new_Envelope;
            }

            fifo.last = new_Envelope;
            fifo.len += 1;

            return;
        }

        fn dequeue(fifo: *Self) ?*Envelope {
            if (fifo.len == 0) {
                return null;
            }

            var result = fifo.first;
            fifo.first = result.?.next;

            if (fifo.len == 1) {
                fifo.last = null;
            } else {
                fifo.first.?.prev = fifo.first;
            }

            result.?.prev = null;
            result.?.next = null;
            fifo.len -= 1;

            return result;
        }
    };
}

test "basic MailBox test" {
    const M = MailBox(u32);
    var mbox = M.open();

    try testing.expectError(error.Timeout, mbox.receive(10));

    var one = M.Envelope{ .letter = 1 };
    var two = M.Envelope{ .letter = 2 };
    var three = M.Envelope{ .letter = 3 };
    var four = M.Envelope{ .letter = 4 };
    var five = M.Envelope{ .letter = 5 };

    try mbox.send(&one);
    try mbox.send(&two);
    try mbox.send(&three);
    try mbox.send(&four);
    try mbox.send(&five);

    try testing.expect(mbox.letters() == 5);

    for (1..6) |i| {
        const recv = mbox.receive(100);

        if (recv) |val| {
            try testing.expect(val.*.letter == i);
        } else |_| {
            try testing.expect(false);
        }
    }

    try testing.expectError(error.Timeout, mbox.receive(10));

    _ = try mbox.close();
    try testing.expectError(error.Closed, mbox.receive(10));
}
