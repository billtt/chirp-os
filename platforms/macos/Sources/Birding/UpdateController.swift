import AppKit
import BirdingCore

private final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let limit:Int64
    init(limit:Int64) { self.limit=limit }
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL) {}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {
        if totalBytesWritten>limit || totalBytesExpectedToWrite>limit { downloadTask.cancel() }
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) {
        let hosts=["github.com","release-assets.githubusercontent.com","objects.githubusercontent.com"]
        completionHandler(request.url?.scheme == "https" && hosts.contains(request.url?.host ?? "") ? request:nil)
    }
}

final class UpdateController: NSObject {
    weak var desktop:DesktopController?
    private(set) var pending:ReadyUpdate?
    private(set) var busy=false
    private(set) var installing=false
    private(set) var statusText=""
    private var confirming=false
    private var journal=UpdateJournal()
    private var timer:Timer?
    private(set) var bubble:NSPanel?
    private var bubbleTimer:Timer?
    private let session:URLSession
    private let stateFile:URL
    init(desktop:DesktopController,stateFile:URL = UpdateInstaller.base.appendingPathComponent("state.json")) {
        self.stateFile=stateFile
        self.desktop=desktop
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=30;config.timeoutIntervalForResource=900
        config.httpAdditionalHeaders=["User-Agent":"ChirpOS/\(UpdateInstaller.currentVersion)","Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"]
        session=URLSession(configuration:config)
        super.init()
        journal=(try? UpdateInstaller.read(UpdateJournal.self,at:stateFile)) ?? UpdateJournal()
    }
    func start() {
        do {
            try FileManager.default.createDirectory(at:UpdateInstaller.base,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            journal=(try? UpdateInstaller.read(UpdateJournal.self,at:stateFile)) ?? UpdateJournal()
            UpdateInstaller.pruneCache()
            // Clock corrections cannot postpone checks indefinitely.
            if journal.nextCheck.timeIntervalSinceNow>3600 { journal.nextCheck=Date() }
        } catch { statusText=error.localizedDescription;return }
        timer=Timer(timeInterval:60,repeats:true) { [weak self] _ in self?.check() }
        RunLoop.main.add(timer!,forMode:.common)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let previousError=UpdateInstaller.base.appendingPathComponent("last-error.txt")
            if FileManager.default.fileExists(atPath:previousError.path) {
                showBubble(desktop?.t("上次更新未完成，可从菜单重试。","The last update did not finish; retry from the menu.") ?? "",actionable:false)
                try? FileManager.default.removeItem(at:previousError)
            }
            if let ready=try? UpdateInstaller.read(ReadyUpdate.self,at:UpdateInstaller.base.appendingPathComponent("ready.json")), UUID(uuidString:ready.token) != nil,
               let version=UpdateVersion(ready.release.version), let current=UpdateVersion(UpdateInstaller.currentVersion), version>current {
                busy=true
                do {
                    try await Task.detached { try UpdateInstaller.stage(release:ready.release,token:ready.token,target:Bundle.main.bundleURL) }.value
                    acceptVerifiedUpdate(ready)
                } catch { statusText=error.localizedDescription;UpdateInstaller.clearReady(token:ready.token) }
                busy=false;refresh()
            }
            // Give startup and the species migration prompt time to settle.
            try? await Task.sleep(nanoseconds:15_000_000_000)
            check()
        }
    }
    private func saveJournal() throws { try UpdateInstaller.write(journal,to:stateFile) }
    private func refresh() { desktop?.makeMenu() }
    func check(manual:Bool=false) {
        guard !busy,!installing,!confirming,manual || Date()>=journal.nextCheck else { return }
        busy=true;statusText=desktop?.t("正在检查更新…","Checking for updates…") ?? "";refresh()
        Task { @MainActor [weak self] in
            guard let self else { return }
            var temporary:String?
            do {
                let (data,response)=try await session.data(from:UpdateRelease.endpoint)
                guard let response=response as? HTTPURLResponse else { throw UpdateFailure.invalid("Invalid update response") }
                if response.statusCode != 404 {
                    guard response.statusCode == 200 else { throw UpdateFailure.invalid("Update server returned HTTP \(response.statusCode)") }
                    if let release=try UpdateRelease.select(data,current:UpdateInstaller.currentVersion,platform:UpdateInstaller.platform) {
                        if pending?.release != release {
                            statusText=desktop?.t("正在下载并校验更新…","Downloading and verifying update…") ?? "";refresh()
                            let token=UUID().uuidString;temporary=token
                            let root=UpdateInstaller.root(token)
                            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
                            let free=(try FileManager.default.attributesOfFileSystem(forPath:root.path)[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                            guard free>release.size*4+100_000_000 else { throw UpdateFailure.invalid("Not enough free space for the update") }
                            let delegate=UpdateDownloadDelegate(limit:release.size)
                            let (file,downloadResponse)=try await session.download(from:URL(string:release.downloadURL)!,delegate:delegate)
                            guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.invalid("Update download failed") }
                            try FileManager.default.moveItem(at:file,to:root.appendingPathComponent("package.zip"))
                            let target=Bundle.main.bundleURL
                            try await Task.detached { try UpdateInstaller.stage(release:release,token:token,target:target) }.value
                            let ready=ReadyUpdate(token:token,release:release)
                            try UpdateInstaller.write(ready,to:UpdateInstaller.base.appendingPathComponent("ready.json"))
                            let previous=pending;temporary=nil
                            if let previous { try? FileManager.default.removeItem(at:UpdateInstaller.root(previous.token)) }
                            acceptVerifiedUpdate(ready)
                        }
                    } else if manual { showBubble(desktop?.t("目前已是最新可用版本。","You have the latest available version.") ?? "",actionable:false) }
                } else if manual { showBubble(desktop?.t("暂无可用的新版本。","No new release is available.") ?? "",actionable:false) }
                journal.finishCheck(now:Date(),success:true);statusText=""
            } catch {
                if let temporary { try? FileManager.default.removeItem(at:UpdateInstaller.root(temporary)) }
                journal.finishCheck(now:Date(),success:false)
                statusText=desktop?.t("更新检查失败，将自动重试","Update check failed; retry scheduled") ?? ""
                NSLog("Update check: %@",error.localizedDescription)
                if manual { showBubble(String(error.localizedDescription.prefix(220)),actionable:false) }
            }
            try? saveJournal();busy=false;refresh()
        }
    }
    func acceptVerifiedUpdate(_ ready:ReadyUpdate) { pending=ready;announceIfNeeded();refresh() }
    private func announceIfNeeded() {
        guard let pending,journal.announce(pending.release.version) else { return }
        // Persist before showing: ignoring a bubble, closing the app or choosing
        // Later must not cause another unsolicited alert for this version.
        do { try saveJournal() } catch { return }
        refresh()
        showBubble(desktop?.t("\(pending.release.version) 已下载并校验，点击查看更新。","\(pending.release.version) is ready. Click to review the update.") ?? "",actionable:true)
    }
    func decorate(_ image:NSImage) -> NSImage {
        guard pending != nil else { return image }
        let decorated=NSImage(size:image.size)
        decorated.lockFocus();image.draw(at:.zero,from:.zero,operation:.sourceOver,fraction:1)
        NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:16,y:16,width:8,height:8)).fill()
        NSColor.systemRed.setFill();NSBezierPath(ovalIn:NSRect(x:17,y:17,width:6,height:6)).fill()
        decorated.unlockFocus();return decorated
    }
    func addMenuItems(to menu:NSMenu) {
        guard let desktop else { return }
        if let pending {
            let item=NSMenuItem(title:installing ? desktop.t("正在安装更新…","Installing update…") : desktop.t("安装更新 \(pending.release.version)…","Install update \(pending.release.version)…"),action:#selector(confirmUpdate),keyEquivalent:"")
            item.target=self;item.isEnabled = !installing && !busy;menu.addItem(item)
        }
        if !statusText.isEmpty { let item=NSMenuItem(title:statusText,action:nil,keyEquivalent:"");item.isEnabled=false;menu.addItem(item) }
        let check=NSMenuItem(title:desktop.t("检查更新…","Check for updates…"),action:#selector(manualCheck),keyEquivalent:"")
        check.target=self;check.isEnabled = !busy && !installing;menu.addItem(check)
    }
    @objc private func manualCheck() { check(manual:true) }
    @objc func confirmUpdate() {
        guard let ready=pending,let desktop,!installing,!busy,!confirming else { return }
        confirming=true;defer { confirming=false }
        bubble?.orderOut(nil)
        let alert=confirmationDialog(for:ready)
        NSApp.activate(ignoringOtherApps:true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        installing=true;refresh()
        let ticket=UpdateTicket(token:ready.token,release:ready.release,target:Bundle.main.bundleURL.path,parentPID:ProcessInfo.processInfo.processIdentifier,created:Date())
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.detached { try UpdateInstaller.prepare(ticket) }.value
                var helperReady=false
                for _ in 0..<100 {
                    if FileManager.default.fileExists(atPath:ticket.root.appendingPathComponent("helper-ready").path) { helperReady=true;break }
                    try await Task.sleep(nanoseconds:100_000_000)
                }
                guard helperReady else {
                    try? Data().write(to:ticket.root.appendingPathComponent("cancel"),options:.atomic)
                    throw UpdateFailure.invalid("Update helper could not start; the current version will keep running")
                }
                NSApp.terminate(nil)
            } catch {
                installing=false;statusText=desktop.t("更新安装失败，可从菜单重试","Installation failed; retry from the menu")
                showBubble(String(error.localizedDescription.prefix(220)),actionable:false);refresh()
            }
        }
    }
    func confirmationDialog(for ready:ReadyUpdate) -> NSAlert {
        let desktop=desktop!
        let alert=NSAlert();alert.messageText=desktop.t("安装啾啾 \(ready.release.version)？","Install ChirpOS \(ready.release.version)?")
        alert.icon=NSImage(cgImage:desktop.art.frames["stand"]!,size:NSSize(width:64,height:64))
        alert.informativeText=desktop.t("更新已下载并校验。安装后应用将自动重启，设置会保留。","The update is downloaded and verified. ChirpOS will restart and keep your settings.")
        let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:480,height:250));scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder
        let notes=NSTextView(frame:scroll.bounds);notes.isEditable=false;notes.isRichText=false;notes.font = .systemFont(ofSize:13)
        notes.string=ready.release.notes.isEmpty ? desktop.t("此版本未提供更新说明。","No release notes were provided."):ready.release.notes
        notes.textContainerInset=NSSize(width:10,height:10);scroll.documentView=notes;alert.accessoryView=scroll
        alert.addButton(withTitle:desktop.t("安装并重启","Install and restart"));alert.addButton(withTitle:desktop.t("晚点再说","Later"))
        return alert
    }
    @objc private func bubbleClicked() { confirmUpdate() }
    private func showBubble(_ text:String,actionable:Bool) {
        guard let button=desktop?.status?.button,let statusWindow=button.window else { return }
        bubbleTimer?.invalidate();bubble?.orderOut(nil)
        let panel=OverlayPanel(contentRect:NSRect(x:0,y:0,width:330,height:92),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.level = .popUpMenu;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=true;panel.hidesOnDeactivate=false;panel.isReleasedWhenClosed=false
        let background=NSVisualEffectView(frame:NSRect(x:0,y:0,width:330,height:92));background.material = .popover;background.state = .active;background.wantsLayer=true;background.layer?.cornerRadius=12
        let label=NSButton(title:text,target:actionable ? self:nil,action:actionable ? #selector(bubbleClicked):nil)
        label.frame=NSRect(x:14,y:10,width:302,height:72);label.isBordered=false;label.font = .systemFont(ofSize:13);label.cell?.wraps=true
        background.addSubview(label);panel.contentView=background
        let screen=statusWindow.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        panel.setFrameOrigin(NSPoint(x:min(screen.maxX-340,max(screen.minX+10,statusWindow.frame.midX-165)),y:screen.maxY-102))
        panel.orderFrontRegardless();bubble=panel
        bubbleTimer=Timer.scheduledTimer(withTimeInterval:12,repeats:false) { [weak self] _ in self?.bubble?.orderOut(nil) }
    }
    deinit { timer?.invalidate();bubbleTimer?.invalidate();session.invalidateAndCancel() }
}
