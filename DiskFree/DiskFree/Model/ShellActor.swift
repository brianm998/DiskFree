import Foundation
import ShellOut

public actor ShellActor {
    let fullPathToExecutable: String
    let arguments: [String]
    let outputDirname: String?

    public init(_ fullPathToExecutable: String,
                arguments: [String] = [],
                outputDirname: String? = nil)
    {
        self.fullPathToExecutable = fullPathToExecutable
        self.arguments = arguments
        self.outputDirname = outputDirname
    }
    
    public func execute() throws -> String {
        if let outputDirname {
            try shellOut(to: fullPathToExecutable,
                         arguments: arguments,
                         at: outputDirname)
        } else {
            try shellOut(to: fullPathToExecutable,
                         arguments: arguments)
        }
    }

    /// Runs the command without blocking a thread and without a shell.
    /// If it has not finished after `timeout` seconds it is terminated
    /// (SIGKILL shortly after if needed) and an error is thrown.
    public func execute(timeout: TimeInterval) async throws -> String {
        let process = Process()
        if fullPathToExecutable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: fullPathToExecutable)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [fullPathToExecutable] + arguments
        }
        if let outputDirname {
            process.currentDirectoryURL = URL(fileURLWithPath: outputDirname)
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let state = ProcessRunState()
        let name = fullPathToExecutable
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                state.append(data)
            }
        }

        let timeoutTask = Task.detached {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard process.isRunning else { return }
            let pid = process.processIdentifier
            process.terminate()
            // report the timeout now; do not depend on the process dying
            state.finish(.failure("\(name) timed out after \(timeout) seconds"))
            try await Task.sleep(nanoseconds: 500_000_000)
            if process.isRunning { kill(pid, SIGKILL) }
        }
        defer {
            timeoutTask.cancel()
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            state.setContinuation(cont)
            process.terminationHandler = { p in
                // let the readability handler drain what is left
                let rest = pipe.fileHandleForReading.readDataToEndOfFile()
                state.append(rest)
                if p.terminationStatus == 0 {
                    state.finish(.success(state.output))
                } else {
                    state.finish(.failure("\(name) exited with status \(p.terminationStatus)"))
                }
            }
            do {
                try process.run()
            } catch {
                state.finish(.failure(error))
            }
        }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var continuation: CheckedContinuation<String, Error>?
    private var result: Result<String, Error>?

    var output: String {
        lock.lock(); defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }

    func append(_ more: Data) {
        lock.lock(); data.append(more); lock.unlock()
    }

    func setContinuation(_ c: CheckedContinuation<String, Error>) {
        lock.lock(); continuation = c; lock.unlock()
    }

    // first call wins
    func finish(_ r: Result<String, Error>) {
        lock.lock()
        guard result == nil, let c = continuation else { lock.unlock(); return }
        result = r
        continuation = nil
        lock.unlock()
        c.resume(with: r)
    }
}
