//-----------------------------
const std       = @import("std");
const builtin   = @import("builtin");
const debug     = std.debug;
const assert = debug.assert;
const testing   = std.testing;

const Mutex     = std.Thread.Mutex;
const Condition = std.Thread.Condition;
//-----------------------------

pub fn MailBox(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Envelope inside the linked list wrapping the actual letter.
        pub const Envelope = struct {
            prev:   ?*Envelope = null,
            next:   ?*Envelope = null,
            letter: T,
        };

        first:  ?*Envelope = null,
        last:   ?*Envelope = null,
        len:    usize = 0,
        mutex:  Mutex = .{},
        cond:   Condition = .{},

        pub fn send(mbox: *Self, new_Envelope: *Envelope) void {

            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            mbox.push(new_Envelope);

            mbox.cond.signal();
        }

        pub fn receive(mbox: *Self, timeout_ns: u64) error{Timeout}!*Envelope {

            var timeout_timer = std.time.Timer.start() catch unreachable;

            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            while (mbox.len == 0) {
                const elapsed = timeout_timer.read();
                if (elapsed > timeout_ns)
                    return error.Timeout;

                const local_timeout_ns = timeout_ns - elapsed;
                try mbox.cond.timedWait(&mbox.mutex, local_timeout_ns);
            }

            const last = mbox.last;

            if (mbox.len > 0) {
                defer mbox.cond.signal();
            }

            if (last) |lastEnvelope| {
                    mbox.remove(lastEnvelope);
                    return lastEnvelope;
            } else {
                return error.Timeout;
            }
        }

        /// Insert a new Envelope at the beginning of the list.
        ///
        /// Arguments:
        ///     new_Envelope: Pointer to the new Envelope to insert.
        fn push(list: *Self, new_Envelope: *Envelope) void {
            if (list.first) |first| {
                // Insert before first.
                list.insertBefore(first, new_Envelope);
            } else {
                // Empty list.
                list.first = new_Envelope;
                list.last = new_Envelope;
                new_Envelope.prev = null;
                new_Envelope.next = null;

                list.len = 1;
            }
        }

        /// Remove a Envelope from the list.
        ///
        /// Arguments:
        ///     Envelope: Pointer to the Envelope to be removed.
        fn remove(list: *Self, envelope: *Envelope) void {
            if (envelope.prev) |prev_Envelope| {
                // Intermediate Envelope.
                prev_Envelope.next = envelope.next;
            } else {
                // First element of the list.
                list.first = envelope.next;
            }

            if (envelope.next) |next_Envelope| {
                // Intermediate Envelope.
                next_Envelope.prev = envelope.prev;
            } else {
                // Last element of the list.
                list.last = envelope.prev;
            }

            list.len -= 1;
            assert(list.len == 0 or (list.first != null and list.last != null));
        }

        /// Insert a new Envelope before an existing one.
        ///
        /// Arguments:
        ///     Envelope: Pointer to a Envelope in the list.
        ///     new_Envelope: Pointer to the new Envelope to insert.
        fn insertBefore(list: *Self, envelope: *Envelope, new_Envelope: *Envelope) void {
            new_Envelope.next = envelope;
            if (envelope.prev) |prev_Envelope| {
                // Intermediate Envelope.
                new_Envelope.prev = prev_Envelope;
                prev_Envelope.next = new_Envelope;
            } else {
                // First element of the list.
                new_Envelope.prev = null;
                list.first = new_Envelope;
            }
            envelope.prev = new_Envelope;

            list.len += 1;
        }
    };
}

test "basic MailBox test" {
    const M = MailBox(u32);
    var mbox = M{};

    try testing.expectError(error.Timeout, mbox.receive(10));

    var one     = M.Envelope{ .letter = 1 };
    var two     = M.Envelope{ .letter = 2 };
    var three   = M.Envelope{ .letter = 3 };
    var four    = M.Envelope{ .letter = 4 };
    var five    = M.Envelope{ .letter = 5 };

    mbox.send(&one);
    mbox.send(&two);
    mbox.send(&three);
    mbox.send(&four);
    mbox.send(&five);

    try testing.expect(mbox.len == 5);

    for (1..6) |i| {
        const recv = mbox.receive(100);

        if ( recv ) |val| {
            try testing.expect(val.*.letter == i);
        } else |_| {
            try testing.expect(false);
        }
    }

    try testing.expectError(error.Timeout, mbox.receive(10));
}
