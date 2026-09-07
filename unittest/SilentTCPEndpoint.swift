//
//  SilentTCPEndpoint.swift
//  mailcore2
//
//  Shared test helper.
//

// Darwin only, like the tests that use it: it needs a POSIX listening socket, and the Android job
// builds the test target without running it.
#if canImport(Darwin)

import Darwin
import Dispatch
import Foundation

/// A TCP endpoint that accepts connections and never answers a command.
///
/// Without a greeting, a client sits in its first read until the socket timeout expires - so a
/// command sent here can only end by being interrupted, which makes both interruption and queue
/// occupancy observable in a test. With a greeting, an IMAP connect completes (embed the
/// capabilities in the banner so the client does not follow up with a CAPABILITY command) and the
/// connection then idles, which makes disconnect behavior observable: mailcore tears a connection
/// down by closing the socket, reported here through waitForClientDisconnect().
final class SilentTCPEndpoint {

    private let listeningSocket: Int32
    private let greeting: String?
    private let acceptQueue = DispatchQueue(label: "SilentTCPEndpoint.accept")
    private let lock = NSLock()
    private var acceptedSockets: [Int32] = []
    private var openClientCount = 0
    private var everAcceptedClient = false
    private var isClosed = false

    let port: UInt16

    /// Pass an IMAP banner (e.g. "* OK [CAPABILITY IMAP4rev1] ready\r\n") to let connects finish;
    /// pass nil to stay silent so that every command blocks.
    init(greeting: String? = nil) throws {
        self.greeting = greeting

        // Everything below works on a local descriptor: a closure that touched `listeningSocket`
        // would capture self before `port` is initialized.
        let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw NSError(domain: "SilentTCPEndpoint", code: Int(errno), userInfo: nil)
        }

        var reuse: Int32 = 1
        setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0 // any free port
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bound = withUnsafePointer(to: &address) { pointer -> Int32 in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                return bind(fileDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bound == 0, listen(fileDescriptor, 8) == 0 else {
            close(fileDescriptor)
            throw NSError(domain: "SilentTCPEndpoint", code: Int(errno), userInfo: nil)
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &boundAddress) { pointer -> Int32 in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                return getsockname(fileDescriptor, sockaddrPointer, &length)
            }
        }

        guard named == 0 else {
            close(fileDescriptor)
            throw NSError(domain: "SilentTCPEndpoint", code: Int(errno), userInfo: nil)
        }

        listeningSocket = fileDescriptor
        port = UInt16(bigEndian: boundAddress.sin_port)

        acceptQueue.async { [weak self] in
            self?.acceptConnections()
        }
    }

    private func acceptConnections() {
        while true {
            let accepted = accept(listeningSocket, nil, nil)
            guard accepted >= 0 else {
                return // the listening socket was closed
            }

            lock.lock()
            let closed = isClosed
            if closed {
                lock.unlock()
                Darwin.close(accepted)
                return
            }
            acceptedSockets.append(accepted)
            openClientCount += 1
            everAcceptedClient = true
            lock.unlock()

            if let greeting = greeting {
                greeting.utf8CString.withUnsafeBufferPointer { buffer in
                    // -1 for the terminating NUL of a CString; loop out partial writes
                    var sent = 0
                    let total = buffer.count - 1
                    while sent < total {
                        let written = send(accepted, buffer.baseAddress! + sent, total - sent, 0)
                        guard written > 0 else {
                            return
                        }
                        sent += written
                    }
                }
            }

            // Incoming commands are read and discarded - never answered - so EOF, i.e. the client
            // closing its socket, is the only thing this loop reports. The reader owns the
            // descriptor: closing it from stop() while recv() blocks on it would let the fd
            // number be reused and the loop read somebody else's descriptor; stop() only
            // shuts the socket down, which wakes recv(), and the close happens here.
            DispatchQueue.global().async { [weak self] in
                var buffer = [UInt8](repeating: 0, count: 1024)
                while recv(accepted, &buffer, buffer.count, 0) > 0 {
                }
                Darwin.close(accepted)
                guard let self = self else {
                    return
                }
                self.lock.lock()
                self.openClientCount -= 1
                self.lock.unlock()
            }
        }
    }

    /// Waits until at least one client was accepted and every accepted client has closed its
    /// socket. Returns false when clients are still connected after the timeout.
    func waitForClientDisconnect(timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            lock.lock()
            let disconnected = everAcceptedClient && openClientCount == 0
            lock.unlock()
            if disconnected {
                return true
            }
            usleep(50_000)
        }
        return false
    }

    func stop() {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            return
        }
        isClosed = true
        let sockets = acceptedSockets
        acceptedSockets = []
        lock.unlock()

        // shutdown() wakes the blocked accept()/recv() calls without invalidating the fd
        // numbers under them; each descriptor is then closed by the thread that owns it
        // (accepted sockets by their readers, the listening one right here after the wakeup).
        shutdown(listeningSocket, SHUT_RDWR)
        Darwin.close(listeningSocket)
        for accepted in sockets {
            shutdown(accepted, SHUT_RDWR)
        }
    }
}

#endif
