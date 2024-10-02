import Foundation

typealias VolumeRecords = [String:[SizeInfo]]

func timeDurationSeconds(of records: VolumeRecords) -> TimeInterval {
    var ret: TimeInterval = 0

    for (volume, sizes) in records {
        var latestTimeForThisVolume: TimeInterval = 0
        var earliestTimeForThisVolume: TimeInterval = 1000000000000000000

        for size in sizes {
            if size.timestamp < earliestTimeForThisVolume {
                earliestTimeForThisVolume = size.timestamp
            } else if size.timestamp > latestTimeForThisVolume {
                latestTimeForThisVolume = size.timestamp
            }
        }

        var timeDurationOfThisVolume = latestTimeForThisVolume - earliestTimeForThisVolume
        
        if timeDurationOfThisVolume > ret { ret = timeDurationOfThisVolume }
    }
    
    return ret
}
