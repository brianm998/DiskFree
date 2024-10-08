import Foundation

public struct NetworkVolume: Sendable,
                             Codable,
                             Identifiable,
                             Hashable,
                             Comparable
{
    public let username: String
    public let remoteHost: String
    public let remotePath: String
    public let localMount: String
    public let type: String
    public let id = UUID()

    public init(username: String,
                remoteHost: String,
                remotePath: String,
                localMount: String,
                type: String)
    {
        self.username = username
        self.remoteHost = remoteHost
        self.remotePath = remotePath
        self.localMount = localMount
        self.type = type
    }

    //admin@beast.local/root on /System/Volumes/Data/mnt/root (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
    public init?(from mountOutputLine: String) {
        if let match = mountOutputLine.firstMatch(of: /^\/\/(\w+)@([\w.]+)([\/\w]*)\s+on\s+([\/\w]+)\s+\((\w+)/) {
            self.username = String(match.1)
            self.remoteHost = String(match.2)
            self.remotePath = String(match.3)
            self.localMount = String(match.4) // remove /System/Volumes/Data ?
            self.type = String(match.5)
        } else {
            // no match on this line
            return nil
        }
    }

  public static func == (lhs: NetworkVolume, rhs: NetworkVolume) -> Bool {
        lhs.username == rhs.username &&
        lhs.remoteHost == rhs.remoteHost &&
        lhs.remotePath == rhs.remotePath &&
        lhs.localMount == rhs.localMount &&
        lhs.type == rhs.type
    }

  public static func < (lhs: NetworkVolume, rhs: NetworkVolume) -> Bool {
      lhs.localMount < rhs.localMount
  }
  
  public func hash(into hasher: inout Hasher) {
        hasher.combine(username)
        hasher.combine(remoteHost)
        hasher.combine(remotePath)
        hasher.combine(localMount)
        hasher.combine(type)
    }
}

