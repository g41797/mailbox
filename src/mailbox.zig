// Copyright (c) 2025 g41797
// SPDX-License-Identifier: MIT

pub fn MailBox(comptime Letter: type) type {
    return struct {
        const Self = @This();

        /// Envelope inside FIFO wrapping the actual letter.
        pub const Envelope = struct {
            prev: ?*Envelope = null,
            next: ?*Envelope = null,
            letter: Letter,
        };

        first: ?*Envelope = null,
        last: ?*Envelope = null,
        len: usize = 0,
        closed: bool = false,
        mutex: Mutex = .{},
        cond: Condition = .{},
        interrupted: bool = false,

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

        /// Wake-up waiting on receive thread.
        /// If mailbox was closed - returns error.Closed
        /// If waiting was already interrupted -  - returns error.AlreadyInterrupted
        pub fn interrupt(mbox: *Self) error{ Closed, AlreadyInterrupted }!void {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) {
                return error.Closed;
            }

            if (mbox.interrupted) {
                return error.AlreadyInterrupted;
            }

            mbox.interrupted = true;

            mbox.cond.signal();
        }

        /// Blocks thread  maximum timeout_ns till Envelope in head of FIFO will be available.
        /// If not available - returns error.Timeout.
        /// Otherwise removes Envelope from the head and returns it to the caller.
        /// If mailbox was closed - returns error.Closed
        /// If interrupt was issued - returns error.Interrupted
        pub fn receive(mbox: *Self, timeout_ns: u64) error{ Timeout, Closed, Interrupted }!*Envelope {
            var timeout_timer = std.time.Timer.start() catch unreachable;

            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            while (mbox.len == 0) {
                if (mbox.closed) {
                    return error.Closed;
                }

                if (mbox.interrupted) {
                    mbox.interrupted = false;
                    return error.Interrupted;
                }

                const elapsed = timeout_timer.read();
                if (elapsed > timeout_ns)
                    return error.Timeout;

                const local_timeout_ns = timeout_ns - elapsed;
                try mbox.cond.timedWait(&mbox.mutex, local_timeout_ns);
            }

            if (mbox.closed) {
                return error.Closed;
            }

            if (mbox.interrupted) {
                mbox.interrupted = false;
                return error.Interrupted;
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
        pub fn close(mbox: *Self) ?*Envelope {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) return null;

            mbox.closed = true;
            mbox.interrupted = false;

            const head = mbox.first;

            mbox.first = null;

            mbox.cond.signal();

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

pub fn MailBoxIntrusive(comptime Envelope: type) type {
    return struct {
        const Self = @This();

        /// Envelope has following structure
        /// in order to be intrusive
        /// pub const T = struct {
        ///     prev: ?*T = null,
        ///     next: ?*T = null,
        ///     additional stuff
        /// };
        first: ?*Envelope = null,
        last: ?*Envelope = null,
        len: usize = 0,
        closed: bool = false,
        mutex: Mutex = .{},
        cond: Condition = .{},
        interrupted: bool = false,

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

        /// Wake-up waiting on receive thread.
        /// If mailbox was closed - returns error.Closed
        /// If waiting was already interrupted -  - returns error.AlreadyInterrupted
        pub fn interrupt(mbox: *Self) error{ Closed, AlreadyInterrupted }!void {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) {
                return error.Closed;
            }

            if (mbox.interrupted) {
                return error.AlreadyInterrupted;
            }

            mbox.interrupted = true;

            mbox.cond.signal();
        }

        /// Blocks thread  maximum timeout_ns till Envelope in head of FIFO will be available.
        /// If not available - returns error.Timeout.
        /// Otherwise removes Envelope from the head and returns it to the caller.
        /// If mailbox was closed - returns error.Closed
        /// If interrupt was issued - returns error.Interrupted
        pub fn receive(mbox: *Self, timeout_ns: u64) error{ Timeout, Closed, Interrupted }!*Envelope {
            var timeout_timer = std.time.Timer.start() catch unreachable;

            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            while (mbox.len == 0) {
                if (mbox.closed) {
                    return error.Closed;
                }

                if (mbox.interrupted) {
                    mbox.interrupted = false;
                    return error.Interrupted;
                }

                const elapsed = timeout_timer.read();
                if (elapsed > timeout_ns)
                    return error.Timeout;

                const local_timeout_ns = timeout_ns - elapsed;
                try mbox.cond.timedWait(&mbox.mutex, local_timeout_ns);
            }

            if (mbox.closed) {
                return error.Closed;
            }

            if (mbox.interrupted) {
                mbox.interrupted = false;
                return error.Interrupted;
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
        pub fn close(mbox: *Self) ?*Envelope {
            mbox.mutex.lock();
            defer mbox.mutex.unlock();

            if (mbox.closed) return null;

            mbox.closed = true;

            const head = mbox.first;

            mbox.first = null;

            mbox.cond.signal();

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

const std = @import("std");
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
