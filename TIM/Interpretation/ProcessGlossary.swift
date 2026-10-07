import Foundation

/// What kind of thing a process is, phrased so a person can act on it rather
/// than so a kernel engineer can categorise it.
enum ProcessCategory: String, Sendable, CaseIterable {
    case macOSCore = "Part of macOS"
    case appleApp = "Apple app"
    case backgroundTask = "Background service"
    case security = "Security & privacy"
    case sync = "Sync & cloud"
    case network = "Network"
    case media = "Photos, media & fonts"
    case developer = "Developer tools"
    case hardware = "Hardware & drivers"
    case thirdParty = "From another company"

    var blurb: String {
        switch self {
        case .macOSCore: return "Something the system itself needs to run."
        case .appleApp: return "Part of an app that came with your Mac."
        case .backgroundTask: return "Quiet work macOS does on its own."
        case .security: return "Checking that things are safe to run."
        case .sync: return "Keeping your files and accounts up to date."
        case .network: return "Talking to the internet and your local network."
        case .media: return "Working through your photos, music or fonts."
        case .developer: return "Tooling for people who write software."
        case .hardware: return "Talking to a piece of hardware."
        case .thirdParty: return "Something you or a download installed."
        }
    }
}

/// How safe it is to quit this process. `.unknown` is a first-class answer —
/// guessing here would be worse than saying we don't know.
enum SafeToQuit: String, Sendable {
    case safe = "Safe to quit"
    case leaveAlone = "Leave this one alone"
    case depends = "Depends"

    var note: String {
        switch self {
        case .safe: return "You can quit this and things will be fine. It comes back when it is needed."
        case .leaveAlone: return "Quitting this would interrupt something important, or stop your Mac working properly."
        case .depends: return "Quitting this may pause a task rather than break anything."
        }
    }
}

struct ProcessGlossaryEntry: Sendable, Identifiable {
    let id: String
    /// Canonical display name, e.g. "WindowServer".
    let name: String
    /// Bundle identifiers this can appear as. Looked up first, because they
    /// are unambiguous where display names are not.
    let bundleIdentifiers: [String]
    /// Executable basenames as they show in the process list.
    let executableNames: [String]
    /// Other ways people write or misspell this name.
    let aliases: [String]
    /// Plain-language phrases a person might actually type when they are
    /// describing the problem rather than the process.
    let knownFor: [String]
    let category: ProcessCategory
    let safeToQuit: SafeToQuit
    /// One sentence. What a hover shows.
    let summary: String
    /// The fuller explanation.
    let detail: String

    init(
        id: String,
        name: String,
        bundleIdentifiers: [String] = [],
        executableNames: [String] = [],
        aliases: [String] = [],
        knownFor: [String] = [],
        category: ProcessCategory,
        safeToQuit: SafeToQuit,
        summary: String,
        detail: String
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.executableNames = executableNames
        self.aliases = aliases
        self.knownFor = knownFor
        self.category = category
        self.safeToQuit = safeToQuit
        self.summary = summary
        self.detail = detail
    }
}

/// Plain-English explanations for the processes people actually see and don't
/// recognise. This is a seed set: it sets the voice and the shape, and the long
/// tail is meant to be filled in later against the same structure.
enum ProcessGlossary {
    static let all: [ProcessGlossaryEntry] = [
        // MARK: The ones that worry people
        entry(
            id: "windowserver",
            name: "WindowServer",
            bundleIdentifiers: ["com.apple.WindowServer"],
            executableNames: ["WindowServer"],
            aliases: ["window server", "windows server"],
            knownFor: ["high cpu", "fan loud", "screen drawing", "external display", "lots of windows", "sluggish graphics"],
            category: .macOSCore,
            safeToQuit: .leaveAlone,
            summary: "The part of macOS that draws every window you can see.",
            detail: "Everything on screen — every window, menu and shadow — is composited by WindowServer. The more windows, displays and transparency you have, the harder it works. A high number usually means you have a lot on screen, not that anything is wrong. It cannot be quit: it is how your screen gets drawn."
        ),
        entry(
            id: "kernel_task",
            name: "kernel_task",
            executableNames: ["kernel_task"],
            aliases: ["kernel task", "kerneltask"],
            knownFor: ["very high cpu", "fan on", "mac is hot", "throttling", "won't go away"],
            category: .macOSCore,
            safeToQuit: .leaveAlone,
            summary: "The core of macOS itself. A high number here is usually macOS protecting itself from heat.",
            detail: "This is the operating system rather than an app. When your Mac gets warm, macOS deliberately makes kernel_task busy so other things cannot use the processor — it is easing off the throttle, not causing the heat. High kernel_task beside a warm machine points at something else working hard. It cannot be quit."
        ),
        entry(
            id: "safari-web-content",
            name: "Safari Web Content",
            bundleIdentifiers: ["com.apple.WebKit.WebContent"],
            executableNames: ["Safari Web Content", "com.apple.WebKit.WebContent"],
            aliases: ["safari helper", "webkit webcontent", "safari webcontent", "safari tab"],
            knownFor: ["high memory", "safari using lots of ram", "many tabs", "browser memory", "safari slow"],
            category: .appleApp,
            safeToQuit: .safe,
            summary: "One of the pieces Safari runs underneath itself — usually a group of browser tabs.",
            detail: "Safari splits itself into several processes so one misbehaving tab cannot take the rest down. Each of these holds a set of tabs. A large memory number almost always means many tabs are open. Quitting closes those tabs; Safari offers to reopen them next time."
        ),
        entry(
            id: "webkit-networking",
            name: "Safari Networking",
            bundleIdentifiers: ["com.apple.WebKit.Networking"],
            executableNames: ["com.apple.WebKit.Networking"],
            aliases: ["webkit networking", "safari network"],
            knownFor: ["network activity", "safari downloading", "background data"],
            category: .appleApp,
            safeToQuit: .safe,
            summary: "Safari's own networking piece — it fetches the pages and files you ask for.",
            detail: "Kept apart from the tabs so a slow download does not hold up what you are looking at. Activity here is usually a page loading, a file downloading, or a tab refreshing."
        ),

        // MARK: Background services people don't recognise
        entry(
            id: "fileproviderd",
            name: "fileproviderd",
            executableNames: ["fileproviderd"],
            aliases: ["file provider", "fileprovider", "fileprovidered"],
            knownFor: ["icloud drive", "onedrive", "dropbox", "files syncing", "external drive", "file access slow"],
            category: .sync,
            safeToQuit: .depends,
            summary: "The coordinator for files that live somewhere other than on this Mac — iCloud Drive, OneDrive and the like.",
            detail: "Cloud storage services plug into macOS through one shared doorway, and this is it. It decides which files are on your disk and which still need downloading. Busy fileproviderd usually means something is syncing or a folder is being made available offline. Quitting pauses syncing until it restarts."
        ),
        entry(
            id: "biomeagent",
            name: "biomeagent",
            bundleIdentifiers: ["com.apple.BiomeAgent"],
            executableNames: ["biomeagent"],
            aliases: ["biome agent", "biomed"],
            knownFor: ["suggestions", "siri", "on device data", "quiet background work"],
            category: .backgroundTask,
            safeToQuit: .depends,
            summary: "Keeps the on-device database macOS uses for suggestions and shortcuts.",
            detail: "Biome is Apple's record of what happens on your Mac, kept on the device so features like suggested Shortcuts have something to work from. It works quietly in small bursts. Quitting simply stops that work until it is needed again."
        ),
        entry(
            id: "mds_stores",
            name: "mds_stores",
            executableNames: ["mds_stores", "mds"],
            aliases: ["mds stores", "mds", "spotlight indexing"],
            knownFor: ["spotlight slow", "high cpu after update", "fan on after installing", "search not finding files", "indexing"],
            category: .backgroundTask,
            safeToQuit: .depends,
            summary: "Spotlight, building the index that makes search work.",
            detail: "To find files instantly, macOS keeps an index of everything on your disk. This process writes that index. It works hard right after a macOS update, a large file copy, or connecting a big drive, then goes quiet. Let it finish — interrupting it just means it starts again."
        ),
        entry(
            id: "mdworker_shared",
            name: "mdworker_shared",
            executableNames: ["mdworker_shared", "mdworker"],
            aliases: ["mdworker", "md worker", "spotlight worker"],
            knownFor: ["spotlight", "indexing", "high cpu"],
            category: .backgroundTask,
            safeToQuit: .depends,
            summary: "The worker that reads your files so Spotlight can index them.",
            detail: "Where mds_stores keeps the index, this is the one that opens files to work out what is inside them. Several run at once while indexing is under way."
        ),
        entry(
            id: "nsurlsessiond",
            name: "nsurlsessiond",
            executableNames: ["nsurlsessiond"],
            aliases: ["nsurlsession", "urlsession"],
            knownFor: ["downloading", "network traffic", "background data", "app updates"],
            category: .sync,
            safeToQuit: .depends,
            summary: "The part of macOS that handles internet transfers on behalf of your apps.",
            detail: "Apps hand their downloads and uploads to this shared service rather than each doing its own. Busy here means something is downloading, syncing or checking for updates. Quitting stops transfers in progress."
        ),
        entry(
            id: "cloudd",
            name: "cloudd",
            executableNames: ["cloudd"],
            aliases: ["cloud d", "icloud sync"],
            knownFor: ["icloud", "icloud drive syncing", "photos uploading", "background data"],
            category: .sync,
            safeToQuit: .depends,
            summary: "iCloud syncing — keeping your documents, photos and settings up to date.",
            detail: "This moves data between your Mac and iCloud. It gets busy after you add a lot of files, or when you sign in on a new device and everything has to catch up."
        ),
        entry(
            id: "bird",
            name: "bird",
            executableNames: ["bird"],
            aliases: ["bird daemon", "icloud drive daemon"],
            knownFor: ["icloud drive", "files downloading", "placeholder files"],
            category: .sync,
            safeToQuit: .depends,
            summary: "The part of iCloud Drive that decides which files are physically on your Mac.",
            detail: "iCloud Drive can keep only the files you need in local storage, downloading the rest on demand. That is this process's job. The name is unhelpful — it stands for the file provider behind iCloud Drive."
        ),
        entry(
            id: "trustd",
            name: "trustd",
            executableNames: ["trustd"],
            aliases: ["trust d", "certificate daemon"],
            knownFor: ["security checks", "certificate warnings", "websites not loading", "keychain"],
            category: .security,
            safeToQuit: .leaveAlone,
            summary: "Checks that the software and websites you use are genuine.",
            detail: "Before macOS lets a certificate, an app update or a website through, it asks trustd to confirm the signature is real and has not been revoked. Occasional network activity is normal. If secure websites will not load, this is one of the pieces involved."
        ),
        entry(
            id: "tccd",
            name: "tccd",
            executableNames: ["tccd"],
            aliases: ["tcc", "permission daemon", "privacy daemon"],
            knownFor: ["permission prompts", "camera access", "microphone access", "screen recording permission", "app can't access files"],
            category: .security,
            safeToQuit: .leaveAlone,
            summary: "The gatekeeper for permissions — camera, microphone, location, your files.",
            detail: "Its name stands for Transparency, Consent and Control. It remembers which apps you have allowed to use your camera, microphone, location and documents, and enforces those answers. If an app cannot reach something it should, the setting is usually in System Settings under Privacy & Security."
        ),
        entry(
            id: "secd",
            name: "secd",
            executableNames: ["secd"],
            aliases: ["keychain daemon", "password daemon"],
            knownFor: ["keychain", "passwords", "wifi passwords", "certificate prompts"],
            category: .security,
            safeToQuit: .leaveAlone,
            summary: "Looks after your saved passwords and certificates.",
            detail: "Your keychain — the store behind saved passwords, Wi-Fi keys and certificates — is managed here. A keychain prompt usually means something is reading a saved secret it has not used before."
        ),
        entry(
            id: "opendirectoryd",
            name: "opendirectoryd",
            executableNames: ["opendirectoryd"],
            aliases: ["open directory", "directory services"],
            knownFor: ["login", "accounts", "network accounts", "slow login"],
            category: .security,
            safeToQuit: .leaveAlone,
            summary: "Handles accounts and logins, including network accounts at work or school.",
            detail: "When something needs to know who a user is or what they may do, it asks this. On a personal Mac it stays quiet. On a Mac joined to a workplace or school network it can appear when signing in."
        ),

        // MARK: Everyday macOS
        entry(
            id: "launchd",
            name: "launchd",
            executableNames: ["launchd"],
            aliases: ["launch daemon"],
            knownFor: ["first process", "starts everything", "can't quit"],
            category: .macOSCore,
            safeToQuit: .leaveAlone,
            summary: "The first thing macOS starts, which then starts everything else.",
            detail: "Every service on your Mac is launched and watched over by launchd. It is not a problem to be solved — it is the reason the rest of this list exists."
        ),
        entry(
            id: "loginwindow",
            name: "loginwindow",
            executableNames: ["loginwindow"],
            aliases: ["login window", "desktop session"],
            knownFor: ["login screen", "desktop", "logout"],
            category: .macOSCore,
            safeToQuit: .leaveAlone,
            summary: "The process behind your login session and desktop.",
            detail: "It shows the login screen, starts your session when you sign in, and handles logging out. It is closely tied to WindowServer — quitting it logs you out."
        ),
        entry(
            id: "dock",
            name: "Dock",
            bundleIdentifiers: ["com.apple.dock"],
            executableNames: ["Dock"],
            aliases: ["the dock"],
            knownFor: ["dock", "launchpad", "mission control", "stage manager"],
            category: .appleApp,
            safeToQuit: .safe,
            summary: "The Dock at the bottom of your screen, plus Mission Control and Launchpad.",
            detail: "One process draws the Dock and also handles the app switcher, Mission Control and Launchpad. If the Dock ever looks wrong, quitting it is harmless — macOS restarts it immediately."
        ),
        entry(
            id: "finder",
            name: "Finder",
            bundleIdentifiers: ["com.apple.finder"],
            executableNames: ["Finder"],
            aliases: ["the finder"],
            knownFor: ["file windows", "browsing files", "external drives", "desktop icons"],
            category: .appleApp,
            safeToQuit: .safe,
            summary: "The app you use to browse files, folders and drives.",
            detail: "Finder draws your desktop and every file-browsing window. Busy Finder usually means it is copying files, building previews, or reading an external drive. You can relaunch it from the Apple menu without losing anything."
        ),
        entry(
            id: "controlcenter",
            name: "Control Center",
            bundleIdentifiers: ["com.apple.controlcenter"],
            executableNames: ["ControlCenter"],
            aliases: ["control center", "systemuiserver", "menu bar icons"],
            knownFor: ["menu bar icons", "wifi menu", "sound menu", "brightness", "battery icon"],
            category: .appleApp,
            safeToQuit: .safe,
            summary: "The things in the top-right of your menu bar — Wi-Fi, sound, brightness and friends.",
            detail: "This draws the status items and the Control Center panel. On older Macs the same role was played by SystemUIServer. Restarting it is safe; the icons flicker and come back."
        ),
        entry(
            id: "notificationcenter",
            name: "NotificationCenter",
            bundleIdentifiers: ["com.apple.notificationcenterui"],
            executableNames: ["NotificationCenter"],
            aliases: ["notification center", "notifications"],
            knownFor: ["notification banners", "reminders", "widgets"],
            category: .appleApp,
            safeToQuit: .safe,
            summary: "Shows your notification banners, reminders and widgets.",
            detail: "If a banner appears on screen, this drew it. Activity here is usually a notification arriving or a widget refreshing."
        ),
        entry(
            id: "user-event-agent",
            name: "UserEventAgent",
            executableNames: ["UserEventAgent"],
            aliases: ["user event agent", "usereventagent"],
            knownFor: ["power changes", "sleep wake", "login items", "background triggers"],
            category: .backgroundTask,
            safeToQuit: .leaveAlone,
            summary: "Watches for things that happen to your Mac and wakes the right pieces in response.",
            detail: "Plugged in, unplugged, screen locked, session started — this notices and passes it on. There is usually one per user session, and it is normal for it to sit quietly."
        ),
        entry(
            id: "runningboardd",
            name: "runningboardd",
            executableNames: ["runningboardd"],
            aliases: ["running board", "runningboard"],
            knownFor: ["app freezing", "apps suspended", "resource limits", "background apps"],
            category: .macOSCore,
            safeToQuit: .leaveAlone,
            summary: "Decides which apps are allowed to run right now, and how much they may use.",
            detail: "macOS manages apps like a stage manager — some are front of house, some are suspended. That is this process's job. You will see it when apps are being started, stopped or woken in the background."
        ),
        entry(
            id: "distnoted",
            name: "distnoted",
            executableNames: ["distnoted"],
            aliases: ["dist note", "distributed notifications"],
            knownFor: ["app communication", "background messages"],
            category: .backgroundTask,
            safeToQuit: .leaveAlone,
            summary: "The post office apps use to pass small messages to each other.",
            detail: "Apps publish and listen for small notices rather than talking directly. Several of these run at once, one per session. Nothing is usually wrong when you see it."
        ),
        entry(
            id: "cfprefsd",
            name: "cfprefsd",
            executableNames: ["cfprefsd"],
            aliases: ["cf prefs", "preferences daemon", "settings daemon"],
            knownFor: ["settings", "preferences", "plist files"],
            category: .backgroundTask,
            safeToQuit: .leaveAlone,
            summary: "Reads and writes app and system settings behind the scenes.",
            detail: "When you change a setting, or an app remembers a window position, this handles the file write. It is only noticeable when something is wrong with a preference file."
        ),
        entry(
            id: "fseventsd",
            name: "fseventsd",
            executableNames: ["fseventsd"],
            aliases: ["fsevents", "file events"],
            knownFor: ["file changes", "backup", "dropbox", "watching folders"],
            category: .backgroundTask,
            safeToQuit: .leaveAlone,
            summary: "Notes when files change, so backups and search stay up to date without polling.",
            detail: "Rather than checking every folder repeatedly, macOS reports changes as they happen. This is the reporter. Active fseventsd usually means files are being written somewhere — an install, a sync, a backup."
        ),
        entry(
            id: "logd",
            name: "logd",
            executableNames: ["logd", "syslogd"],
            aliases: ["log daemon", "logging", "syslog"],
            knownFor: ["logs", "console", "log files"],
            category: .backgroundTask,
            safeToQuit: .leaveAlone,
            summary: "Collects the logs everything on your Mac writes.",
            detail: "Every process writes diagnostic records to one place, and this is it. If something is very chatty, logd works harder. The logs themselves are readable in Console."
        ),
        entry(
            id: "reportcrash",
            name: "ReportCrash",
            executableNames: ["ReportCrash", "CrashReporterSupport"],
            aliases: ["crash reporter", "crash reports", "problem reports"],
            knownFor: ["app crashing", "crash reports", "high cpu after crash", "problem report dialog"],
            category: .backgroundTask,
            safeToQuit: .safe,
            summary: "Writes up the report when an app crashes.",
            detail: "If an app quits unexpectedly, this collects what happened so it can be sent to the developer. Seeing it busy usually means something just crashed, and occasionally a large report takes a while."
        ),
        entry(
            id: "softwareupdated",
            name: "softwareupdated",
            executableNames: ["softwareupdated"],
            aliases: ["software update", "macos update"],
            knownFor: ["macos update", "app updates", "downloading update", "installing update", "high cpu during update"],
            category: .backgroundTask,
            safeToQuit: .depends,
            summary: "Checks for and installs macOS and App Store updates.",
            detail: "It checks periodically in the background, then downloads updates. It gets busy during a download or install, which is expected. Best left to finish what it started."
        ),
        entry(
            id: "backupd",
            name: "backupd",
            executableNames: ["backupd", "backupd-helper"],
            aliases: ["time machine", "backup"],
            knownFor: ["time machine", "backup running", "external drive", "high disk activity"],
            category: .backgroundTask,
            safeToQuit: .depends,
            summary: "Time Machine, copying your files to a backup drive.",
            detail: "When a backup runs, this reads a lot and writes to your backup disk. It is scheduled to be gentle, but a first backup or a long-overdue one can be noticeably busy."
        ),
        entry(
            id: "photoanalysisd",
            name: "photoanalysisd",
            executableNames: ["photoanalysisd"],
            aliases: ["photo analysis", "photos analysis"],
            knownFor: ["photos app", "faces", "memories", "high cpu when photos open"],
            category: .media,
            safeToQuit: .depends,
            summary: "Looks through your photo library to find faces, places and objects.",
            detail: "Photos works out what is in each picture so you can search for 'beach' and find beaches. That analysis is this process. It runs while Photos is open and when your Mac is plugged in and idle."
        ),
        entry(
            id: "suggestd",
            name: "suggestd",
            executableNames: ["suggestd"],
            aliases: ["suggest daemon", "suggestions"],
            knownFor: ["spotlight suggestions", "siri suggestions", "memories", "keyboard suggestions"],
            category: .media,
            safeToQuit: .depends,
            summary: "Builds the suggestions behind Spotlight, Siri and your keyboard.",
            detail: "It looks at patterns in what you do on the device to offer things like suggested Shortcuts and photo Memories. It works quietly and on the device."
        ),
        entry(
            id: "coreaudiod",
            name: "coreaudiod",
            executableNames: ["coreaudiod"],
            aliases: ["core audio", "audio daemon", "sound daemon"],
            knownFor: ["sound", "audio", "speakers", "microphone", "airpods", "audio glitching"],
            category: .hardware,
            safeToQuit: .leaveAlone,
            summary: "Everything to do with sound — speakers, microphones and Bluetooth audio.",
            detail: "All audio on your Mac flows through this. It gets busy during video calls, music, or when a Bluetooth headset connects. If sound stops working, this is one of the first pieces to restart."
        ),
        entry(
            id: "bluetoothd",
            name: "bluetoothd",
            executableNames: ["bluetoothd"],
            aliases: ["bluetooth daemon", "bluetooth"],
            knownFor: ["airpods", "magic mouse", "magic keyboard", "bluetooth disconnecting"],
            category: .hardware,
            safeToQuit: .leaveAlone,
            summary: "Runs your Bluetooth connections.",
            detail: "AirPods, Magic Mouse, Magic Keyboard and anything else wireless all go through this. Busy numbers are normal while connecting or reconnecting devices."
        ),
        entry(
            id: "hidd",
            name: "hidd",
            executableNames: ["hidd"],
            aliases: ["human interface device", "keyboard daemon", "trackpad daemon"],
            knownFor: ["keyboard", "trackpad", "mouse", "typing lag", "input"],
            category: .hardware,
            safeToQuit: .leaveAlone,
            summary: "Turns what you type and click into things the system understands.",
            detail: "Every keystroke, trackpad gesture and mouse movement passes through here. If input feels laggy, this is one of the pieces involved."
        ),
        entry(
            id: "powerd",
            name: "powerd",
            executableNames: ["powerd"],
            aliases: ["power daemon", "battery daemon"],
            knownFor: ["battery", "charging", "sleep", "power adapter", "battery draining fast"],
            category: .hardware,
            safeToQuit: .leaveAlone,
            summary: "Manages power — battery, charging, and when your Mac sleeps.",
            detail: "It decides when to dim the screen, when to sleep, and how fast to charge. Your Mac can show as plugged in but not charging when powerd is holding the charge steady to protect the battery."
        ),
        entry(
            id: "thermalmonitord",
            name: "thermalmonitord",
            executableNames: ["thermalmonitord"],
            aliases: ["thermal monitor", "temperature", "fans"],
            knownFor: ["fan noise", "mac is hot", "overheating", "thermal throttling"],
            category: .hardware,
            safeToQuit: .leaveAlone,
            summary: "Keeps an eye on temperature and decides when to run the fans.",
            detail: "If your fans spin up, this is what decided that. It reports how warm the Mac is running so the system can slow down before things get uncomfortable."
        ),
        entry(
            id: "mDNSResponder",
            name: "mDNSResponder",
            executableNames: ["mDNSResponder"],
            aliases: ["mdns responder", "bonjour", "network discovery", "dns"],
            knownFor: ["wifi", "network", "finding printers", "airplay", "local network", "internet problems"],
            category: .network,
            safeToQuit: .leaveAlone,
            summary: "Handles the naming and discovery your Mac does on the local network.",
            detail: "Finding printers, AirPlay targets and other devices on your Wi-Fi, plus resolving website names, all pass through here. If something on your network cannot be found, this is one of the pieces involved."
        ),

        // MARK: Things people installed
        entry(
            id: "krunkit",
            name: "krunkit",
            executableNames: ["krunkit"],
            aliases: ["krunk", "krunkit vm", "krunvm"],
            knownFor: ["virtual machine", "docker", "colima", "orbstack", "linux containers", "developer tool"],
            category: .developer,
            safeToQuit: .depends,
            summary: "Runs a Linux virtual machine, used by container tools like Colima or OrbStack.",
            detail: "This is not part of macOS — something you installed brought it in. It is the small virtual machine that lets Apple Silicon Macs run Linux containers. If you use Docker, Colima or OrbStack this is expected. If you do not, it is worth working out which download installed it."
        ),
        entry(
            id: "docker",
            name: "Docker",
            bundleIdentifiers: ["com.docker.docker"],
            executableNames: ["Docker", "com.docker.backend", "Docker Desktop"],
            aliases: ["docker desktop", "docker backend", "docker vm", "com.docker.build"],
            knownFor: ["docker", "containers", "virtual machine", "developer tool", "high cpu when idle"],
            category: .developer,
            safeToQuit: .depends,
            summary: "Container tooling — it runs a small Linux machine on your Mac.",
            detail: "Docker Desktop runs a virtual machine in the background so it can host containers. It is genuinely heavy, and high CPU here is usually a container running or the VM keeping itself alive. Quitting is safe if you are not actively using it."
        ),
        entry(
            id: "node",
            name: "node",
            executableNames: ["node", "nodejs"],
            aliases: ["node js", "nodejs", "npm"],
            knownFor: ["developer tool", "build process", "web development", "terminal"],
            category: .developer,
            safeToQuit: .depends,
            summary: "A JavaScript runtime, usually from something you or a developer tool started.",
            detail: "node is not part of macOS. If you do not write software, it is often a leftover from a build tool or a local development server. Safe to quit if you are not running a project that needs it."
        ),
        entry(
            id: "chrome-helper",
            name: "Google Chrome Helper",
            executableNames: ["Google Chrome Helper", "Chrome Helper (GPU)", "Chrome Helper (Renderer)"],
            aliases: ["chrome helper", "chrome renderer", "chrome gpu", "google chrome"],
            knownFor: ["chrome", "many tabs", "high memory", "browser slow"],
            category: .thirdParty,
            safeToQuit: .safe,
            summary: "One of the pieces Chrome runs underneath itself, usually a group of tabs.",
            detail: "Chrome, like Safari, splits itself up so one bad tab cannot take the browser down. There are several of these and they can use a lot of memory with many tabs open."
        ),
        entry(
            id: "adobe-creative-cloud",
            name: "Adobe Creative Cloud",
            bundleIdentifiers: ["com.adobe.CreativeCloud"],
            executableNames: ["Creative Cloud", "Adobe CEF Helper", "Adobe Desktop Service"],
            aliases: ["adobe", "creative cloud", "adobe cef helper", "ccxprocess"],
            knownFor: ["adobe", "photoshop", "illustrator", "background updater", "high cpu when idle"],
            category: .thirdParty,
            safeToQuit: .depends,
            summary: "Adobe's background services — licensing, updates and syncing.",
            detail: "Creative Cloud runs several helpers that check licences and look for updates even when no Adobe app is open. Quitting is safe if you are not using an Adobe app right now, though they may start again."
        ),
        entry(
            id: "google-drive",
            name: "Google Drive",
            executableNames: ["Google Drive", "Google Drive File Stream"],
            aliases: ["google drive", "drive file stream", "google drive helper"],
            knownFor: ["google drive", "files syncing", "drive streaming", "background data"],
            category: .thirdParty,
            safeToQuit: .depends,
            summary: "Google Drive, streaming and syncing your files.",
            detail: "Like iCloud Drive it keeps some files local and downloads the rest as you open them. Busy here means it is syncing. Quitting pauses syncing rather than removing anything."
        ),
        entry(
            id: "dropbox",
            name: "Dropbox",
            bundleIdentifiers: ["com.getdropbox.dropbox"],
            executableNames: ["Dropbox"],
            aliases: ["dropbox", "dropbox helper", "dbx"],
            knownFor: ["dropbox", "files syncing", "background data", "badge icons"],
            category: .thirdParty,
            safeToQuit: .depends,
            summary: "Dropbox, syncing your files and updating the little icons on them.",
            detail: "It also adds the green tick overlays to files in Finder, which is where some of its activity comes from. Quitting pauses syncing until you start it again."
        ),
        entry(
            id: "spotify",
            name: "Spotify Helper",
            bundleIdentifiers: ["com.spotify.client"],
            executableNames: ["Spotify Helper", "Spotify"],
            aliases: ["spotify", "spotify helper"],
            knownFor: ["spotify", "music", "high memory", "audio"],
            category: .thirdParty,
            safeToQuit: .safe,
            summary: "One of the pieces Spotify runs underneath itself.",
            detail: "Spotify runs helpers for playback, its embedded web pages and hardware acceleration. Like most Electron-style apps it can hold more memory than you would expect."
        ),
        entry(
            id: "microsoft-autoupdate",
            name: "Microsoft AutoUpdate",
            bundleIdentifiers: ["com.microsoft.autoupdate2"],
            executableNames: ["Microsoft AutoUpdate", "MAU2"],
            aliases: ["microsoft autoupdate", "office update", "mau"],
            knownFor: ["office", "word", "excel", "updates", "background updater"],
            category: .thirdParty,
            safeToQuit: .safe,
            summary: "Checks for updates to Microsoft apps such as Word, Excel and Teams.",
            detail: "It looks for new versions in the background and installs them when you agree. Safe to quit — it simply stops checking until you open a Microsoft app again."
        ),
        entry(
            id: "vmnetd",
            name: "vmnetd",
            executableNames: ["vmnetd", "com.apple.vmnetd"],
            aliases: ["vmnet", "vmnetd"],
            knownFor: ["virtual machine", "docker", "vmware", "parallels", "network for vms"],
            category: .developer,
            safeToQuit: .leaveAlone,
            summary: "Handles networking for virtual machines and container tools.",
            detail: "If you run Docker, Colima, Parallels or similar, this gives those virtual machines a way onto your network. Without it they cannot reach the internet."
        ),
    ]

    /// Looks up an entry for a running process. Bundle identifiers win over
    /// display names, because names collide and bundles don't.
    static func entry(forName name: String, bundleIdentifier: String?) -> ProcessGlossaryEntry? {
        if let bundleIdentifier {
            let lowered = bundleIdentifier.lowercased()
            if let match = all.first(where: { entry in
                entry.bundleIdentifiers.contains { $0.lowercased() == lowered }
            }) {
                return match
            }
        }
        return entry(forExecutableName: name)
    }

    /// Matches a process list name against the executable names an entry lists.
    static func entry(forExecutableName name: String) -> ProcessGlossaryEntry? {
        let lowered = name.lowercased()
        return all.first(where: { entry in
            entry.executableNames.contains { $0.lowercased() == lowered }
        })
    }

    /// A labelled guess for a process we have no entry for. Nil when there is
    /// nothing to go on — the caller says "we don't know" rather than inventing.
    static func guessedCategory(forName name: String, bundleIdentifier: String?) -> ProcessCategory? {
        if let bundleIdentifier {
            let lowered = bundleIdentifier.lowercased()
            return lowered.hasPrefix("com.apple.") ? .appleApp : .thirdParty
        }
        let lowered = name.lowercased()
        if lowered.contains("helper") || lowered.contains("renderer") {
            return .thirdParty
        }
        return nil
    }

    private static func entry(
        id: String,
        name: String,
        bundleIdentifiers: [String] = [],
        executableNames: [String] = [],
        aliases: [String] = [],
        knownFor: [String] = [],
        category: ProcessCategory,
        safeToQuit: SafeToQuit,
        summary: String,
        detail: String
    ) -> ProcessGlossaryEntry {
        ProcessGlossaryEntry(
            id: id,
            name: name,
            bundleIdentifiers: bundleIdentifiers,
            executableNames: executableNames,
            aliases: aliases,
            knownFor: knownFor,
            category: category,
            safeToQuit: safeToQuit,
            summary: summary,
            detail: detail
        )
    }
}
