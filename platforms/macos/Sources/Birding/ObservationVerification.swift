import AppKit
import BirdingCore

/// Uses isolated files and synthetic birds; never modifies the user's Life List.
enum ObservationVerification {
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
            checks["feedbackUsesClickLocation"]=d.feedbackPanel.map{abs($0.frame.midX-screenPoint.x)<1} ?? false
            let heldFrame=camera.frame
            d.updateCamera(now:clickTime+0.02,mouse:NSPoint(x:screenPoint.x+100,y:screenPoint.y),pressedButtons:1)
            checks["heldClickKeepsPanelUntilMouseUp"]=camera.isVisible && camera.frame == heldFrame
            click(.leftMouseUp,at:screenPoint)
            checks["mouseUpReleasesCamera"] = !d.cameraPressed
            bird.position=position
            if let view=d.feedbackPanel?.contentView as? ObservationFeedbackView { try snapshot(view,to:folder.appendingPathComponent("feedback-new.png")) }
            d.photograph(at:hitPoint(bird))
            checks["repeatShowsOnlyBirdName"]=(d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(bird.profile.id)
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
            checks["repeatedMouseEventsDoNotDoubleCount"]=d.lifeList.records["treeSparrow"]?.count == 2 && (d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(another.profile.id)
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
            checks["noEmptyActionBar"]=content.subviews.compactMap{$0 as? NSScrollView}.first?.frame.height == content.bounds.height
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
            d.toggleObservations()
            checks["disableRestoresPreferencesKeepsRecords"] = try !d.lifeList.enabled && encoder.encode(d.settings) == original && d.lifeList.records["treeSparrow"]?.count == 2
            gallery.refreshMode()
            checks["guideRestoresActions"]=content.subviews.compactMap{$0 as? NSSegmentedControl}.allSatisfy{!$0.isHidden}
            checks["offMenuReturnsToGuide"]=d.status.menu!.items.contains{$0.title == "图鉴…"}
            let loaded=try LifeList.load(from:d.lifeListURL)
            checks["recordsPersistAcrossRestart"] = !loaded.enabled && loaded.records["treeSparrow"]?.count == 2
            d.toggleObservations()
            checks["reEnableInvalidatesExistingVisit"] = !d.observationVisits.contains(ObjectIdentifier(another))
            gallery.close();d.cameraPanel?.orderOut(nil);d.feedbackPanel?.orderOut(nil)
            try JSONSerialization.data(withJSONObject:checks,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("results.json"))
            print(checks.sorted{$0.key<$1.key}.map{"\($0.value ? "PASS" : "FAIL") \($0.key)"}.joined(separator:"\n"))
            exit(checks.values.allSatisfy{$0} ? 0:1)
        } catch { print("Observation verification failed: \(error)");exit(1) }
    }
}
