import AppKit
import BirdingCore
import Darwin

struct UpdateTicket: Codable {
    let token: String
    let release: UpdateRelease
    let target: String
    let parentPID: Int32
    let created: Date
    var root: URL { UpdateInstaller.root(token) }
}

enum UpdateInstaller {
    static let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Birding/Updates",isDirectory:true)
    static func root(_ token: String) -> URL { base.appendingPathComponent(token,isDirectory:true) }
    static func write<T: Encodable>(_ value: T, to url: URL) throws { try JSONEncoder().encode(value).write(to:url,options:.atomic) }
    static func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T { try JSONDecoder().decode(type,from:Data(contentsOf:url)) }
    static var currentVersion: String { Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.0.0" }
    static var platform: String {
        #if arch(arm64)
        return "macOS-arm64"
        #else
        return "macOS-x86_64"
        #endif
    }
    static func load(_ token: String, allowExpired: Bool = false) throws -> UpdateTicket {
        guard UUID(uuidString:token) != nil, root(token).standardizedFileURL == root(token).resolvingSymlinksInPath() else { throw UpdateFailure.invalid("Invalid update ticket") }
        let ticket=try read(UpdateTicket.self,at:root(token).appendingPathComponent("transaction.json"))
        guard ticket.token == token, allowExpired || Date().timeIntervalSince(ticket.created) < 7*86400 else { throw UpdateFailure.invalid("Expired update ticket") }
        _ = try UpdateReplacement(target:URL(fileURLWithPath:ticket.target),token:token)
        return ticket
    }
    @discardableResult static func command(_ path: String, _ args: [String]) throws -> String {
        let process=Process();process.executableURL=URL(fileURLWithPath:path);process.arguments=args
        let pipe=Pipe();process.standardOutput=pipe;process.standardError=pipe
        try process.run()
        // Drain output before waiting, so a full pipe cannot deadlock the helper.
        let data=pipe.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit()
        let output=String(data:data,encoding:.utf8) ?? ""
        guard process.terminationStatus == 0 else { throw UpdateFailure.invalid("\(URL(fileURLWithPath:path).lastPathComponent): \(output.prefix(1500))") }
        return output
    }
    static func team(of app: URL) throws -> String {
        try command("/usr/bin/codesign",["--verify","--deep","--strict",app.path])
        let output=try command("/usr/bin/codesign",["-dv","--verbose=4",app.path])
        let value=output.split(separator:"\n").first(where:{$0.hasPrefix("TeamIdentifier=")}).map{String($0.dropFirst(15))} ?? ""
        guard value.count == 10, value.allSatisfy({$0.isASCII && ($0.isUppercase || $0.isNumber)}) else {
            throw UpdateFailure.invalid("当前开发包未使用 Developer ID 签名，不能自动替换。请使用正式安装版。 / Automatic installation requires a Developer ID-signed build.")
        }
        return value
    }
    static func validateApp(_ app: URL, release: UpdateRelease, team: String) throws {
        guard let bundle=Bundle(url:app), bundle.bundleIdentifier == "dev.birding.desktop",
              bundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String == release.version,
              bundle.executableURL?.lastPathComponent == "Birding" else { throw UpdateFailure.invalid("Update bundle identity/version mismatch") }
        let requirement="anchor apple generic and identifier \"dev.birding.desktop\" and certificate leaf[subject.OU] = \"\(team)\""
        try command("/usr/bin/codesign",["--verify","--deep","--strict","-R",requirement,app.path])
        try command("/usr/sbin/spctl",["--assess","--type","execute",app.path])
        let architectures=try command("/usr/bin/lipo",["-archs",bundle.executableURL!.path])
        guard architectures.split(whereSeparator:{$0.isWhitespace}).contains(Substring(platform == "macOS-arm64" ? "arm64":"x86_64")) else { throw UpdateFailure.invalid("Update CPU architecture mismatch") }
        if let minimum=bundle.object(forInfoDictionaryKey:"LSMinimumSystemVersion") as? String {
            let parts=minimum.split(separator:".").compactMap{Int($0)}
            if let major=parts.first {
                guard ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion:major,minorVersion:parts.count>1 ? parts[1]:0,patchVersion:parts.count>2 ? parts[2]:0)) else { throw UpdateFailure.invalid("This update requires a newer macOS version") }
            }
        }
    }
    static func stage(release: UpdateRelease, token: String, target: URL) throws {
        let archive=root(token).appendingPathComponent("package.zip"), extracted=root(token).appendingPathComponent("extracted")
        try release.verify(archive)
        let expanded=try UpdateArchive.validate(Data(contentsOf:archive,options:.mappedIfSafe))
        let free=(try FileManager.default.attributesOfFileSystem(forPath:root(token).path)[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard free>expanded*2+50_000_000 else { throw UpdateFailure.invalid("Not enough free space to unpack this update") }
        let fm=FileManager.default
        if fm.fileExists(atPath:extracted.path) { try fm.removeItem(at:extracted) }
        try fm.createDirectory(at:extracted,withIntermediateDirectories:false)
        try command("/usr/bin/ditto",["-x","-k",archive.path,extracted.path])
        try validateApp(extracted.appendingPathComponent("ChirpOS.app"),release:release,team:team(of:target))
    }
    static func prepare(_ ticket: UpdateTicket) throws {
        let fm=FileManager.default, target=URL(fileURLWithPath:ticket.target)
        guard !target.path.contains("/AppTranslocation/"), !target.path.hasPrefix("/Volumes/"),
              fm.isWritableFile(atPath:target.deletingLastPathComponent().path) else { throw UpdateFailure.invalid("请将应用移到可写的应用程序目录后安装更新。 / Move ChirpOS to a writable Applications folder first.") }
        // Re-extract from the checked archive at confirmation time; never trust an old staging tree.
        try stage(release:ticket.release,token:ticket.token,target:target)
        let replacement=try UpdateReplacement(target:target,token:ticket.token)
        try replacement.prepare(from:ticket.root.appendingPathComponent("extracted/ChirpOS.app"))
        do {
            try validateApp(replacement.candidate,release:ticket.release,team:team(of:target))
            try? fm.removeItem(at:ticket.root.appendingPathComponent("cancel"))
            try? fm.removeItem(at:ticket.root.appendingPathComponent("helper-ready"))
            try? fm.removeItem(at:ticket.root.appendingPathComponent("healthy.json"))
            try write(ticket,to:ticket.root.appendingPathComponent("transaction.json"))
            let helper=ticket.root.appendingPathComponent("installer")
            if fm.fileExists(atPath:helper.path) { try fm.removeItem(at:helper) }
            try fm.copyItem(at:Bundle.main.executableURL!,to:helper)
            try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:helper.path)
            let p=Process();p.executableURL=helper;p.arguments=["--apply-update",ticket.token];try p.run()
        } catch {
            try? fm.removeItem(at:replacement.candidate);throw error
        }
    }
    static func alive(_ pid: Int32) -> Bool { pid > 0 && kill(pid,0) == 0 }
    static func launch(_ target: URL, arguments: [String]) throws -> NSRunningApplication {
        let config=NSWorkspace.OpenConfiguration();config.arguments=arguments;config.createsNewApplicationInstance=true;config.activates=false
        var result:NSRunningApplication?, failure:Error?, done=false
        NSWorkspace.shared.openApplication(at:target,configuration:config) { app,error in result=app;failure=error;done=true }
        let deadline=Date().addingTimeInterval(15)
        while !done && Date()<deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.05)) }
        guard let result else { throw failure ?? UpdateFailure.invalid("New version failed to launch") }
        return result
    }
    static func runHelper(token: String) -> Int32 {
        var ticket:UpdateTicket?, replacement:UpdateReplacement?, launched:NSRunningApplication?, replaced=false
        do {
            let t=try load(token);ticket=t
            let r=try UpdateReplacement(target:URL(fileURLWithPath:t.target),token:token);replacement=r
            try t.release.verify(t.root.appendingPathComponent("package.zip"))
            try validateApp(r.candidate,release:t.release,team:team(of:r.target))
            try Data(String(ProcessInfo.processInfo.processIdentifier).utf8).write(to:t.root.appendingPathComponent("helper-pid"),options:.atomic)
            try Data().write(to:t.root.appendingPathComponent("helper-ready"),options:.atomic)
            let deadline=Date().addingTimeInterval(60)
            while alive(t.parentPID) && Date()<deadline && !FileManager.default.fileExists(atPath:t.root.appendingPathComponent("cancel").path) { Thread.sleep(forTimeInterval:0.1) }
            guard !FileManager.default.fileExists(atPath:t.root.appendingPathComponent("cancel").path) else { throw UpdateFailure.invalid("Installation was cancelled before replacement") }
            guard !alive(t.parentPID) else { throw UpdateFailure.invalid("Previous version did not exit") }
            try r.replace();replaced=true
            launched=try launch(r.target,arguments:["--update-launch",token])
            let healthDeadline=Date().addingTimeInterval(90)
            while Date()<healthDeadline {
                if !alive(launched!.processIdentifier) { throw UpdateFailure.invalid("New version exited during startup") }
                if let health=try? read(UpdateHealth.self,at:t.root.appendingPathComponent("healthy.json")), health.token==token,
                   health.pid==launched!.processIdentifier, health.version==t.release.version {
                    // Cleanup failure must never roll a healthy application back.
                    try? Data().write(to:t.root.appendingPathComponent("complete"),options:.atomic)
                    do { try r.complete();clearReady(token:token);try FileManager.default.removeItem(at:t.root) }
                    catch { NSLog("Update cleanup deferred: %@",error.localizedDescription) }
                    return 0
                }
                Thread.sleep(forTimeInterval:0.2)
            }
            throw UpdateFailure.invalid("New version did not confirm successful startup")
        } catch {
            if let t=ticket {
                try? Data(error.localizedDescription.utf8).write(to:base.appendingPathComponent("last-error.txt"),options:.atomic)
                var recovered = !replaced
                if replaced, let r=replacement {
                    if let launched, !launched.isTerminated { launched.terminate();Thread.sleep(forTimeInterval:2);if !launched.isTerminated { launched.forceTerminate() } }
                    do { try r.rollback();recovered=true; _ = try launch(r.target,arguments:[]) } catch { NSLog("Update rollback: %@",error.localizedDescription) }
                } else if let r=replacement { try? FileManager.default.removeItem(at:r.candidate) }
                try? FileManager.default.removeItem(at:t.root.appendingPathComponent("helper-ready"))
                if recovered { try? FileManager.default.removeItem(at:t.root.appendingPathComponent("transaction.json")) }
            }
            return 1
        }
    }
    struct UpdateHealth: Codable { let token,version:String;let pid:Int32 }
    static func clearReady(token: String) {
        if let ready=try? read(ReadyUpdate.self,at:base.appendingPathComponent("ready.json")),ready.token==token { try? FileManager.default.removeItem(at:base.appendingPathComponent("ready.json")) }
    }
    static func pruneCache() {
        let fm=FileManager.default
        if let ready=try? read(ReadyUpdate.self,at:base.appendingPathComponent("ready.json")),UUID(uuidString:ready.token) != nil,
           let version=UpdateVersion(ready.release.version),let current=UpdateVersion(currentVersion),version<=current,
           root(ready.token).standardizedFileURL==root(ready.token).resolvingSymlinksInPath(),
           !fm.fileExists(atPath:root(ready.token).appendingPathComponent("transaction.json").path) {
            clearReady(token:ready.token);try? fm.removeItem(at:root(ready.token))
        }
        let ready=(try? read(ReadyUpdate.self,at:base.appendingPathComponent("ready.json")))?.token
        for folder in (try? fm.contentsOfDirectory(at:base,includingPropertiesForKeys:[.contentModificationDateKey])) ?? [] {
            guard UUID(uuidString:folder.lastPathComponent) != nil,folder.lastPathComponent != ready,
                  folder.standardizedFileURL==folder.resolvingSymlinksInPath(),!fm.fileExists(atPath:folder.appendingPathComponent("transaction.json").path),
                  let date=(try? folder.resourceValues(forKeys:[.contentModificationDateKey]))?.contentModificationDate,Date().timeIntervalSince(date)>7*86400 else { continue }
            try? fm.removeItem(at:folder)
        }
    }
    static func cleanupConfirmed() {
        let fm=FileManager.default
        for root in (try? fm.contentsOfDirectory(at:base,includingPropertiesForKeys:nil)) ?? [] {
            guard UUID(uuidString:root.lastPathComponent) != nil, root.standardizedFileURL==root.resolvingSymlinksInPath(),
                  fm.fileExists(atPath:root.appendingPathComponent("complete").path),
                  let ticket=try? read(UpdateTicket.self,at:root.appendingPathComponent("transaction.json")), ticket.token==root.lastPathComponent,
                  ticket.target==Bundle.main.bundleURL.path, let version=UpdateVersion(ticket.release.version),
                  let current=UpdateVersion(currentVersion), current>=version else { continue }
            do { try UpdateReplacement(target:Bundle.main.bundleURL,token:ticket.token).complete();clearReady(token:ticket.token);try fm.removeItem(at:root) }
            catch { NSLog("Update cleanup deferred: %@",error.localizedDescription) }
        }
    }
    static func confirmHealthy(desktop: DesktopController) {
        cleanupConfirmed()
        // A power loss before replacement must not leave an un-installable candidate.
        for token in (try? FileManager.default.contentsOfDirectory(atPath:base.path)) ?? [] {
            guard let ticket=try? load(token,allowExpired:true),ticket.target==Bundle.main.bundleURL.path,
                  let version=UpdateVersion(ticket.release.version),let current=UpdateVersion(currentVersion),version>current,
                  let replacement=try? UpdateReplacement(target:Bundle.main.bundleURL,token:token),
                  !FileManager.default.fileExists(atPath:replacement.backup.path) else { continue }
            let pid=(try? String(contentsOf:ticket.root.appendingPathComponent("helper-pid"),encoding:.utf8)).flatMap{Int32($0)}
            guard pid.map(alive) != true else { continue }
            do {
                if FileManager.default.fileExists(atPath:replacement.candidate.path) { try FileManager.default.removeItem(at:replacement.candidate) }
                try FileManager.default.removeItem(at:ticket.root.appendingPathComponent("transaction.json"))
            } catch { NSLog("Update recovery deferred: %@",error.localizedDescription) }
        }
        // Also recover an interrupted transaction after a normal/manual launch.
        let explicit=argument("--update-launch")
        let candidates=explicit.map{[$0]} ?? ((try? FileManager.default.contentsOfDirectory(atPath:base.path)) ?? [])
        guard let ticket=candidates.compactMap({try? load($0,allowExpired:true)}).first(where:{$0.target==Bundle.main.bundleURL.path && $0.release.version==currentVersion}) else { return }
        let token=ticket.token
        DispatchQueue.main.asyncAfter(deadline:.now()+10) { [weak desktop] in
            guard let desktop, desktop.timer?.isValid == true, !desktop.panels.isEmpty else { return }
            try? write(UpdateHealth(token:token,version:currentVersion,pid:ProcessInfo.processInfo.processIdentifier),to:ticket.root.appendingPathComponent("healthy.json"))
            DispatchQueue.global(qos:.utility).asyncAfter(deadline:.now()+3) {
                let pid=(try? String(contentsOf:ticket.root.appendingPathComponent("helper-pid"),encoding:.utf8)).flatMap{Int32($0)}
                if pid.map(alive) != true {
                    try? Data().write(to:ticket.root.appendingPathComponent("complete"),options:.atomic)
                    cleanupConfirmed()
                }
            }
        }
    }
}

struct ReadyUpdate: Codable { let token: String;let release: UpdateRelease }
