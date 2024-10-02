import Foundation

typealias VolumeRecords = [String:[SizeInfo]]

func oldestTime(from records: VolumeRecords) -> TimeInterval {
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
