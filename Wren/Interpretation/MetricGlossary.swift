import Foundation

/// Plain-English definitions for every technical value the app shows.
/// `summary` is the hover line; `detail` is the expanded explanation.
struct GlossaryEntry: Sendable, Identifiable {
    let id: String
    let term: String
    let summary: String
    let detail: String
}

enum MetricGlossary {
    // MARK: Processor

    static let cpu = GlossaryEntry(
        id: "cpu",
        term: "CPU",
        summary: "How busy your Mac's processor is right now.",
        detail: "The processor does the thinking. A high number just means it has a lot of work on its hands — brief spikes are completely normal. It is only worth noticing if it stays high and your Mac feels slow."
    )

    static let cpuUserSystem = GlossaryEntry(
        id: "cpu.userSystem",
        term: "CPU user / system",
        summary: "Time spent on your apps, and time spent by macOS itself.",
        detail: "User is time spent on the things you opened. System is time macOS spends keeping everything running, such as loading files and managing memory."
    )

    static let cpuIdle = GlossaryEntry(
        id: "cpu.idle",
        term: "CPU idle",
        summary: "How much of the processor is sitting unused.",
        detail: "A high idle number is good — it means your Mac has capacity to spare."
    )

    static let cpuApp = GlossaryEntry(
        id: "cpu.app",
        term: "App CPU",
        summary: "How much processor time this app is using.",
        detail: "Shown as a share of one core's full capacity, so a busy app can read above 100% on a Mac with several cores. Sums the app and everything it runs underneath."
    )

    // MARK: Memory

    static let memory = GlossaryEntry(
        id: "memory.used",
        term: "Memory in use",
        summary: "How much of your Mac's fast working memory is being used.",
        detail: "RAM is where your Mac keeps what it is working on right now. macOS fills it up on purpose so it does not have to reload things from disk, so a full-looking memory graph is not a problem by itself."
    )

    static let memoryPressure = GlossaryEntry(
        id: "memory.pressure",
        term: "Memory pressure",
        summary: "How hard your Mac is working to find room in memory.",
        detail: "This is the number that actually matters. It measures how much macOS is compressing, moving and shuffling data to make room. If pressure is normal, your Mac has enough memory — even when memory looks full."
    )

    static let freeMemory = GlossaryEntry(
        id: "memory.free",
        term: "Free",
        summary: "Memory that is not being used at all.",
        detail: "macOS normally keeps this low on purpose. Spare memory is better spent caching things you are likely to need again."
    )

    static let activeMemory = GlossaryEntry(
        id: "memory.active",
        term: "Active",
        summary: "Memory holding things in use right now.",
        detail: "Data that has been touched recently and is being kept ready. It cannot be dropped without being saved somewhere else first."
    )

    static let inactiveMemory = GlossaryEntry(
        id: "memory.inactive",
        term: "Inactive",
        summary: "Memory kept around in case it is needed again.",
        detail: "This holds things you used a little while ago so they open fast again. It can be cleared instantly if anything else needs the room."
    )

    static let wiredMemory = GlossaryEntry(
        id: "memory.wired",
        term: "Wired",
        summary: "Memory macOS has to keep in place.",
        detail: "Wired memory holds the essentials — the system itself and its connections to your hardware. It cannot be compressed or moved to disk."
    )

    static let compressedMemory = GlossaryEntry(
        id: "memory.compressed",
        term: "Compressed",
        summary: "Memory macOS squeezed to make more room.",
        detail: "Rather than write less-used data to disk, macOS can compress it in RAM. A lot of compressed memory means your Mac is working to make room."
    )

    static let purgeableMemory = GlossaryEntry(
        id: "memory.purgeable",
        term: "Purgeable",
        summary: "Memory macOS can clear instantly if it needs the room.",
        detail: "It is kept purely for speed, such as parts of an app you are not currently using. If your Mac needs memory, this is the first to go."
    )

    static let internalMemory = GlossaryEntry(
        id: "memory.internal",
        term: "Internal",
        summary: "Memory attributed to hardware built into your Mac.",
        detail: "macOS tracks some memory as belonging to the hardware inside your machine, usually the graphics chip. For most people this sits at or near zero and can be safely ignored."
    )

    static let externalMemory = GlossaryEntry(
        id: "memory.external",
        term: "External",
        summary: "Memory attributed to hardware connected from outside.",
        detail: "This usually stays at zero. It can appear if you use an external graphics card."
    )

    static let swap = GlossaryEntry(
        id: "memory.swap",
        term: "Swap",
        summary: "Memory that has been parked on your disk.",
        detail: "When RAM gets tight, macOS moves less-used data to storage. A little swap is normal. Swap that grows quickly, especially alongside slow performance, means your Mac is running short on memory."
    )

    static let swapTotal = GlossaryEntry(
        id: "memory.swapTotal",
        term: "Swap total",
        summary: "How much disk space is set aside for memory overflow.",
        detail: "macOS grows and shrinks this automatically, so the number changing on its own is expected."
    )

    static let memoryApp = GlossaryEntry(
        id: "memory.app",
        term: "App memory",
        summary: "How much memory this app is holding on to.",
        detail: "This is the app's real memory footprint — the same measure Activity Monitor shows in its Memory column. It includes memory the app shares with other processes."
    )

    // MARK: Disk and network

    static let diskRead = GlossaryEntry(
        id: "disk.read",
        term: "Disk read",
        summary: "How fast files are being loaded from storage.",
        detail: "Reading is data coming off your disk into memory — opening apps, loading projects, starting up. A spike usually means something is opening or being indexed."
    )

    static let diskWrite = GlossaryEntry(
        id: "disk.write",
        term: "Disk write",
        summary: "How fast files are being saved to storage.",
        detail: "Writing is data going from memory onto your disk — saving documents, installing updates, recording. Heavy writing can make your Mac feel busy even when nothing appears to be open."
    )

    static let networkDown = GlossaryEntry(
        id: "network.down",
        term: "Network down",
        summary: "How fast data is arriving from the internet or your network.",
        detail: "Downloads, streaming, sync services and updates all show up here. A high number is normal while something is downloading or during a video call."
    )

    static let networkUp = GlossaryEntry(
        id: "network.up",
        term: "Network up",
        summary: "How fast data is being sent out to the internet or your network.",
        detail: "Uploads, video calls, backups and cloud sync all show up here. If this stays high, something is probably sending a large amount of data out."
    )

    // MARK: Power and heat

    static let energyWatts = GlossaryEntry(
        id: "energy.watts",
        term: "Energy",
        summary: "How much power an app is drawing right now.",
        detail: "Watts is the rate of energy use. Higher watts means more battery drain and more heat. This is measured directly rather than estimated."
    )

    static let battery = GlossaryEntry(
        id: "power.battery",
        term: "Battery",
        summary: "How much charge is left in your battery.",
        detail: "A battery that drains unusually fast is usually being held by one busy app — the Apps screen is the quickest way to find it."
    )

    static let charging = GlossaryEntry(
        id: "power.charging",
        term: "Charging",
        summary: "Whether your Mac is drawing power from a charger right now.",
        detail: "Your Mac can show as plugged in but not charging when it is holding the charge steady to protect the battery."
    )

    static let powerSource = GlossaryEntry(
        id: "power.source",
        term: "Power source",
        summary: "Whether your Mac is running on a charger or on battery.",
        detail: "On battery, macOS is free to save power by trimming background work."
    )

    static let thermalState = GlossaryEntry(
        id: "power.thermal",
        term: "Thermal state",
        summary: "How warm your Mac is running.",
        detail: "As a Mac gets warm it slows itself down to protect the hardware. Nominal and Fair are everyday temperatures. Serious and Critical mean it is hot enough to slow down noticeably."
    )

    static let lowPowerMode = GlossaryEntry(
        id: "power.lowPowerMode",
        term: "Low power mode",
        summary: "A setting that trims performance to extend battery life.",
        detail: "It reduces background work and screen brightness to make the charge last longer. Your Mac may feel slightly slower while it is on."
    )

    static let uptime = GlossaryEntry(
        id: "system.uptime",
        term: "Uptime",
        summary: "How long since your Mac was last restarted.",
        detail: "A long uptime is not a problem in itself. Restarting now and then clears out temporary state and is good practice."
    )

    // MARK: Apps and processes

    static let processes = GlossaryEntry(
        id: "process.count",
        term: "Processes",
        summary: "The individual pieces that make up a running app.",
        detail: "One app can be made of several processes — a browser runs a separate one for each tab, for instance. This app groups them together so you see apps rather than parts."
    )

    static let pid = GlossaryEntry(
        id: "process.pid",
        term: "PID",
        summary: "The number macOS gives each running process.",
        detail: "Process IDs are assigned when something starts and reused later. They are only useful for telling two copies of the same thing apart."
    )

    static let residentMemory = GlossaryEntry(
        id: "process.resident",
        term: "Resident memory",
        summary: "The memory this process currently has loaded in RAM.",
        detail: "It is the raw size of what is held in physical memory right now. App memory is usually the better figure to look at, since it accounts for sharing."
    )
}
