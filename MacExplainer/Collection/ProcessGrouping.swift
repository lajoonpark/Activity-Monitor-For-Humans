import Foundation

enum ProcessGrouping {
    /// Groups a published slice of snapshots into combined process groups.
    ///
    /// Key rules, applied in order for the SAME slice:
    ///  1. bundleIdentifier != nil            -> "bundle:<id>" key
    ///  2. parentPid walks up the same-slice map and lands on an app / top
    ///     process -> that top process's key
    ///  3. otherwise                          -> "name:<displayName>" key
    static func buildGroups(from processes: [ProcessSnapshot]) -> [ProcessGroupStats] {
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.id, $0) })

        func rootKey(for pid: Int32) -> (key: String, root: ProcessSnapshot) {
            var seen = Set<Int32>()
            var current = byPID[pid]
            while let process = current, seen.insert(process.id).inserted {
                if let bundle = process.bundleIdentifier {
                    return ("bundle:\(bundle)", process)
                }
                guard let parentPid = process.parentPid,
                      parentPid != process.id,
                      let parent = byPID[parentPid] else {
                    return ("name:\(process.name)", process)
                }
                current = parent
            }
            return ("name:\(current?.name ?? "Unknown")", current ?? byPID[pid] ?? processes[0])
        }

        var buckets: [String: (root: ProcessSnapshot, members: [ProcessSnapshot])] = [:]
        for process in processes {
            let (key, root) = rootKey(for: process.id)
            var bucket = buckets[key] ?? (root: root, members: [])
            bucket.members.append(process)
            buckets[key] = bucket
        }

        return buckets.map { key, bucket in
            let energySum = bucket.members.reduce(into: UInt64(0)) { sum, member in
                if let delta = member.energyNanojoulesDelta { sum += delta }
            }
            let hasEnergy = bucket.members.contains { $0.energyNanojoulesDelta != nil }
            return ProcessGroupStats(
                id: key,
                name: bucket.root.name,
                pid: bucket.root.id,
                isApplication: bucket.root.isApplication,
                cpuPercent: bucket.members.reduce(0) { $0 + $1.cpuPercent },
                residentBytes: bucket.members.reduce(0) { $0 + $1.residentBytes },
                energyNanojoulesDelta: hasEnergy ? energySum : nil,
                processCount: Int32(bucket.members.count)
            )
        }
    }
}
