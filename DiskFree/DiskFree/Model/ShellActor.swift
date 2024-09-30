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
}
