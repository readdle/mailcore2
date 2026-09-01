//
//  IMAPInterruptCurrentCommandTests.swift
//  mailcore2
//
//  Tests for IMAPOperation::interruptCurrentCommand().
//

// Darwin only: the tests need a POSIX listening socket, and the Android job builds the test target
// without running it. Nothing here is platform-specific beyond that socket.
#if canImport(Darwin)

import Darwin
import Dispatch
import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

/// A TCP endpoint that accepts connections and then says nothing at all. A client connected to it
/// sits in its first read until the socket timeout expires - exactly the state that
/// `interruptCurrentCommand()` has to break, and reproducible without an IMAP server.
private final class SilentTCPEndpoint {

    private let listeningSocket: Int32
    private let acceptQueue = DispatchQueue(label: "SilentTCPEndpoint.accept")
    private let lock = NSLock()
    private var acceptedSockets: [Int32] = []
    private var isClosed = false

    let port: UInt16

    init() throws {
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

            // Held open and silent on purpose.
            lock.lock()
            let closed = isClosed
            if closed {
                lock.unlock()
                Darwin.close(accepted)
                return
            }
            acceptedSockets.append(accepted)
            lock.unlock()
        }
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

        Darwin.close(listeningSocket)
        for accepted in sockets {
            Darwin.close(accepted)
        }
    }
}

final class IMAPInterruptCurrentCommandTests: XCTestCase {

    /// Well above every wait below: a command left to its own devices must not be able to finish on
    /// its own and pass a test that is about being interrupted.
    private let sessionTimeout: TimeInterval = 60

    private func makeSession(port: UInt16) -> MCOIMAPSession {
        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(port)
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.timeout = sessionTimeout
        session.maximumConnections = 1
        return session
    }

    /// Runs the test body off the main thread while the main thread keeps spinning its run loop.
    /// mailcore hands parts of an operation's lifecycle to the main queue and waits for them, so a
    /// test that blocks the main thread never gets its operation started in the first place.
    private func runOffMainThread(timeout: TimeInterval, _ body: @escaping () -> Void) {
        let finished = expectation(description: "test body")

        DispatchQueue.global(qos: .userInitiated).async {
            body()
            finished.fulfill()
        }

        waitForExpectations(timeout: timeout)
    }

    private func start(_ operation: MCOIMAPOperation) -> DispatchSemaphore {
        let finished = DispatchSemaphore(value: 0)
        operation.start { _ in
            finished.signal()
        }
        return finished
    }

    func testInterruptEndsTheWaitOfTheRunningCommand() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            let finished = self.start(operation)

            // The endpoint accepts the connection and stays silent, so the command is stuck reading
            // the greeting.
            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The command was expected to be blocked on the socket")

            XCTAssertTrue(operation.interruptCurrentCommand(),
                          "The running operation was expected to report that it interrupted a command")

            // Left alone this would return only when the 60s socket timeout expires.
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success,
                           "interruptCurrentCommand() did not unblock the running command")
        }
    }

    func testInterruptDoesNothingForAnOperationThatIsNotRunning() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 60) {
            // One connection, so the second operation waits in the queue while the first one blocks.
            let running = session.connectOperation()
            let runningFinished = self.start(running)

            XCTAssertEqual(runningFinished.wait(timeout: .now() + 2), .timedOut,
                           "The first command was expected to be blocked on the socket")

            let queued = session.noopOperation()
            let queuedFinished = self.start(queued)

            // The queued operation owns no connection, so interrupting on its behalf must not touch
            // the stream the running one is blocked on.
            XCTAssertFalse(queued.interruptCurrentCommand(),
                           "A queued operation has no command of its own to interrupt")

            XCTAssertEqual(runningFinished.wait(timeout: .now() + 3), .timedOut,
                           "A queued operation must not interrupt the command of the running one")

            // ... while the running operation can still be interrupted itself.
            XCTAssertTrue(running.interruptCurrentCommand(),
                          "The running operation was expected to report that it interrupted a command")

            XCTAssertEqual(runningFinished.wait(timeout: .now() + 10), .success,
                           "interruptCurrentCommand() did not unblock the running command")
            XCTAssertEqual(queuedFinished.wait(timeout: .now() + 10), .success,
                           "The queued operation was expected to finish once the connection was freed")
        }
    }
}

#endif
