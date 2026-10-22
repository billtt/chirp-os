import AppKit
import BirdingCore

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// Layer-hosted view: only tiny sprite textures change. Avoid AppKit's growing
// full-screen display lists during continuous partial redraw on macOS 26.
final class DesktopView: NSView {
    weak var controller: DesktopController?
    var desktopRect: CGRect = .zero
    private var sprites: [CALayer] = []
    private let nameLabel=CATextLayer()
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override init(frame: NSRect) {
        super.init(frame: frame)
        let root = CALayer()
        root.isGeometryFlipped = true
        root.backgroundColor = NSColor.clear.cgColor
        root.frame = bounds
        layer = root; wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func updateSprites() {
        guard let controller, let root = layer else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        while sprites.count > controller.birds.count { sprites.removeLast().removeFromSuperlayer() }
        while sprites.count < controller.birds.count {
            let container = CALayer()
            let texture = CALayer()
            texture.magnificationFilter = .nearest; texture.minificationFilter = .nearest
            container.addSublayer(texture); container.mask = CAShapeLayer()
            root.addSublayer(container); sprites.append(container)
        }
        for (index,bird) in controller.birds.enumerated() {
            let container = sprites[index]
            let scale = controller.spriteScale(for:bird)
            let side = 48*scale
            let rect = CGRect(x:bird.position.x-(bird.facingRight ? 29 : 19)*scale,
                              y:bird.position.y+(bird.hopOffset-39)*scale,width:side,height:side)
            let pieces = Geometry.visiblePieces(rect,blockers:bird.blockers(in:controller.surfaces))
            container.isHidden = !rect.intersects(desktopRect) || pieces.isEmpty
            guard !container.isHidden else { continue }
            container.frame = rect.offsetBy(dx:-desktopRect.minX,dy:-desktopRect.minY)
            let texture = container.sublayers![0]
            texture.bounds = CGRect(x:0,y:0,width:side,height:side)
            texture.position = CGPoint(x:side/2,y:side/2)
            texture.setAffineTransform(CGAffineTransform(scaleX:bird.facingRight ? 1 : -1,y:1))
            texture.contents = controller.arts[bird.profile.id]!.frames[bird.frameName]
            let path = CGMutablePath()
            for piece in pieces { path.addRect(piece.offsetBy(dx:-rect.minX,dy:-rect.minY)) }
            let mask = container.mask as! CAShapeLayer
            mask.frame = CGRect(origin:.zero,size:rect.size)
            mask.path = path; mask.fillColor = NSColor.black.cgColor
        }
        if nameLabel.superlayer == nil {
            nameLabel.fontSize=13;nameLabel.alignmentMode = .center
            nameLabel.foregroundColor=NSColor.white.cgColor
            nameLabel.backgroundColor=NSColor.black.withAlphaComponent(0.8).cgColor
            nameLabel.cornerRadius=6;nameLabel.contentsScale=window?.backingScaleFactor ?? 2
            root.addSublayer(nameLabel)
        }
        nameLabel.zPosition=1000
        nameLabel.isHidden=true
        if let bird=controller.hoveredBird, desktopRect.contains(bird.position) {
            let text=controller.language.name(bird.profile.id)
            let width=min(desktopRect.width,ceil((text as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:13)]).width)+20)
            let pixel=controller.arts[bird.profile.id]!.topPixel(frame:bird.frameName)
            let top=bird.position.y+(CGFloat(pixel)+bird.hopOffset-39)*controller.spriteScale(for:bird)
            let x=min(desktopRect.maxX-width,max(desktopRect.minX,bird.position.x-width/2))
            let y=max(desktopRect.minY,top-28)
            nameLabel.frame=CGRect(x:x-desktopRect.minX,y:y-desktopRect.minY,width:width,height:23)
            nameLabel.string=text;nameLabel.isHidden=false
        }
        CATransaction.commit()
    }
}

final class DesktopController: NSObject {
    var loginService: LoginItemManaging = SystemLoginItem()
    var loginItem: NSMenuItem?
    var loginApprovalItem: NSMenuItem?
    let art = BirdArt()
    let arts = Dictionary(uniqueKeysWithValues: SpeciesID.allCases.map { ($0, BirdArt(species:$0)) })
    var settings = BirdSettings()
    var catalog: SpeciesCatalog { settings.catalog }
    var preferences = UserDefaults.standard
    var language = AppLanguage.chinese
    var gallery:SpeciesGallery?
    var settingsWindow: SpeciesSettingsWindow?
    var settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Birding/settings.json")
    var legacyURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Birding/species.json")
    func t(_ zh:String,_ en:String) -> String { language.text(zh,en) }
    func spriteScale(for bird: Bird) -> CGFloat { scale * bird.profile.relativeScale }
    func loadSpeciesConfig() throws { settings = try BirdSettings.load(from:settingsURL,legacyURL:legacyURL) }
    func applySettings(_ value:BirdSettings) throws {
        var saved=value;saved.pendingSpecies=[]
        try saved.save(to:settingsURL)
        settings = saved
    }
    @objc func showSpeciesGallery() {
        if gallery == nil {gallery=SpeciesGallery(desktop:self)}
        gallery?.showWindow(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func showSpeciesSettings() {
        if let settingsWindow, settingsWindow.window?.isVisible == true {
            settingsWindow.window?.makeKeyAndOrderFront(nil)
        } else {
            settingsWindow = SpeciesSettingsWindow(desktop:self)
            settingsWindow?.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps:true)
    }
    @objc func toggleLanguage() {
        language = language == .chinese ? .english : .chinese
        preferences.set(language.rawValue,forKey:"appLanguage")
        makeMenu(); settingsWindow?.relocalize()
    }
    func updateStatusLine() {
        statusLine.title = t("桌面鸟群 · \(residentCount) 只 · \(birds.count-residentCount) 只正在离开",
                             "Birds · \(residentCount) visiting · \(birds.count-residentCount) departing")
    }
    var hoverTracker=HoverTracker<ObjectIdentifier>()
    weak var hoveredBird:Bird?
    var birds: [Bird] = []
    var surfaces: [Surface] = [] // Front to back, exactly as supplied by WindowServer.
    var panels: [OverlayPanel] = []
    var views: [DesktopView] = []
    var population = Population()
    var populationMenu: NSMenu!
    var populationItem: NSMenuItem!
    var automaticPopulation = true
    var lastArrivalPosition: CGPoint?
    var arrivalCount = 0
    var departureCount = 0
    var scale: CGFloat = 1
    var paused = false
    var timer: Timer?
    var lastTick = ProcessInfo.processInfo.systemUptime
    var lastSample: Double = 0
    var lastDiagnostic: Double = 0
    var status: NSStatusItem!
    var statusLine: NSMenuItem!
    var diagnosticPath: String?
    var integration: IntegrationCheck?
    var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 900 }
    var screenRects: [CGRect] { NSScreen.screens.map { Geometry.quartz($0.visibleFrame, primaryHeight: primaryHeight) } }
    var displayRects: [CGRect] { NSScreen.screens.map { Geometry.quartz($0.frame, primaryHeight: primaryHeight) } }
    var residentCount: Int { birds.filter { !$0.isDeparting }.count }
    func start() {
        language = AppLanguage(rawValue:preferences.string(forKey:"appLanguage") ?? "zh") ?? .chinese
        if let saved = PopulationRange(lower: UserDefaults.standard.integer(forKey:"populationLower"), upper: UserDefaults.standard.integer(forKey:"populationUpper")) {
            population = Population(range:saved)
        }
        do { try loadSpeciesConfig() } catch { NSLog("Birding species configuration: %@; using bundled defaults",error.localizedDescription) }
        makeMenu(); rebuildScreens()
        if !CommandLine.arguments.contains(where:{$0.hasPrefix("--verify") || $0 == "--integration"}) {DispatchQueue.main.async { [weak self] in self?.promptNewSpecies() }}
        sampleWindows(dt: 1.0/30)
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildScreens), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(waking), name: NSWorkspace.didWakeNotification, object: nil)
        startTimer()
    }
    func startTimer() {
        timer?.invalidate()
        lastTick = ProcessInfo.processInfo.systemUptime
        let t = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.003
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    @objc func sleeping() { timer?.invalidate() }
    @objc func waking() { lastSample = 0; startTimer() }
    @objc func spaceChanged() { lastSample = 0; sampleWindows(dt: 1); for v in views { v.needsDisplay = true } }
    @objc func rebuildScreens() {
        panels.forEach { $0.orderOut(nil) }; panels.removeAll(); views.removeAll()
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false; panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
            panel.animationBehavior = .none
            let view = DesktopView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.controller = self; view.desktopRect = Geometry.quartz(screen.frame, primaryHeight: primaryHeight)
            panel.contentView = view; panel.orderFrontRegardless()
            panels.append(panel); views.append(view)
        }
        for bird in birds { if bird.isDeparting { sendAway(bird) } else { chooseDestination(bird) } }
    }
    func sampleWindows(dt: Double) {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        // Higher levels (menus, security/lock screen) already cover our panel in WindowServer.
        // Software masking is only needed for windows that the floating overlay covers.
        let own = ProcessInfo.processInfo.processIdentifier
        surfaces = list.compactMap { info in
            guard let id = info[kCGWindowNumber as String] as? UInt32,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != own,
                  let layer = info[kCGWindowLayer as String] as? Int, layer >= 0, layer <= NSWindow.Level.floating.rawValue,
                  let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0.05,
                  let raw = info[kCGWindowBounds as String] as? [String:Any],
                  let rect = CGRect(dictionaryRepresentation: raw as CFDictionary), rect.width > 1, rect.height > 1 else { return nil }
            if layer == NSWindow.Level.floating.rawValue,
               NSRunningApplication(processIdentifier:pid)?.bundleIdentifier == "dev.birding.desktop" { return nil }
            return Surface(id: id, pid: pid, rect: rect, layer: layer)
        }
        for bird in birds { bird.updateHost(surfaces: surfaces, sampleDT: dt, spriteScale: spriteScale(for:bird)) }
    }
    func bounds(of bird: Bird) -> CGRect {
        let scale = spriteScale(for:bird)
        return CGRect(x: bird.position.x - (bird.facingRight ? 29 : 19)*scale,
               y: bird.position.y+(bird.hopOffset-39)*scale, width: 48*scale, height: 48*scale).insetBy(dx: -2,dy: -2)
    }
    func chooseDestination(_ bird: Bird, entering: Bool = false) {
        guard !bird.isDeparting else { return }
        let scale = spriteScale(for:bird)
        func airspace(_ point: CGPoint) -> CGRect? {
            screenRects.first(where: { $0.contains(point) }).map {
                CGRect(x: $0.minX + 29*scale, y: $0.minY + 39*scale,
                       width: max(0, $0.width - 58*scale), height: max(0, $0.height - 48*scale))
            }
        }
        func duration(to point: CGPoint) -> Double {
            entering ? max(2.8, Double(Geometry.distance(bird.position,point))/400 * Bird.flightSpeedMultiplier) : Double.random(in:2.6...4.8)
        }
        let occupied = birds.filter { $0 !== bird && !$0.isDeparting }.compactMap { other -> CGRect? in
            guard let id = other.hostID, let host = surfaces.first(where: { $0.id == id }) else { return nil }
            let foot = Geometry.foot(on:host,fraction:other.fraction,edge:other.edge)
            return Geometry.landingFootprint(at: foot, scale: spriteScale(for: other)).insetBy(dx: -8, dy: -8)
        }
        if bird.profile.id == .greatSpottedWoodpecker {
            var sides:[(Surface,PerchEdge,ClosedRange<CGFloat>)]=[]
            for host in surfaces where host.layer == 0 && host.rect.height >= 180 {
                for edge in [PerchEdge.left,.right] { for screen in screenRects {
                    for range in Geometry.sideRanges(on:host,edge:edge,surfaces:surfaces,screen:screen,scale:scale,occupied:occupied) { sides.append((host,edge,range)) }
                }}
            }
            let length=sides.reduce(CGFloat.zero){$0+$1.2.upperBound-$1.2.lowerBound}
            var ticket=CGFloat.random(in:0...max(0,length))
            for (host,edge,range) in sides {
                let n=range.upperBound-range.lowerBound
                if ticket<n {
                    bird.edge=edge;bird.fraction=(range.lowerBound+ticket-host.rect.minY-42)/(host.rect.height-84)
                    let point=Geometry.foot(on:host,fraction:bird.fraction,edge:edge)
                    bird.fly(to:point,host:host,duration:duration(to:point),airspace:airspace(point));return
                };ticket-=n
            }
        }
        bird.edge = .top
        var choices: [(Surface, ClosedRange<CGFloat>)] = []
        for host in surfaces where host.layer == 0 && host.rect.width >= 180 && host.rect.height >= 100 {
            for screen in screenRects {
                for range in Geometry.landingRanges(on: host, surfaces: surfaces, screen: screen, scale: scale, occupied: occupied) {
                    choices.append((host, range))
                }
            }
        }
        let total = choices.reduce(CGFloat.zero) { $0 + $1.1.upperBound - $1.1.lowerBound }
        if total > 0 {
            var ticket = CGFloat.random(in: 0..<total)
            for (host, range) in choices {
                let length = range.upperBound - range.lowerBound
                if ticket < length {
                    let foot = CGPoint(x: range.lowerBound + ticket, y: host.rect.minY)
                    let start = Geometry.perchX(0, rect: host.rect), end = Geometry.perchX(1, rect: host.rect)
                    bird.fraction = (foot.x - start) / (end - start)
                    bird.fly(to: foot, host: host, duration: duration(to: foot), airspace: airspace(foot))
                    return
                }
                ticket -= length
            }
        }
        guard let screen = screenRects.randomElement() else { return }
        let foot = CGPoint(x: CGFloat.random(in: (screen.minX+70)...max(screen.minX+71,screen.maxX-70)),
                           y: CGFloat.random(in: (screen.minY+110)...max(screen.minY+111,screen.maxY-80)))
        bird.fly(to: foot, host: nil, duration: entering ? duration(to:foot) : 4.5, arc: 40, airspace: airspace(foot))
    }
    func bringInBird() {
        guard let point = Migration.outsidePoint(screens:displayRects,right:Bool.random(),fraction:CGFloat.random(in:0.2...0.75),margin:80*scale*3+20) else { return }
        lastArrivalPosition = point
        let bird = Bird(position:point,fraction:CGFloat.random(in:0.12...0.88),profile:catalog.profile(settings.probabilities.choose()))
        birds.append(bird); arrivalCount += 1
        chooseDestination(bird,entering:true)
    }
    func sendAway(_ bird: Bird) {
        guard let point = Migration.outsidePoint(screens:displayRects,right:Bool.random(),fraction:CGFloat.random(in:0.2...0.75),margin:80*scale*3+20) else { return }
        let duration = max(2.8,Double(Geometry.distance(bird.position,point))/400 * Bird.flightSpeedMultiplier)
        bird.depart(to:point,duration:duration)
    }
    func updatePopulation(_ dt: Double) {
        guard automaticPopulation, integration == nil else { return }
        if let event = population.tick(dt,residents:residentCount,total:birds.count) {
            switch event {
            case .arrive: bringInBird()
            case .depart:
                if let bird = birds.filter({!$0.isDeparting}).randomElement() { sendAway(bird) }
            }
        }
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.05, max(0,now-lastTick)); lastTick = now
        if now-lastSample >= 1.0/30 {
            sampleWindows(dt: now-lastSample); lastSample = now
        }
        if !paused {
            updatePopulation(dt)
            for bird in birds { bird.tick(dt); if bird.needsDestination && integration == nil { chooseDestination(bird) } }
            birds.removeAll { bird in
                let gone = bird.departureFinished && !displayRects.contains(where: { $0.intersects(bounds(of:bird)) })
                if gone { departureCount += 1 }
                return gone
            }
        }
        updateHover(now:now)
        for view in views { view.updateSprites() }
        if now-lastDiagnostic > 1 {
            lastDiagnostic = now
            updateStatusLine()
            if let diagnosticPath { writeDiagnostics(to: diagnosticPath) }
        }
    }
    func writeDiagnostics(to path: String) {
        let obj: [String:Any] = ["windowCount": surfaces.count, "overlayCount":panels.count,
            "renderer":"Core Animation sprite layers",
            "populationRange":[population.range.lower,population.range.upper],
            "residentCount":residentCount,"departingCount":birds.count-residentCount,
            "arrivals":arrivalCount,"departures":departureCount,
            "spriteScale":scale, "flightSpeedMultiplier":Bird.flightSpeedMultiplier,
            "nonactivating":panels.allSatisfy{ !$0.canBecomeKey && !$0.canBecomeMain && $0.ignoresMouseEvents },
            "birds":birds.map{["species":$0.profile.id.rawValue,"name":$0.profile.name,"relativeScale":$0.profile.relativeScale,"state":$0.state.rawValue,"departing":$0.isDeparting,"host":$0.hostID ?? 0,"depth":$0.depthID ?? 0,"x":$0.position.x,"y":$0.position.y,"frame":$0.frameName,"followed":$0.followedDistance,"startles":$0.startledCount,"landings":$0.landedCount] as [String:Any]}]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted,.sortedKeys]) { try? data.write(to: URL(fileURLWithPath:path), options: .atomic) }
    }
    func makeMenu() {
        if status == nil { status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        let icon = NSImage(cgImage: art.frames["stand"]!, size: NSSize(width: 24,height: 24))
        status.button?.image = icon; status.button?.toolTip = t("啾啾 · 桌面观鸟","ChirpOS · Desktop Birdwatching")
        let menu = NSMenu()
        menu.delegate = self
        statusLine = NSMenuItem(title: t("桌面鸟群 · 等待第一只鸟飞来","Birds · Waiting for the first arrival"), action: nil, keyEquivalent: "")
        menu.addItem(statusLine); menu.addItem(.separator())
        add(menu,paused ? t("继续动画","Resume animation") : t("暂停动画","Pause animation"),#selector(togglePause),"p")
        add(menu,t("让小鸟飞一会儿","Let the birds fly"),#selector(scatter),"f")
        add(menu,t("大小：1× / 1.5×","Size: 1× / 1.5×"),#selector(toggleScale),"")
        populationItem = NSMenuItem(title:"",action:nil,keyEquivalent:"")
        populationMenu = NSMenu()
        for (index,label) in [t("3–5 只","3–5 birds"),t("8–12 只","8–12 birds"),t("15–20 只","15–20 birds")].enumerated() {
            let item = NSMenuItem(title:label,action:#selector(selectPopulation(_:)),keyEquivalent:"")
            item.target = self; item.tag = index; populationMenu.addItem(item)
        }
        populationMenu.addItem(.separator())
        add(populationMenu,t("自定义范围…","Custom range…"),#selector(customPopulation),"")
        populationItem.submenu = populationMenu; menu.addItem(populationItem)
        refreshPopulationMenu()
        menu.addItem(.separator())
        add(menu,t("图鉴…","Field guide…"),#selector(showSpeciesGallery),"")
        add(menu,t("鸟种设置…","Bird settings…"),#selector(showSpeciesSettings),"")
        addLoginItem(to:menu)
        add(menu,language.switchTitle,#selector(toggleLanguage),"")
        add(menu,t("打开项目说明","Open README"),#selector(openReadme),"")
        add(menu,t("退出啾啾","Quit ChirpOS"),#selector(quit),"q")
        status.menu = menu
        updateStatusLine()
        let main=NSMenu()
        let application=NSMenuItem();main.addItem(application);application.submenu=NSMenu()
        add(application.submenu!,t("退出啾啾","Quit ChirpOS"),#selector(quit),"q")
        let editItem=NSMenuItem(title:t("编辑","Edit"),action:nil,keyEquivalent:"")
        let edit=NSMenu(title:editItem.title);editItem.submenu=edit;main.addItem(editItem)
        for (title,action,key) in [(t("撤销","Undo"),"undo:","z"),(t("剪切","Cut"),"cut:","x"),(t("复制","Copy"),"copy:","c"),(t("粘贴","Paste"),"paste:","v"),(t("全选","Select All"),"selectAll:","a")] {
            edit.addItem(NSMenuItem(title:title,action:Selector(action),keyEquivalent:key))
        }
        NSApp.mainMenu=main
    }
    func add(_ menu: NSMenu,_ title: String,_ action: Selector,_ key: String) {
        let item = NSMenuItem(title:title,action:action,keyEquivalent:key); item.target = self; menu.addItem(item)
    }
    @objc func togglePause(_ sender: NSMenuItem) { paused.toggle(); sender.title = paused ? t("继续动画","Resume animation") : t("暂停动画","Pause animation") }
    @objc func scatter() { for bird in birds where !bird.isDeparting { chooseDestination(bird) } }
    @objc func toggleScale() { scale = scale == 1 ? 1.5 : 1; for v in views { v.needsDisplay = true } }
    let populationPresets = [PopulationRange.standard,PopulationRange(lower:8,upper:12)!,PopulationRange(lower:15,upper:20)!]
    func refreshPopulationMenu() {
        populationItem.title = t("鸟群范围：\(population.range.lower)–\(population.range.upper) 只","Population: \(population.range.lower)–\(population.range.upper) birds")
        for item in populationMenu.items where item.action == #selector(selectPopulation(_:)) {
            item.state = populationPresets[item.tag] == population.range ? .on : .off
        }
    }
    func applyPopulationRange(_ range: PopulationRange) {
        population.setRange(range)
        UserDefaults.standard.set(range.lower,forKey:"populationLower")
        UserDefaults.standard.set(range.upper,forKey:"populationUpper")
        refreshPopulationMenu()
    }
    @objc func selectPopulation(_ sender: NSMenuItem) { applyPopulationRange(populationPresets[sender.tag]) }
    @objc func customPopulation() {
        let alert = NSAlert()
        alert.messageText = t("设置鸟群数量范围","Set population range")
        alert.informativeText = t("输入最少和最多数量（1–50）。小鸟会陆续飞入或飞走，逐渐达到这个范围。","Enter minimum and maximum counts (1–50). Birds will gradually arrive or leave to reach this range.")
        alert.addButton(withTitle:t("保存","Save")); alert.addButton(withTitle:t("取消","Cancel"))
        let form = NSView(frame:NSRect(x:0,y:0,width:280,height:62))
        let lower = NSTextField(string:String(population.range.lower))
        let upper = NSTextField(string:String(population.range.upper))
        for (index,pair) in [(t("最少","Minimum"),lower),(t("最多","Maximum"),upper)].enumerated() {
            let label = NSTextField(labelWithString:pair.0)
            label.frame = NSRect(x:index*140,y:36,width:120,height:20)
            pair.1.frame = NSRect(x:index*140,y:4,width:120,height:26)
            form.addSubview(label); form.addSubview(pair.1)
        }
        alert.accessoryView = form
        NSApp.activate(ignoringOtherApps:true)
        while alert.runModal() == .alertFirstButtonReturn {
            if let lo = Int(lower.stringValue.trimmingCharacters(in:.whitespaces)),
               let hi = Int(upper.stringValue.trimmingCharacters(in:.whitespaces)),
               let range = PopulationRange(lower:lo,upper:hi) {
                applyPopulationRange(range); return
            }
            alert.informativeText = t("请输入 1–50 的整数，最多数量不能小于最少数量。","Enter integers from 1 to 50. Maximum must be at least minimum.")
        }
    }
    @objc func openReadme() {
        let root = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.open(root.appendingPathComponent("README.md"))
    }
    @objc func quit() { NSApp.terminate(nil) }
}
