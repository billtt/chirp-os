import AppKit
import BirdingCore

final class SpeciesGallery:NSWindowController {
    private var timer:Timer?
    private var grid:BirdGalleryView!
    private var actions:NSSegmentedControl!
    @objc func selectAction(_ sender:NSSegmentedControl) {
        grid.action=GalleryAction(rawValue:sender.selectedSegment) ?? .resting
        grid.started=ProcessInfo.processInfo.systemUptime
        grid.needsDisplay=true
    }
    init(desktop:DesktopController) {
        let w=NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:690),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        w.minSize=NSSize(width:900,height:400)
        w.title=desktop.t("图鉴","Field guide");w.isReleasedWhenClosed=false
        w.appearance=NSAppearance(named:.aqua);w.backgroundColor = .white
        w.contentView!.wantsLayer=true;w.contentView!.layer?.backgroundColor=NSColor.white.cgColor
        super.init(window:w)
        let barHeight:CGFloat=52
        let labels=[desktop.t("休息","Rest"),desktop.t("飞行","Flight"),desktop.t("振翅","Flapping"),desktop.t("滑翔","Gliding"),desktop.t("着陆","Landing"),desktop.t("理羽","Preening"),desktop.t("其他","Other")]
        actions=NSSegmentedControl(labels:labels,trackingMode:.selectOne,target:self,action:#selector(selectAction(_:)))
        actions.selectedSegment=0;actions.frame=NSRect(x:16,y:w.contentView!.bounds.height-barHeight+12,width:840,height:28)
        actions.autoresizingMask=[.width,.minYMargin];actions.setAccessibilityLabel(desktop.t("图鉴动作","Field guide action"))
        w.contentView!.addSubview(actions)
        let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:w.contentView!.bounds.width,height:w.contentView!.bounds.height-barHeight));scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true;scroll.drawsBackground=true;scroll.backgroundColor = .white
        grid=BirdGalleryView(desktop:desktop);grid.updateLayout()
        let grid=self.grid!
        scroll.documentView=grid;w.contentView!.addSubview(scroll);w.center()
        timer=Timer(timeInterval:1/30,repeats:true){[weak self,weak grid] _ in
            guard self?.window?.isVisible == true else {return};grid?.updateLayout();grid?.needsDisplay=true
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
    var maxScale:CGFloat {desktop.scale * (desktop.catalog.species.map(\.relativeScale).max() ?? 1)}
    var cellWidth:CGFloat {max(220,ceil(48*maxScale)+32)}
    var cellHeight:CGFloat {ceil(48*maxScale)+90}
    var columns:Int {max(1,Int(880/cellWidth))}
    func updateLayout() {
        let size=NSSize(width:max(880,cellWidth),height:CGFloat((desktop.catalog.species.count+columns-1)/columns)*cellHeight)
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
        NSColor.white.setFill();dirtyRect.fill()
        guard let ctx=NSGraphicsContext.current?.cgContext else{return}
        let age=ProcessInfo.processInfo.systemUptime-started
        for (i,p) in desktop.catalog.species.enumerated() {
            let cell=NSRect(x:CGFloat(i%columns)*cellWidth,y:CGFloat(i/columns)*cellHeight,width:cellWidth,height:cellHeight)
            let scale=desktop.scale*p.relativeScale
            let labelY=cell.minY+ceil(48*maxScale)+24
            guard cell.intersects(dirtyRect) else {continue}
            let pose=GalleryPose.frame(p.id,age:age,fps:p.flapFPS,action:action,speedMultiplier:p.speed)
            desktop.arts[p.id]!.draw(name:pose,at:CGPoint(x:cell.midX+5*scale,y:cell.minY+16+39*maxScale),scale:scale,right:true,context:ctx)
            let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
            let style:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.black,.paragraphStyle:paragraph]
            (desktop.language.name(p.id) as NSString).draw(in:NSRect(x:cell.minX+5,y:labelY,width:cell.width-10,height:36),withAttributes:style)
            (actionName(pose) as NSString).draw(in:NSRect(x:cell.minX+5,y:labelY+36,width:cell.width-10,height:18),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.darkGray,.paragraphStyle:paragraph])
        }
    }
}
