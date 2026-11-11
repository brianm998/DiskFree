import Testing
import Foundation
@testable import DiskFree

struct ShellActorTests {
    func running(_ pattern: String) throws -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-f", pattern]
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    @Test func timeoutKillsHungCommand() async throws {
        let arg = "29.\(Int.random(in: 100000...999999))"
        let actor = ShellActor("sleep", arguments: [arg])
        let start = Date()
        await #expect(throws: (any Error).self) {
            _ = try await actor.execute(timeout: 1)
        }
        #expect(Date().timeIntervalSince(start) < 2)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(try !running(arg))
    }

    @Test func returnsOutput() async throws {
        let actor = ShellActor("echo", arguments: ["hello world"])
        let out = try await actor.execute(timeout: 5)
        #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "hello world")
    }
}
