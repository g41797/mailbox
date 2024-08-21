![](_logo/mailboxes.png)

# An implementation of Mailbox abstraction in Zig          

[![CI](https://github.com/g41797/yazq/actions/workflows/ci.yml/badge.svg)](https://github.com/g41797/yazq/actions/workflows/ci.yml)

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
> **iRMX 86™ NUCLEUS REFERENCE MANUAL** _Copyright @ 1980, 1981 Intel Corporation_


