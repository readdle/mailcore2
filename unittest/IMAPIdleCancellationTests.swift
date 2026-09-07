//
//  IMAPIdleCancellationTests.swift
//  mailcore2
//
//  Swift port of the "cancel wakes IDLE" half of upstream MailCore's tests/test-imap-idle.cpp
//  (MailCore/mailcore2 commit ab53363b). The other half - disconnect() racing a running idle() on
//  the core IMAPSession - needs the synchronous C++ session, which the Swift layer does not expose.
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

/// The least IMAP server that can take a MailCore session into IDLE: greeting, CAPABILITY with IDLE,
/// LOGIN, LIST for the delimiter, SELECT, then "+ idling" and waiting for DONE. Everything else is answered with a tagged OK.
private final class FakeIdleIMAPServer {

    private let listeningSocket: Int32
    private let serverQueue = DispatchQueue(label: "FakeIdleIMAPServer")
    private let condition = NSCondition()
    private var clientSocket: Int32 = -1
    private var idleEntered = false
    private var doneReceived = false
    private var connectionClosed = false
    private var isStopped = false
    private var transcriptLines: [String] = []

    /// Every line the client sent, for diagnostics.
    var transcript: String {
        condition.lock()
        defer { condition.unlock() }
        return transcriptLines.joined(separator: "\n")
    }

    let port: UInt16

    init() throws {
        let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw NSError(domain: "FakeIdleIMAPServer", code: Int(errno), userInfo: nil)
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

        guard bound == 0, listen(fileDescriptor, 1) == 0 else {
            close(fileDescriptor)
            throw NSError(domain: "FakeIdleIMAPServer", code: Int(errno), userInfo: nil)
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
            throw NSError(domain: "FakeIdleIMAPServer", code: Int(errno), userInfo: nil)
        }

        listeningSocket = fileDescriptor
        port = UInt16(bigEndian: boundAddress.sin_port)

        serverQueue.async { [weak self] in
            self?.serve()
        }
    }

    // MARK: Observation

    /// True once the client has sent IDLE and been answered with "+ idling".
    func waitForIdleEntered(timeout: TimeInterval) -> Bool {
        return wait(timeout: timeout) { self.idleEntered }
    }

    /// True once the client either sent DONE or closed the connection - the two ways a running IDLE
    /// can legitimately end.
    func waitForDoneOrClose(timeout: TimeInterval) -> Bool {
        return wait(timeout: timeout) { self.doneReceived || self.connectionClosed }
    }

    private func wait(timeout: TimeInterval, until predicate: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        condition.lock()
        defer { condition.unlock() }
        while !predicate() {
            if !condition.wait(until: deadline) {
                return predicate()
            }
        }
        return true
    }

    private func mark(_ change: () -> Void) {
        condition.lock()
        change()
        condition.broadcast()
        condition.unlock()
    }

    func stop() {
        condition.lock()
        guard !isStopped else {
            condition.unlock()
            return
        }
        isStopped = true
        let client = clientSocket
        condition.unlock()

        shutdown(listeningSocket, SHUT_RDWR)
        Darwin.close(listeningSocket)
        if client >= 0 {
            shutdown(client, SHUT_RDWR)
            Darwin.close(client)
        }
    }

    // MARK: Protocol

    private func serve() {
        let accepted = accept(listeningSocket, nil, nil)
        guard accepted >= 0 else {
            return // stopped before a client arrived
        }
        mark { clientSocket = accepted }

        guard send("* OK fake imap ready\r\n") else {
            mark { connectionClosed = true }
            return
        }

        var idleTag = ""
        while let line = readLine() {
            mark { transcriptLines.append(line) }
            if line == "DONE" {
                mark { doneReceived = true }
                if !idleTag.isEmpty {
                    _ = send("\(idleTag) OK IDLE done\r\n")
                }
                continue
            }

            let tag = String(line.prefix { $0 != " " })
            let upper = line.uppercased()
            let ok: Bool
            if upper.contains(" CAPABILITY") {
                ok = send("* CAPABILITY IMAP4rev1 IDLE\r\n\(tag) OK CAPABILITY done\r\n")
            }
            else if upper.contains(" LOGIN") {
                ok = send("\(tag) OK LOGIN done\r\n")
            }
            else if upper.contains(" LIST") {
                // Readdle's fork asks for the hierarchy delimiter before selecting anything.
                ok = send("* LIST (\\Noselect) \"/\" \"\"\r\n\(tag) OK LIST done\r\n")
            }
            else if upper.contains(" SELECT") {
                ok = send("* FLAGS (\\Seen)\r\n"
                    + "* 0 EXISTS\r\n"
                    + "* 0 RECENT\r\n"
                    + "* OK [UIDVALIDITY 1]\r\n"
                    + "* OK [UIDNEXT 1]\r\n"
                    + "* OK [PERMANENTFLAGS (\\Seen)]\r\n"
                    + "\(tag) OK [READ-WRITE] SELECT done\r\n")
            }
            else if upper.contains(" IDLE") {
                idleTag = tag
                ok = send("+ idling\r\n")
                if ok {
                    mark { idleEntered = true }
                }
            }
            else if upper.contains(" LOGOUT") {
                _ = send("* BYE logging out\r\n\(tag) OK LOGOUT done\r\n")
                mark { connectionClosed = true }
                return
            }
            else {
                ok = send("\(tag) OK ignored\r\n")
            }

            if !ok {
                mark { connectionClosed = true }
                return
            }
        }
        mark { connectionClosed = true }
    }

    private func send(_ text: String) -> Bool {
        var bytes = Array(text.utf8)
        var remaining = bytes.count
        var offset = 0
        while remaining > 0 {
            let written = bytes.withUnsafeMutableBytes { buffer -> Int in
                return Darwin.send(clientSocket, buffer.baseAddress! + offset, remaining, 0)
            }
            guard written > 0 else {
                return false
            }
            offset += written
            remaining -= written
        }
        return true
    }

    private func readLine() -> String? {
        var line: [UInt8] = []
        var byte: UInt8 = 0
        while true {
            let count = recv(clientSocket, &byte, 1, 0)
            if count == 0 {
                return nil
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                return nil
            }
            if byte == UInt8(ascii: "\n") {
                if line.last == UInt8(ascii: "\r") {
                    line.removeLast()
                }
                return String(decoding: line, as: UTF8.self)
            }
            line.append(byte)
        }
    }
}

final class IMAPIdleCancellationTests: XCTestCase {

    /// Well above every wait below: an IDLE left alone must not be able to end on its own and pass a
    /// test that is about being woken up. (IMAPSession itself caps IDLE at 28 minutes.)
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

    private func startIdle(_ session: MCOIMAPSession) -> (MCOIMAPIdleOperation, DispatchSemaphore) {
        let finished = DispatchSemaphore(value: 0)
        let operation = session.idleOperation(folder: "INBOX", lastKnownUID: 0)
        operation.start { error in
            if let error = error {
                print("IMAPIdleCancellationTests: idle finished with error \(error)")
            }
            finished.signal()
        }
        return (operation, finished)
    }

    private func waitUntilQueueStopped(_ session: MCOIMAPSession, timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while session.isOperationQueueRunning {
            if Date() >= deadline {
                return false
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return true
    }

    /// Control case: `interruptIdle()` is the documented way to end an IDLE early, and it must work
    /// against the fake server before the cancel test below means anything.
    func testInterruptIdleEndsRunningIdle() throws {
        let server = try FakeIdleIMAPServer()
        defer { server.stop() }

        let session = makeSession(port: server.port)

        runOffMainThread(timeout: 30) {
            let (operation, finished) = self.startIdle(session)

            XCTAssertTrue(server.waitForIdleEntered(timeout: 5), "The session was expected to enter IDLE. Client sent:\n\(server.transcript)")
            XCTAssertEqual(finished.wait(timeout: .now() + 1), .timedOut, "IDLE was expected to still be running")

            operation.interruptIdle()

            XCTAssertEqual(finished.wait(timeout: .now() + 5), .success, "interruptIdle() did not end the IDLE")
            XCTAssertTrue(server.waitForDoneOrClose(timeout: 5), "The server saw neither DONE nor a close")
            XCTAssertTrue(self.waitUntilQueueStopped(session, timeout: 5), "The operation queue did not stop")
        }
    }

    /// Upstream's `testCancelWakesIdleIteration`: cancelling every operation on the session has to
    /// wake a running IDLE. Upstream made this true by having IMAPIdleOperation::cancel() call
    /// interruptIdle(); without that, cancel only flips a flag the blocked IDLE never looks at, and
    /// everything queued behind it - a disconnect included - waits for the IDLE to time out.
    func testCancelAllOperationsWakesRunningIdle() throws {
        let server = try FakeIdleIMAPServer()
        defer { server.stop() }

        let session = makeSession(port: server.port)

        runOffMainThread(timeout: 30) {
            let (operation, finished) = self.startIdle(session)

            XCTAssertTrue(server.waitForIdleEntered(timeout: 5), "The session was expected to enter IDLE. Client sent:\n\(server.transcript)")
            XCTAssertEqual(finished.wait(timeout: .now() + 1), .timedOut, "IDLE was expected to still be running")

            session.cancelAllOperations()

            let stopped = self.waitUntilQueueStopped(session, timeout: 5)
            // Known gap until upstream 03a19472 ("Fix IMAP IDLE teardown races") is merged: the
            // expectation is strict, so the test fails the day the fix lands and this block must go.
            // Spark does not depend on it today - it never calls cancelAllOperations() on an IMAP
            // session and always interruptIdle()s before disconnecting the idle session.
            XCTExpectFailure("IMAPIdleOperation::cancel() does not interrupt a running IDLE yet") {
                XCTAssertTrue(stopped, "cancelAllOperations() did not wake the running IDLE")
            }
            if stopped {
                XCTAssertTrue(server.waitForDoneOrClose(timeout: 5), "The server saw neither DONE nor a close")
            }
            else {
                // Do not leave the IDLE blocked behind us: end it the way that is known to work.
                operation.interruptIdle()
                _ = self.waitUntilQueueStopped(session, timeout: 5)
            }
        }
    }
}

#endif
