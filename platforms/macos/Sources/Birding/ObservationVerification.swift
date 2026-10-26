import AppKit
import BirdingCore

/// Uses isolated files and synthetic birds; never modifies the user's Life List.
enum ObservationVerification {
    final class HeartsPreview:NSView {
        let desktop:DesktopController
        let bird:Bird
        let origin:CGPoint
        let includeLabel:Bool
        init(desktop:DesktopController,bird:Bird,origin:CGPoint = .zero,includeLabel:Bool = false) {
            self.desktop=desktop;self.bird=bird;self.origin=origin;self.includeLabel=includeLabel
            super.init(frame:NSRect(x:0,y:0,width:includeLabel ? 440:320,height:300))
        }
        required init?(coder:NSCoder){fatalError()}
        override func draw(_ dirtyRect:NSRect) {
            NSColor(white:0.93,alpha:1).setFill();bounds.fill()
            let context=NSGraphicsContext.current!.cgContext
            context.saveGState();context.translateBy(x:0,y:bounds.height);context.scaleBy(x:1,y:-1)
            desktop.arts[bird.profile.id]!.draw(name:bird.frameName,at:CGPoint(x:bird.position.x-origin.x,y:bird.position.y-origin.y),scale:desktop.spriteScale(for:bird),right:bird.facingRight,context:context)
            context.restoreGState()
            for panel in [desktop.heartsPanel,includeLabel ? desktop.feedbackPanel:nil,includeLabel ? desktop.clickFlashPanel:nil].compactMap({$0}) {
                guard panel.isVisible,let view=panel.contentView else {continue}
                context.saveGState()
                context.clip(to:bounds)
                context.translateBy(x:panel.frame.minX-origin.x,y:panel.frame.minY+bounds.height-desktop.primaryHeight+origin.y)
                view.draw(view.bounds);context.restoreGState()
            }
        }
    }
    @discardableResult static func snapshot(_ view:NSView,to url:URL) throws -> NSBitmapImageRep {
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(view.bounds.width),pixelsHigh:Int(view.bounds.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
        view.draw(view.bounds);NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using:.png,properties:[:])!.write(to:url);return bitmap
    }
    static func run(to folder:URL) {
        var checks:[String:Bool]=[:]
        do {
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let d=DesktopController()
            d.settingsURL=folder.appendingPathComponent("settings.json")
            d.settings.probabilities.adjust(at:0,to:8000)
            d.settings.catalog.species[0].speed=0.5
            let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
            let original=try encoder.encode(d.settings)
            d.makeMenu()
            let old=Bird(position:CGPoint(x:300,y:300),fraction:0.5,profile:d.catalog.profile(.treeSparrow))
            d.birds=[old]
            d.toggleObservations()
            checks["enableUsesDefaultsPreservesPreferences"]=try d.lifeList.enabled && d.catalog.species == SpeciesCatalog.standard.species && encoder.encode(d.settings) == original
            checks["oldBirdDepartsAndCannotBeRecorded"]=old.isDeparting && !d.observationVisits.contains(ObjectIdentifier(old))
            checks["settingsMenuAvailable"]=d.status.menu!.items.first{$0.action == #selector(d.showSpeciesSettings)}?.isEnabled == true
            let bird=Bird(position:CGPoint(x:300,y:300),fraction:0.5,profile:d.catalog.profile(.treeSparrow))
            d.birds=[bird];d.observationVisits.arrive(ObjectIdentifier(bird))
            func hitPoint(_ bird:Bird)->CGPoint {
                let art=d.arts[bird.profile.id]!, scale=d.spriteScale(for:bird)
                for y in 0..<48 { for x in 0..<48 where art.contains(frame:bird.frameName,x:x,y:y) {
                    return CGPoint(x:bird.position.x+(CGFloat(bird.facingRight ? x : 47-x)+0.5-(bird.facingRight ? 29:19))*scale,y:bird.position.y+(CGFloat(y)+0.5+bird.hopOffset-39)*scale)
                }}
                return .zero
            }
            // Exercise the actual AppKit click handler, including a timer tick
            // after the physical press but before delivery of mouseDown.
            let clickPoint=hitPoint(bird)
            let screenPoint=NSPoint(x:clickPoint.x,y:d.primaryHeight-clickPoint.y)
            let clickTime=ProcessInfo.processInfo.systemUptime
            d.updateHover(now:clickTime,at:clickPoint)
            d.updateCamera(now:clickTime,mouse:screenPoint,pressedButtons:0)
            let camera=d.cameraPanel!, cameraView=camera.contentView as! CameraTargetView
            checks["viewfinderAcceptsInactiveFirstClick"]=cameraView.acceptsFirstMouse(for:nil) && !camera.canBecomeKey && !camera.canBecomeMain
            let position=bird.position
            bird.position.x += 80
            d.updateHover(now:clickTime+0.01,at:clickPoint)
            checks["animationMovedOffClickPixel"]=d.cameraBird == nil
            d.updateCamera(now:clickTime+0.01,mouse:screenPoint,pressedButtons:1)
            checks["pendingMouseDownKeepsDisplayedTarget"]=camera.isVisible && cameraView.bird === bird && camera.frame.contains(screenPoint)
            func click(_ type:NSEvent.EventType, at point:NSPoint) {
                let event=NSEvent.mouseEvent(with:type,location:camera.convertPoint(fromScreen:point),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:camera.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseDown ? 1:0)!
                camera.sendEvent(event)
            }
            click(.leftMouseDown,at:screenPoint)
            checks["firstClickRecordsDisplayedBird"]=d.lifeList.records["treeSparrow"]?.count == 1 && d.feedbackPanel?.isVisible == true && (d.feedbackPanel?.contentView as? ObservationFeedbackView)?.isNew == true
            checks["feedbackAnchorsAboveBirdInsteadOfClick"]=d.feedbackPanel.map{
                abs($0.frame.midX-d.feedbackBounds(for:bird).midX)<1 && $0.frame.minY+32 >= d.primaryHeight-d.feedbackBounds(for:bird).minY+8
            } ?? false
            let flashFrame=d.clickFlashPanel!.frame
            checks["clickFlashAnchorsActualClick"] = abs(flashFrame.midX-screenPoint.x)<1 && abs(flashFrame.midY-screenPoint.y)<1
            bird.position.x += 20;d.positionFeedback()
            checks["clickFlashDoesNotFollowMovingLabel"] = d.clickFlashPanel!.frame == flashFrame
            bird.position.x -= 20;d.positionFeedback()
            let heldFrame=camera.frame
            d.updateCamera(now:clickTime+0.02,mouse:NSPoint(x:screenPoint.x+100,y:screenPoint.y),pressedButtons:1)
            checks["heldClickKeepsPanelUntilMouseUp"]=camera.isVisible && camera.frame == heldFrame
            click(.leftMouseUp,at:screenPoint)
            checks["mouseUpReleasesCamera"] = !d.cameraPressed
            bird.position=position
            if let view=d.feedbackPanel?.contentView as? ObservationFeedbackView { try snapshot(view,to:folder.appendingPathComponent("feedback-new.png")) }
            let originalView=d.feedbackPanel?.contentView, started=d.feedbackStarted
            d.photograph(at:hitPoint(bird),now:started+0.1)
            checks["repeatKeepsOriginalFeedback"] = d.feedbackPanel?.contentView === originalView && d.feedbackStarted == started
            checks["twoClicksHaveNoHearts"] = d.heartsPanel?.isVisible != true
            d.photograph(at:hitPoint(bird),now:started+0.2)
            checks["thirdClickShowsHeartsWithoutReplacingText"] = d.heartsPanel?.isVisible == true && d.feedbackPanel?.contentView === originalView
            d.updateHearts(now:started+0.5)
            if let view=d.heartsPanel?.contentView { try snapshot(view,to:folder.appendingPathComponent("hearts.png")) }
            d.updateHearts(now:started+1.5)
            checks["heartsExpire"] = d.heartsPanel?.isVisible == false
            let savedScale=d.scale
            var aboveEveryBird=true,headAnchored=true
            for globalScale:CGFloat in [1,2] {
                d.scale=globalScale
                for profile in d.catalog.species {
                    let sample=Bird(position:CGPoint(x:500,y:400),fraction:0.5,profile:profile)
                    d.birds=[sample]
                    for right in [true,false] {
                        sample.facingRight=right
                        d.showHearts(for:sample,now:started)
                        let art=d.arts[profile.id]!,scale=d.spriteScale(for:sample)
                        let top=sample.position.y+(CGFloat(art.topPixel(frame:sample.frameName))+sample.hopOffset-39)*scale
                        aboveEveryBird = aboveEveryBird && d.heartsPanel!.frame.minY >= d.primaryHeight-top+10
                        let crownX=sample.position.x+((right ? art.headPixelX:48-art.headPixelX)-(right ? 29:19))*scale
                        headAnchored = headAnchored && abs(d.heartsPanel!.frame.midX-crownX)<1
                    }
                }
            }
            checks["heartsAboveAllSpeciesAtBothSizes"] = aboveEveryBird
            checks["heartsFollowHeadWhenMirrored"] = headAnchored
            let edgeBird=Bird(position:CGPoint(x:500,y:0),fraction:0.5,profile:d.catalog.profile(.nightHeron))
            edgeBird.state = .perched
            let edgeScale=d.spriteScale(for:edgeBird), edgeArt=d.arts[edgeBird.profile.id]!
            let screen=NSScreen.main!.visibleFrame
            edgeBird.position.y=d.primaryHeight-screen.maxY+12-(CGFloat(edgeArt.topPixel(frame:edgeBird.frameName))-39)*edgeScale
            d.birds=[edgeBird];d.showHearts(for:edgeBird,now:started)
            let expectedHeartBottom=ceil(screen.maxY-12+ObservationHearts.clearance(scale:edgeScale))
            checks["screenTopDoesNotPushHeartsOntoBird"] = abs(d.heartsPanel!.frame.minY-expectedHeartBottom)<1
            let savedFeedbackBird=d.feedbackBird
            d.feedbackBird=edgeBird;d.positionFeedback()
            let labelPanel=d.feedbackPanel!, labelView=labelPanel.contentView as! ObservationFeedbackView
            let labelWidth=min(labelPanel.frame.width-8,ObservationFeedbackView.textWidth(labelView.text))
            func currentLabelRect() -> CGRect {
                CGRect(x:labelPanel.frame.midX-labelWidth/2,y:d.primaryHeight-(labelPanel.frame.minY+57),width:labelWidth,height:25)
            }
            checks["screenTopLabelStaysAboveBird"] = currentLabelRect().maxY <= d.feedbackBounds(for:edgeBird).minY-8 && abs(currentLabelRect().midX-d.feedbackBounds(for:edgeBird).midX)<1
            let beforeMove=currentLabelRect()
            edgeBird.position.x += 80;d.positionFeedback()
            checks["feedbackFollowsBirdWithoutRestartingAnimation"] = abs(currentLabelRect().minX-beforeMove.minX-80)<1 && d.feedbackStarted == started
            let savedText=labelView.text,savedNew=labelView.isNew,savedAge=labelView.age
            labelView.text=d.language.name(edgeBird.profile.id);labelView.isNew=false;labelView.age=0.34
            d.positionFeedback();d.updateHearts(now:started+0.34)
            let clickLocation=NSPoint(x:edgeBird.position.x,y:d.primaryHeight-edgeBird.position.y+15)
            d.showClickFlash(at:clickLocation,now:started);d.updateClickFlash(now:started+0.08)
            checks["screenTopFlashStaysAtClick"] = abs(d.clickFlashPanel!.frame.midX-clickLocation.x)<1 && abs(d.clickFlashPanel!.frame.midY-clickLocation.y)<1
            try snapshot(HeartsPreview(desktop:d,bird:edgeBird,origin:CGPoint(x:edgeBird.position.x-150,y:d.primaryHeight-screen.maxY),includeLabel:true),to:folder.appendingPathComponent("screen-top-feedback.png"))
            edgeBird.position.y += 70;d.positionFeedback();d.updateHearts(now:started+0.34)
            d.showClickFlash(at:NSPoint(x:clickLocation.x,y:clickLocation.y-70),now:started);d.updateClickFlash(now:started+0.08)
            try snapshot(HeartsPreview(desktop:d,bird:edgeBird,origin:CGPoint(x:edgeBird.position.x-150,y:d.primaryHeight-screen.maxY),includeLabel:true),to:folder.appendingPathComponent("near-top-feedback.png"))
            d.updateClickFlash(now:started+0.3)
            checks["clickFlashExpiresIndependently"] = d.clickFlashPanel?.isVisible == false
            labelView.text=savedText;labelView.isNew=savedNew;labelView.age=savedAge
            d.feedbackBird=savedFeedbackBird
            let largeBird=Bird(position:CGPoint(x:160,y:240),fraction:0.5,profile:d.catalog.profile(.nightHeron))
            largeBird.state = .perched
            d.birds=[largeBird];d.showHearts(for:largeBird,now:started)
            for (name,age) in [("pop",0.13),("hold",0.34),("float",0.8)] {
                d.updateHearts(now:started+age)
                try snapshot(HeartsPreview(desktop:d,bird:largeBird),to:folder.appendingPathComponent("large-bird-hearts-\(name).png"))
            }
            d.scale=savedScale;d.birds=[bird];d.updateHearts(now:started+2)
            for (name,age) in [("pop",0.13),("hold",0.34),("float",0.8)] {
                let preview=ObservationHeartsView(frame:NSRect(x:0,y:0,width:120,height:100));preview.age=age
                try snapshot(preview,to:folder.appendingPathComponent("hearts-\(name).png"))
            }
            d.photograph(at:hitPoint(bird),now:started+1.3)
            checks["repeatAfterExpiryShowsOnlyBirdName"]=(d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(bird.profile.id)
            let edge=hitPoint(bird), scale=d.spriteScale(for:bird)
            let near=CGPoint(x:edge.x,y:edge.y-scale/2-4.9)
            d.updateHover(now:started,at:near)
            checks["fivePixelPaddingHitsBird"] = d.cameraBird === bird
            d.updateHover(now:started,at:CGPoint(x:near.x,y:near.y-0.2))
            checks["paddingDoesNotExceedFivePixels"] = d.cameraBird == nil
            bird.facingRight.toggle()
            let mirroredEdge=hitPoint(bird)
            d.updateHover(now:started,at:CGPoint(x:mirroredEdge.x,y:mirroredEdge.y-scale/2-4.9))
            checks["paddingWorksWhenMirrored"] = d.cameraBird === bird
            bird.facingRight.toggle()
            if let view=d.feedbackPanel?.contentView as? ObservationFeedbackView { try snapshot(view,to:folder.appendingPathComponent("feedback-repeat.png")) }
            checks["feedbackFitsText"]=ObservationFeedbackView.textWidth("麻雀") < 60 && ObservationFeedbackView.textWidth("麻雀 加新！") > ObservationFeedbackView.textWidth("麻雀")
            let target=CameraTargetView(frame:NSRect(x:0,y:0,width:28,height:28))
            let targetImage=try snapshot(target,to:folder.appendingPathComponent("viewfinder.png"))
            checks["viewfinderHasOwnVisiblePixels"]=(0..<28).contains { x in (0..<28).contains { y in (targetImage.colorAt(x:x,y:y)?.alphaComponent ?? 0) > 0.5 } }
            checks["wholeViewfinderReceivesClicks"]=(0..<28).allSatisfy { x in (0..<28).allSatisfy { y in (targetImage.colorAt(x:x,y:y)?.alphaComponent ?? 0) > 0 } }
            checks["sameVisitRecordedOnlyOnce"]=d.lifeList.records["treeSparrow"]?.count == 1
            d.cameraBird=nil
            d.updateCamera(now:clickTime+1,mouse:screenPoint,pressedButtons:0)
            checks["leavingBirdClearsClickTarget"] = !camera.isVisible && cameraView.bird == nil
            d.cameraBird=bird
            d.updateCamera(now:clickTime+1.01,mouse:screenPoint,pressedButtons:1)
            checks["externalDragDoesNotShowViewfinder"] = !camera.isVisible && cameraView.bird == nil
            d.updateCamera(now:clickTime+1.02,mouse:screenPoint,pressedButtons:0)
            d.birds=[];d.feedbackPanel?.orderOut(nil)
            click(.leftMouseDown,at:screenPoint);click(.leftMouseUp,at:screenPoint)
            checks["removedBirdCannotBeRecorded"]=d.feedbackPanel?.isVisible == false && d.lifeList.records["treeSparrow"]?.count == 1
            d.birds=[bird];d.hideCamera()
            let first=d.lifeList.records["treeSparrow"]!.firstRecordedAt
            let another=Bird(position:CGPoint(x:300,y:300),fraction:0.5,profile:d.catalog.profile(.treeSparrow))
            d.birds=[another];d.observationVisits.arrive(ObjectIdentifier(another))
            d.updateHover(now:ProcessInfo.processInfo.systemUptime,at:hitPoint(another))
            d.updateCamera(now:ProcessInfo.processInfo.systemUptime,mouse:screenPoint,pressedButtons:0)
            d.updateCamera(now:ProcessInfo.processInfo.systemUptime,mouse:screenPoint,pressedButtons:1)
            click(.leftMouseDown,at:screenPoint);click(.leftMouseUp,at:screenPoint)
            checks["stationaryBirdFirstClickShowsIncrement"]=(d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(another.profile.id)+" +1" && d.lifeList.records["treeSparrow"]?.count == 2
            for _ in 0..<5 { click(.leftMouseDown,at:screenPoint);click(.leftMouseUp,at:screenPoint) }
            checks["repeatedMouseEventsDoNotDoubleCount"]=d.lifeList.records["treeSparrow"]?.count == 2 && (d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(another.profile.id)+" +1"
            checks["newVisitIncrementsPreservingFirstDate"]=d.lifeList.records["treeSparrow"]?.count == 2 && d.lifeList.records["treeSparrow"]?.firstRecordedAt == first
            // Hovering in observation mode targets the camera without starting
            // the delayed name label, even after the one-second dwell period.
            d.updateHover(now:100,at:hitPoint(another))
            d.updateHover(now:102,at:hitPoint(another))
            checks["observationHoverHasNoName"]=d.cameraBird === another && d.hoveredBird == nil
            var masksMatch=true
            for art in d.arts.values {
                for (name,image) in art.frames {
                    let data=image.dataProvider!.data!, bytes=CFDataGetBytePtr(data)!
                    var first:Int?=nil
                    for y in 0..<48 {for x in 0..<48 {
                        let opaque=bytes[(y*image.height/48)*image.bytesPerRow+(x*image.width/48)*4+3]>0
                        if opaque && first == nil {first=y}
                        if art.contains(frame:name,x:x,y:y) != opaque {masksMatch=false}
                    }}
                    if art.topPixel(frame:name) != (first ?? 0) {masksMatch=false}
                }
            }
            checks["cachedHitMasksMatchEveryRenderedFrame"]=masksMatch
            let flyingBird=Bird(position:CGPoint(x:100,y:200),fraction:0.5,profile:d.catalog.profile(.barnSwallow))
            flyingBird.fly(to:CGPoint(x:1300,y:400),host:nil,duration:8,random:{0.5})
            d.birds=[flyingBird];d.observationVisits.arrive(ObjectIdentifier(flyingBird))
            var followed=true,advanced=true
            let hoverStart=ProcessInfo.processInfo.systemUptime
            for step in 0..<120 {
                let previous=flyingBird.position
                flyingBird.tick(1.0/60)
                d.updateHover(now:Double(step)/60,at:hitPoint(flyingBird))
                followed = followed && d.cameraBird === flyingBird && d.hoveredBird == nil
                advanced = advanced && Geometry.distance(previous,flyingBird.position)>0
            }
            let hoverElapsed=ProcessInfo.processInfo.systemUptime-hoverStart
            checks["followingFlyingBirdKeepsMoving"]=followed && advanced
            checks["hoverWorkFitsAnimationBudget"]=hoverElapsed<0.5
            print(String(format:"120 following-hover samples: %.1f ms",hoverElapsed*1000))
            d.birds=[another]
            let grid=BirdGalleryView(desktop:d);grid.updateLayout()
            checks["recordedSpeciesSortFirst"]=grid.profiles.first?.id == .treeSparrow
            checks["lifeListKeepsUndiscoveredSilhouettes"]=grid.profiles.count == SpeciesID.allCases.count
            checks["modeMenuNames"]=d.status.menu!.items.contains{$0.title == "观鸟模式"} && d.status.menu!.items.contains{$0.title == "观鸟记录…"}
            let gallery=SpeciesGallery(desktop:d);gallery.showWindow(nil)
            let content=gallery.window!.contentView!
            content.layoutSubtreeIfNeeded();content.displayIfNeeded()
            checks["singleModeView"]=content.subviews.compactMap{$0 as? NSSegmentedControl}.allSatisfy{$0.isHidden} && gallery.window!.title.hasPrefix("Life List")
            let sortBar=content.subviews.first{$0.identifier?.rawValue == "lifeListSortBar"}!
            let sortTabs=sortBar.subviews.first{$0.identifier?.rawValue == "lifeListSortTabs"} as! NSSegmentedControl
            let galleryScroll=content.subviews.compactMap{$0 as? NSScrollView}.first!
            let galleryGrid=galleryScroll.documentView as! BirdGalleryView
            checks["sortBarVisibleAboveRecords"] = !sortBar.isHidden && galleryScroll.frame.maxY == sortBar.frame.minY
            checks["defaultSortIsNewestFirst"] = sortTabs.selectedSegment == 0 && sortTabs.label(forSegment:0) == "加新时间 ↓" && sortTabs.label(forSegment:1) == "记录数量"
            let originalList=d.lifeList
            d.lifeList=LifeList();d.lifeList.enabled=true
            for _ in 0..<3 {d.lifeList.record(.treeSparrow,at:Date(timeIntervalSince1970:10))}
            d.lifeList.record(.nightHeron,at:Date(timeIntervalSince1970:30))
            for _ in 0..<2 {d.lifeList.record(.barnSwallow,at:Date(timeIntervalSince1970:20))}
            func clickSortTab(_ index:Int) {
                sortTabs.selectedSegment=index
                sortTabs.performClick(nil)
            }
            let sortCases:[(Int,Int,[SpeciesID])]=[
                (0,0,[.treeSparrow,.barnSwallow,.nightHeron]),
                (0,1,[.nightHeron,.barnSwallow,.treeSparrow]),
                (1,1,[.treeSparrow,.barnSwallow,.nightHeron]),
                (1,0,[.nightHeron,.barnSwallow,.treeSparrow])]
            for (field,order,expected) in sortCases {
                galleryGrid.scroll(CGPoint(x:0,y:100))
                clickSortTab(field)
                let profiles=galleryGrid.profiles
                checks["sortControlsApply_\(field)_\(order)"] = Array(profiles.prefix(3).map(\.id)) == expected
                    && profiles.dropFirst(3).allSatisfy{d.lifeList.records[$0.id.rawValue] == nil}
                    && galleryScroll.contentView.bounds.minY == 0
                    && sortTabs.label(forSegment:field)?.hasSuffix(order == 0 ? " ↑":" ↓") == true
                    && !(sortTabs.label(forSegment:1-field) ?? "").contains("↑")
                    && !(sortTabs.label(forSegment:1-field) ?? "").contains("↓")
            }
            checks["countSortHasClearDirectionLabels"] = sortTabs.label(forSegment:0) == "加新时间" && sortTabs.label(forSegment:1) == "记录数量 ↑"
            d.language = .english;gallery.refreshMode()
            checks["sortControlsTranslateToEnglish"] = sortTabs.label(forSegment:0) == "First recorded" && sortTabs.label(forSegment:1) == "Observation count ↑"
            content.displayIfNeeded()
            if let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds) {
                content.cacheDisplay(in:content.bounds,to:bitmap)
                try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("life-list-sorting.png"))
            }
            d.language = .chinese;d.lifeList=originalList
            sortTabs.selectedSegment=0
            NSApp.sendAction(sortTabs.action!,to:sortTabs.target,from:sortTabs)
            checks["switchTabMovesArrowAndDefaultsToDescending"] = sortTabs.label(forSegment:0) == "加新时间 ↓" && sortTabs.label(forSegment:1) == "记录数量"
            let settings=SpeciesSettingsWindow(desktop:d);settings.showWindow(nil)
            let overlay=d.observationPanel(size:NSSize(width:30,height:30),interactive:false)
            overlay.orderFrontRegardless()
            RunLoop.current.run(until:Date(timeIntervalSinceNow:0.3))
            d.sampleWindows(dt:0)
            checks["ownGalleryOccludes"]=d.surfaces.contains{$0.id == UInt32(gallery.window!.windowNumber)}
            checks["ownSettingsOccludes"]=d.surfaces.contains{$0.id == UInt32(settings.window!.windowNumber)}
            checks["ownOverlayDoesNotOcclude"] = !d.surfaces.contains{$0.id == UInt32(overlay.windowNumber)}
            settings.close();overlay.orderOut(nil)
            if let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds) {
                content.cacheDisplay(in:content.bounds,to:bitmap)
                try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("life-list-gallery.png"))
            }
            d.language = .english
            let lifer=Bird(position:CGPoint(x:300,y:300),fraction:0.5,profile:d.catalog.profile(.nightHeron))
            d.birds=[lifer];d.observationVisits.arrive(ObjectIdentifier(lifer))
            d.photograph(at:hitPoint(lifer))
            checks["englishLiferHasSeparator"] = (d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(lifer.profile.id)+" · Lifer!"
            if let view=d.feedbackPanel?.contentView { try snapshot(view,to:folder.appendingPathComponent("feedback-lifer.png")) }
            d.language = .chinese
            d.birds=[another]
            d.toggleObservations()
            checks["disableRestoresPreferencesKeepsRecords"] = try !d.lifeList.enabled && encoder.encode(d.settings) == original && d.lifeList.records["treeSparrow"]?.count == 2
            gallery.refreshMode()
            checks["guideHidesSortBar"] = sortBar.isHidden
            checks["guideRestoresActions"]=content.subviews.compactMap{$0 as? NSSegmentedControl}.allSatisfy{!$0.isHidden}
            checks["offMenuReturnsToGuide"]=d.status.menu!.items.contains{$0.title == "图鉴…"}
            let loaded=try LifeList.load(from:d.lifeListURL)
            checks["recordsPersistAcrossRestart"] = !loaded.enabled && loaded.records["treeSparrow"]?.count == 2
            d.toggleObservations()
            checks["reEnableInvalidatesExistingVisit"] = !d.observationVisits.contains(ObjectIdentifier(another))
            gallery.close();d.clickFlashPanel?.orderOut(nil);d.cameraPanel?.orderOut(nil);d.feedbackPanel?.orderOut(nil);d.heartsPanel?.orderOut(nil)
            try JSONSerialization.data(withJSONObject:checks,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("results.json"))
            print(checks.sorted{$0.key<$1.key}.map{"\($0.value ? "PASS" : "FAIL") \($0.key)"}.joined(separator:"\n"))
            exit(checks.values.allSatisfy{$0} ? 0:1)
        } catch { print("Observation verification failed: \(error)");exit(1) }
    }
}
