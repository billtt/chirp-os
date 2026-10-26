import AppKit
import BirdingCore

extension DesktopController {
    func loadLifeList() {
        do {
            var loaded = try LifeList.load(from: lifeListURL)
            let introduce = loaded.prepareIntroduction()
            if introduce { try loaded.save(to: lifeListURL) }
            lifeList = loaded
            if introduce { DispatchQueue.main.async { self.showObservationIntroduction() } }
        }
        catch {
            // Never overwrite a damaged or newer file with an empty list.
            lifeListAvailable = false
            DispatchQueue.main.async { self.observationError(error) }
        }
    }
    func showObservationIntroduction() {
        let alert=NSAlert()
        alert.messageText=t("欢迎进入观鸟模式", "Welcome to birdwatching mode")
        alert.informativeText=t("将鼠标移到小鸟身上，点击取景框即可记录。首次发现的鸟种会加入 Life List（鸟种记录）。\n\n观鸟模式下鸟种设置不生效。你可以随时在菜单中关闭“观鸟模式”，恢复自己的设置，已有记录会保留。", "Hover over a bird and click the viewfinder to record it. Newly discovered species join your Life List.\n\nCustom bird settings do not apply in birdwatching mode. Turn it off anytime in the menu to restore your settings. Your observations will be kept.")
        alert.addButton(withTitle:t("开始观鸟", "Start birdwatching"));alert.runModal()
    }
    func observationError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = t("无法读取或保存观鸟记录", "Could not read or save observations")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
    @objc func toggleObservations() {
        guard lifeListAvailable else { return }
        var next = lifeList; next.enabled.toggle()
        do { try next.save(to: lifeListURL) } catch { observationError(error); return }
        lifeList = next; observationVisits.reset(); observationInteraction.reset()
        heartsPanel?.orderOut(nil); heartsBird=nil;feedbackBird=nil
        cameraPanel?.orderOut(nil); feedbackPanel?.orderOut(nil);clickFlashPanel?.orderOut(nil)
        if next.enabled {
            for bird in birds { sendAway(bird) }
        }
        makeMenu();settingsWindow?.refreshMode()
    }
    func hideCamera() {
        (cameraPanel?.contentView as? CameraTargetView)?.bird=nil
        if cameraPanel?.isVisible == true { cameraPanel?.orderOut(nil); NSCursor.arrow.set() }
    }
    func updateCamera(now: Double, mouse:NSPoint = NSEvent.mouseLocation, pressedButtons:Int = NSEvent.pressedMouseButtons) {
        updateClickFlash(now:now)
        updateHearts(now:now)
        if let feedback = feedbackPanel, feedback.isVisible {
            let age = now-feedbackStarted
            if age >= 1.2 { feedback.orderOut(nil) }
            else if let view = feedback.contentView as? ObservationFeedbackView {
                view.age=age;positionFeedback();view.needsDisplay=true
            }
        }
        guard lifeList.enabled, NSApp.modalWindow == nil,
              !observationMenuOpen,
              !NSApp.windows.contains(where: { !($0 is OverlayPanel) && $0.isVisible && $0.frame.contains(mouse) }) else {
            hideCamera(); return
        }
        if pressedButtons != 0 {
            // The button state can change before AppKit delivers mouseDown.
            // Keep the displayed target and its bird until that click is handled.
            // Never show a new target during a drag from another application.
            if cameraPressed || (pressedButtons & 1 != 0 && cameraPanel?.isVisible == true && cameraPanel!.frame.contains(mouse)) { return }
            hideCamera(); return
        }
        cameraPressed=false
        guard let bird=cameraBird, observationVisits.contains(ObjectIdentifier(bird)) else {
            hideCamera(); return
        }
        if cameraPanel == nil {
            let panel = observationPanel(size:NSSize(width:28,height:28), interactive:true)
            let view = CameraTargetView(frame:NSRect(x:0,y:0,width:28,height:28))
            view.desktop=self; panel.contentView=view; cameraPanel=panel
        }
        (cameraPanel?.contentView as? CameraTargetView)?.bird=bird
        cameraPanel?.setFrameOrigin(NSPoint(x:mouse.x-14,y:mouse.y-14))
        if cameraPanel?.isVisible != true { cameraPanel?.orderFrontRegardless() }
        CameraTargetView.cameraCursor.set()
    }
    func showClickFlash(at point:NSPoint,now:Double) {
        if clickFlashPanel == nil {
            clickFlashPanel=observationPanel(size:NSSize(width:32,height:32),interactive:false)
            clickFlashPanel?.contentView=ObservationClickFlashView(frame:NSRect(x:0,y:0,width:32,height:32))
        }
        clickFlashStarted=now
        clickFlashPanel?.setFrameOrigin(NSPoint(x:point.x-16,y:point.y-16))
        updateClickFlash(now:now);clickFlashPanel?.orderFrontRegardless()
    }
    func updateClickFlash(now:Double) {
        let age=now-clickFlashStarted
        guard lifeList.enabled,age<0.2 else {clickFlashPanel?.orderOut(nil);return}
        let view=clickFlashPanel?.contentView as? ObservationClickFlashView
        view?.age=age;view?.needsDisplay=true
    }
    func showHearts(for bird:Bird, now:Double) {
        if heartsPanel == nil {
            heartsPanel=observationPanel(size:NSSize(width:120,height:100),interactive:false)
            heartsPanel?.contentView=ObservationHeartsView(frame:NSRect(x:0,y:0,width:120,height:100))
        }
        heartsBird=bird; heartsStarted=now
        updateHearts(now:now)
    }
    func updateHearts(now:Double) {
        guard lifeList.enabled, let bird=heartsBird, birds.contains(where:{$0 === bird}),
              now-heartsStarted < ObservationHearts.duration else { heartsPanel?.orderOut(nil); heartsBird=nil; return }
        let scale=spriteScale(for:bird)
        let art=arts[bird.profile.id]!
        let top=bird.position.y+(CGFloat(min(art.topPixel(frame:bird.frameName),art.topPixel(frame:"stand")))+bird.hopOffset-39)*scale
        let headX=bird.position.x+((bird.facingRight ? art.headPixelX:48-art.headPixelX)-(bird.facingRight ? 29:19))*scale
        guard !bird.blockers(in:surfaces).contains(where:{$0.contains(CGPoint(x:headX,y:top+1))}) else {
            heartsPanel?.orderOut(nil); return
        }
        let view=heartsPanel?.contentView as? ObservationHeartsView
        view?.age=now-heartsStarted; view?.needsDisplay=true
        heartsPanel?.setFrameOrigin(NSPoint(x:headX-60,y:ceil(primaryHeight-top+ObservationHearts.clearance(scale:scale))))
        heartsPanel?.orderFrontRegardless()
    }
    func observationPanel(size:NSSize, interactive:Bool) -> OverlayPanel {
        let panel=OverlayPanel(contentRect:NSRect(origin:.zero,size:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.allowsOffscreenPlacement = !interactive
        panel.animationBehavior = .none; panel.isMovable=false; panel.isMovableByWindowBackground=false
        panel.isOpaque=false; panel.backgroundColor = .clear; panel.hasShadow=false
        panel.ignoresMouseEvents = !interactive; panel.hidesOnDeactivate=false
        panel.level = .floating; panel.isReleasedWhenClosed=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
        return panel
    }
    func positionFeedback() {
        guard let panel=feedbackPanel, let view=panel.contentView as? ObservationFeedbackView,
              let bird=feedbackBird,birds.contains(where:{$0 === bird}) else {feedbackPanel?.orderOut(nil);return}
        let screen=feedbackScreen(for:bird)
        let width=min(panel.frame.width-8,ObservationFeedbackView.textWidth(view.text))
        let placement=BirdFeedbackLayout.label(bird:feedbackBounds(for:bird),screen:screen,size:CGSize(width:width,height:25))
        // The text's baseline rectangle is 32 points above the panel's bottom.
        panel.setFrameOrigin(NSPoint(x:placement.midX-panel.frame.width/2,y:ceil(primaryHeight-placement.maxY-32)))
    }
    func photograph(at point:CGPoint? = nil, target:Bird? = nil, now:Double = ProcessInfo.processInfo.systemUptime) {
        // A visible viewfinder owns its target for this click. Repeating the
        // pixel hit test here can lose it after a hop, blink or queued mouse move.
        if target == nil { updateHover(now:ProcessInfo.processInfo.systemUptime,at:point) }
        guard lifeList.enabled, let bird=target ?? cameraBird,
              birds.contains(where:{$0 === bird}) else { return }
        if let point, bird.blockers(in:surfaces).contains(where:{$0.contains(point)}) { return }
        let visit=ObjectIdentifier(bird)
        guard observationVisits.contains(visit) else { return }
        var isNew=false
        let text:String
        if observationVisits.wasRecorded(visit) { text=language.name(bird.profile.id) }
        else {
            var next=lifeList; isNew=next.record(bird.profile.id)
            do { try next.save(to:lifeListURL) }
            catch { cameraPanel?.orderOut(nil); observationError(error); return }
            lifeList=next; observationVisits.commit(visit)
            text=language.name(bird.profile.id)+(isNew ? t(" · 加新！", " · Lifer!") : " +1")
        }
        let clickPoint=point.map{NSPoint(x:$0.x,y:primaryHeight-$0.y)} ?? NSEvent.mouseLocation
        showClickFlash(at:clickPoint,now:now)
        let reaction=observationInteraction.click(visit,now:now)
        if reaction.hearts { showHearts(for:bird,now:now) }
        guard reaction.label else { return }
        let width=min(feedbackScreen(for:bird).width,max(140,ObservationFeedbackView.textWidth(text)+8))
        if feedbackPanel == nil { feedbackPanel=observationPanel(size:NSSize(width:width,height:110),interactive:false) }
        feedbackPanel?.setContentSize(NSSize(width:width,height:110))
        let view=ObservationFeedbackView(frame:NSRect(x:0,y:0,width:width,height:110))
        view.text=text; view.isNew=isNew; feedbackPanel?.contentView=view
        feedbackBird=bird;positionFeedback()
        feedbackStarted=now; feedbackPanel?.orderFrontRegardless()
    }
}

final class CameraTargetView:NSView {
    weak var desktop:DesktopController?
    weak var bird:Bird?
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    // Draw independently of the system cursor: another foreground application
    // may replace NSCursor while this nonactivating panel still receives clicks.
    override func draw(_ dirtyRect:NSRect) {
        // Fully transparent window pixels can pass clicks through. Give the
        // entire viewfinder a hit surface, including the gaps between its marks.
        NSColor.black.withAlphaComponent(0.01).setFill();bounds.fill()
        Self.cameraCursor.image.draw(in:bounds)
    }
    override func resetCursorRects() { addCursorRect(bounds,cursor:Self.cameraCursor) }
    static let cameraCursor:NSCursor = {
        let image=NSImage(size:NSSize(width:28,height:28))
        image.lockFocus()
        let path=NSBezierPath()
        for (x,y,dx,dy) in [(3.0,3.0,1.0,1.0),(25,3,-1,1),(3,25,1,-1),(25,25,-1,-1)] {
            path.move(to:NSPoint(x:x+dx*6,y:y));path.line(to:NSPoint(x:x,y:y));path.line(to:NSPoint(x:x,y:y+dy*6))
        }
        NSColor.black.setStroke();path.lineWidth=3;path.stroke()
        NSColor.white.setStroke();path.lineWidth=1.5;path.stroke()
        NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:13,y:13,width:2,height:2)).fill()
        image.unlockFocus();return NSCursor(image:image,hotSpot:NSPoint(x:14,y:14))
    }()
    override func mouseDown(with event:NSEvent) {
        guard let desktop, let bird, let window, window.isVisible,
              bounds.contains(convert(event.locationInWindow,from:nil)) else { return }
        desktop.cameraPressed=true
        let point=window.convertPoint(toScreen:event.locationInWindow)
        desktop.photograph(at:CGPoint(x:point.x,y:desktop.primaryHeight-point.y),target:bird)
    }
    override func mouseUp(with event:NSEvent) { desktop?.cameraPressed=false }
}

final class ObservationFeedbackView:NSView {
    static let textFont=NSFont.systemFont(ofSize:13,weight:.medium)
    static func textWidth(_ text:String) -> CGFloat { ceil((text as NSString).size(withAttributes:[.font:textFont]).width)+20 }
    var text="", isNew=false, age=0.0
    override func draw(_ dirtyRect:NSRect) {
        let alpha=max(0,min(1,(1.2-age)*3))
        let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
        let width=min(bounds.width-8,Self.textWidth(text))
        let rect=NSRect(x:(bounds.width-width)/2,y:32+age*16,width:width,height:25)
        NSColor.black.withAlphaComponent(0.8*alpha).setFill();NSBezierPath(roundedRect:rect,xRadius:6,yRadius:6).fill()
        (text as NSString).draw(in:rect.insetBy(dx:4,dy:3),withAttributes:[.font:Self.textFont,.foregroundColor:NSColor.white.withAlphaComponent(alpha),.paragraphStyle:paragraph])
        if isNew {
            let colors:[NSColor]=[.systemPink,.systemYellow,.systemTeal,.systemBlue,.systemOrange]
            for i in 0..<16 {
                let angle=Double(i)*2.4, radius=12+age*42
                colors[i%colors.count].withAlphaComponent(alpha).setFill()
                NSBezierPath(rect:NSRect(x:bounds.midX+cos(angle)*radius,y:35+sin(angle)*radius+age*12,width:4,height:3)).fill()
            }
        }
    }
}

final class ObservationHeartsView:NSView {
    var age=0.0
    override func draw(_ dirtyRect:NSRect) {
        for i in 0..<ObservationHearts.count {
            let particle=ObservationHearts.particle(i,age:age)
            let size=CGFloat(particle.size)
            let x=60+particle.x, y=particle.y
            let heart=NSBezierPath()
            heart.move(to:NSPoint(x:0,y:0))
            heart.curve(to:NSPoint(x:-0.5,y:0.65),controlPoint1:NSPoint(x:-0.2,y:0.22),controlPoint2:NSPoint(x:-0.62,y:0.4))
            heart.curve(to:NSPoint(x:0,y:0.72),controlPoint1:NSPoint(x:-0.42,y:1),controlPoint2:NSPoint(x:-0.12,y:1))
            heart.curve(to:NSPoint(x:0.5,y:0.65),controlPoint1:NSPoint(x:0.12,y:1),controlPoint2:NSPoint(x:0.42,y:1))
            heart.curve(to:.zero,controlPoint1:NSPoint(x:0.62,y:0.4),controlPoint2:NSPoint(x:0.2,y:0.22))
            heart.close()
            var transform=AffineTransform();transform.translate(x:x,y:y);transform.scale(size);heart.transform(using:transform)
            NSColor.systemPink.withAlphaComponent(particle.opacity).setFill();heart.fill()
        }
    }
}

final class ObservationClickFlashView:NSView {
    var age=0.0
    override func draw(_ dirtyRect:NSRect) {
        NSColor.white.withAlphaComponent(max(0,1-age/0.2)).setStroke()
        let flash=NSBezierPath(rect:bounds.insetBy(dx:2,dy:2));flash.lineWidth=2;flash.stroke()
    }
}
