import Foundation

typealias LocalVolumeRecords = [String:[SizeInfo]]

func oldestTime(from records: LocalVolumeRecords) -> TimeInterval {
    var ret: TimeInterval = 1000000000000000000

    for (volume, sizes) in records {
        var earliestTimeForThisVolume: TimeInterval = 1000000000000000000

        for size in sizes {
            if size.timestamp < earliestTimeForThisVolume {
                earliestTimeForThisVolume = size.timestamp
            }
        }

        if earliestTimeForThisVolume < ret { ret = earliestTimeForThisVolume }
    }
    
    return ret
}
