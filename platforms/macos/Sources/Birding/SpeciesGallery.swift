import AppKit
import BirdingCore

private let galleryBackground=NSColor(white:238.0/255.0,alpha:1)

final class SpeciesGallery:NSWindowController {
    private var timer:Timer?
    private var grid:BirdGalleryView!
    private var actions:NSSegmentedControl!
    private var scroll:NSScrollView!
    func refreshMode() {
        guard let content=window?.contentView else { return }
        let observing=grid.desktop.lifeList.enabled
        actions.isHidden=observing
        let frame=NSRect(x:0,y:0,width:content.bounds.width,height:content.bounds.height-(observing ? 0 : 52))
        if scroll.frame != frame { scroll.frame=frame }
    }
    @objc func selectAction(_ sender:NSSegmentedControl) {
        grid.action=GalleryAction(rawValue:sender.selectedSegment) ?? .resting
        grid.started=ProcessInfo.processInfo.systemUptime
        grid.needsDisplay=true
    }
    init(desktop:DesktopController) {
        let w=NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:690),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        w.minSize=NSSize(width:900,height:400)
        w.title=desktop.lifeList.enabled ? desktop.t("Life List（鸟种记录）", "Life List") : desktop.t("图鉴","Field guide");w.isReleasedWhenClosed=false
        w.appearance=NSAppearance(named:.aqua);w.backgroundColor = galleryBackground
        w.contentView!.wantsLayer=true;w.contentView!.layer?.backgroundColor=galleryBackground.cgColor
        super.init(window:w)
        let barHeight:CGFloat=52
        let labels=[desktop.t("休息","Rest"),desktop.t("飞行","Flight"),desktop.t("振翅","Flapping"),desktop.t("滑翔","Gliding"),desktop.t("着陆","Landing"),desktop.t("理羽","Preening"),desktop.t("其他","Other")]
        actions=NSSegmentedControl(labels:labels,trackingMode:.selectOne,target:self,action:#selector(selectAction(_:)))
        actions.selectedSegment=0;actions.frame=NSRect(x:16,y:w.contentView!.bounds.height-barHeight+12,width:840,height:28)
        actions.autoresizingMask=[.width,.minYMargin];actions.setAccessibilityLabel(desktop.t("图鉴动作","Field guide action"))
        w.contentView!.addSubview(actions)
        scroll=NSScrollView(frame:NSRect(x:0,y:0,width:w.contentView!.bounds.width,height:w.contentView!.bounds.height-barHeight));scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true;scroll.drawsBackground=true;scroll.backgroundColor = galleryBackground
        grid=BirdGalleryView(desktop:desktop);grid.updateLayout()
        let grid=self.grid!
        scroll.documentView=grid;w.contentView!.addSubview(scroll);w.center();refreshMode()
        timer=Timer(timeInterval:1/30,repeats:true){[weak self,weak grid] _ in
            guard self?.window?.isVisible == true else {return};self?.refreshMode();grid?.updateLayout();grid?.needsDisplay=true
        }
        RunLoop.main.add(timer!,forMode:.common)
    }
    required init?(coder:NSCoder){fatalError()}
    deinit {timer?.invalidate()}
}
final class BirdGalleryView:NSView {
    unowned let desktop:DesktopController
    var started=ProcessInfo.processInfo.systemUptime
    var action:GalleryAction = .resting
    var profiles:[SpeciesProfile] {
        let all=desktop.catalog.species
        guard desktop.lifeList.enabled else { return all }
        return all.sorted { a,b in
            let x=desktop.lifeList.records[a.id.rawValue]?.firstRecordedAt, y=desktop.lifeList.records[b.id.rawValue]?.firstRecordedAt
            if x != y { return (x ?? .distantPast) > (y ?? .distantPast) }
            return a.id.rawValue < b.id.rawValue
        }
    }
    var maxScale:CGFloat {desktop.scale * (desktop.catalog.species.map(\.relativeScale).max() ?? 1)}
    var topTrim:CGFloat {
        guard desktop.lifeList.enabled else {return 0}
        return desktop.catalog.species.map { p in
            let scale=desktop.scale*p.relativeScale
            return 39*maxScale-39*scale+CGFloat(desktop.arts[p.id]!.topPixel(frame:"stand"))*scale
        }.min() ?? 0
    }
    var cellWidth:CGFloat {max(220,ceil(48*maxScale)+32)}
    var cellHeight:CGFloat {ceil(48*maxScale-topTrim)+68}
    var columns:Int {max(1,Int(880/cellWidth))}
    func updateLayout() {
        let size=NSSize(width:max(880,cellWidth),height:CGFloat((max(1,profiles.count)+columns-1)/columns)*cellHeight)
        if frame.size != size {setFrameSize(size)}
    }
    override var isFlipped:Bool {true}
    init(desktop:DesktopController){self.desktop=desktop;super.init(frame:.zero)}
    required init?(coder:NSCoder){fatalError()}
    func actionName(_ p:String) -> String {
        if p.hasPrefix("bank"){return desktop.t("盘旋展翼","Banking")}
        if p.hasPrefix("glide"){return desktop.t("展开翅膀滑翔","Gliding")}
        if p == "bound"{return desktop.t("收翅起伏飞行","Bounding")}
        if p.hasPrefix("idle"){return desktop.t("习性动作","Characteristic action")}
        if p.hasPrefix("fly"){return desktop.t("振翅飞行","Flapping flight")}
        if p.hasPrefix("land"){return desktop.t("着陆","Landing")}
        if p.hasPrefix("preen"){return desktop.t("理羽","Preening")}
        if p.hasPrefix("peck"){return desktop.t("啄击","Pecking")}
        if p.hasPrefix("cling"){return desktop.t("侧边停靠","Clinging")}
        if p.hasPrefix("poop"){return desktop.t("挤洗手液","Dropping")}
        if p == "stretch"{return desktop.t("伸颈","Stretching")}
        if p == "shake"{return desktop.t("抖毛","Shaking")}
        return desktop.t("休息与张望","Resting & watching")
    }
    override func draw(_ dirtyRect:NSRect) {
        galleryBackground.setFill();dirtyRect.fill()
        guard let ctx=NSGraphicsContext.current?.cgContext else{return}
        let age=ProcessInfo.processInfo.systemUptime-started
        let count=desktop.catalog.species.filter{desktop.lifeList.records[$0.id.rawValue] != nil}.count
        window?.title=desktop.lifeList.enabled ? desktop.t("Life List（鸟种记录）· \(count) / \(desktop.catalog.species.count) 种", "Life List · \(count) / \(desktop.catalog.species.count) species") : desktop.t("图鉴", "Field guide")
        if profiles.isEmpty {
            (desktop.t("还没有记录，开启观鸟后点击桌面上的鸟来加新。", "No observations yet. Enable recording and click a desktop bird.") as NSString).draw(at:NSPoint(x:24,y:30),withAttributes:[.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.darkGray])
        }
        for (i,p) in profiles.enumerated() {
            let record=desktop.lifeList.enabled ? desktop.lifeList.records[p.id.rawValue] : nil
            let hidden=desktop.lifeList.enabled && record == nil
            let cell=NSRect(x:CGFloat(i%columns)*cellWidth,y:CGFloat(i/columns)*cellHeight,width:cellWidth,height:cellHeight)
            let scale=desktop.scale*p.relativeScale
            let labelY=cell.minY+ceil(48*maxScale-topTrim)+8
            guard cell.intersects(dirtyRect) else {continue}
            let pose=desktop.lifeList.enabled ? "stand" : GalleryPose.frame(p.id,age:age,fps:p.flapFPS,action:action,speedMultiplier:p.speed)
            ctx.saveGState()
            if hidden { ctx.beginTransparencyLayer(auxiliaryInfo:nil) }
            desktop.arts[p.id]!.draw(name:pose,at:CGPoint(x:cell.midX+5*scale,y:cell.minY+8+39*maxScale-topTrim),scale:scale,right:true,context:ctx)
            if hidden {
                ctx.setBlendMode(.sourceIn);ctx.setFillColor(NSColor.darkGray.cgColor);ctx.fill(cell);ctx.endTransparencyLayer()
            }
            ctx.restoreGState()
            let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
            let style:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.black,.paragraphStyle:paragraph]
            ((hidden ? desktop.t("未记录", "Unrecorded") : desktop.language.name(p.id)) as NSString).draw(in:NSRect(x:cell.minX+5,y:labelY,width:cell.width-10,height:32),withAttributes:style)
            let dateFormatter=DateFormatter();dateFormatter.locale=Locale(identifier:desktop.language == .chinese ? "zh_CN" : "en_US");dateFormatter.dateFormat = "yyyy/MM/dd"
            if let record {
                let badge="x\(record.count)" as NSString
                let badgeStyle:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.darkGray]
                let size=badge.size(withAttributes:badgeStyle)
                let x=min(cell.maxX-size.width-5,cell.midX+24*scale+3)
                let y=cell.minY+8+39*maxScale-topTrim+9*scale-size.height
                badge.draw(at:NSPoint(x:x,y:y),withAttributes:badgeStyle)
            }
            let detail=record.map { dateFormatter.string(from:$0.firstRecordedAt) } ?? (hidden ? "" : actionName(pose))
            (detail as NSString).draw(in:NSRect(x:cell.minX+5,y:labelY+32,width:cell.width-10,height:24),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.darkGray,.paragraphStyle:paragraph])
        }
    }
}
