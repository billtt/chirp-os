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
            checks["settingsMenuDisabled"]=d.status.menu!.items.first{$0.action == #selector(d.showSpeciesSettings)}?.isEnabled == false
            let bird=Bird(position:CGPoint(x:300,y:300),fraction:0.5,profile:d.catalog.profile(.treeSparrow))
            d.birds=[bird];d.observationVisits.arrive(ObjectIdentifier(bird))
            func hitPoint(_ bird:Bird)->CGPoint {
                let art=d.arts[bird.profile.id]!, scale=d.spriteScale(for:bird)
                for y in 0..<48 { for x in 0..<48 where art.contains(frame:bird.frameName,x:x,y:y) {
                    return CGPoint(x:bird.position.x+(CGFloat(bird.facingRight ? x : 47-x)+0.5-(bird.facingRight ? 29:19))*scale,y:bird.position.y+(CGFloat(y)+0.5+bird.hopOffset-39)*scale)
                }}
                return .zero
            }
            d.paused=true;d.photograph(at:hitPoint(bird));checks["pausedCannotPhotograph"]=d.lifeList.records.isEmpty
            d.paused=false;d.photograph(at:hitPoint(bird))
            if let view=d.feedbackPanel?.contentView as? ObservationFeedbackView { try snapshot(view,to:folder.appendingPathComponent("feedback-new.png")) }
            d.photograph(at:hitPoint(bird))
            checks["repeatShowsOnlyBirdName"]=(d.feedbackPanel?.contentView as? ObservationFeedbackView)?.text == d.language.name(bird.profile.id)
            if let view=d.feedbackPanel?.contentView as? ObservationFeedbackView { try snapshot(view,to:folder.appendingPathComponent("feedback-repeat.png")) }
            checks["feedbackFitsText"]=ObservationFeedbackView.textWidth("麻雀") < 60 && ObservationFeedbackView.textWidth("麻雀 +1 · 加新！") > ObservationFeedbackView.textWidth("麻雀")
            let target=CameraTargetView(frame:NSRect(x:0,y:0,width:28,height:28))
            let targetImage=try snapshot(target,to:folder.appendingPathComponent("viewfinder.png"))
            checks["viewfinderHasOwnVisiblePixels"]=(0..<28).contains { x in (0..<28).contains { y in (targetImage.colorAt(x:x,y:y)?.alphaComponent ?? 0) > 0.5 } }
            checks["sameVisitRecordedOnlyOnce"]=d.lifeList.records["treeSparrow"]?.count == 1
            let first=d.lifeList.records["treeSparrow"]!.firstRecordedAt
            let another=Bird(position:CGPoint(x:300,y:300),fraction:0.5,profile:d.catalog.profile(.treeSparrow))
            d.birds=[another];d.observationVisits.arrive(ObjectIdentifier(another));d.photograph(at:hitPoint(another))
            checks["newVisitIncrementsPreservingFirstDate"]=d.lifeList.records["treeSparrow"]?.count == 2 && d.lifeList.records["treeSparrow"]?.firstRecordedAt == first
            let grid=BirdGalleryView(desktop:d);grid.updateLayout()
            checks["recordedSpeciesSortFirst"]=grid.profiles.first?.id == .treeSparrow
            checks["lifeListKeepsUndiscoveredSilhouettes"]=grid.profiles.count == SpeciesID.allCases.count
            checks["modeMenuNames"]=d.status.menu!.items.contains{$0.title == "观鸟模式"} && d.status.menu!.items.contains{$0.title == "观鸟记录…"}
            let gallery=SpeciesGallery(desktop:d);gallery.showWindow(nil)
            let content=gallery.window!.contentView!
            content.layoutSubtreeIfNeeded();content.displayIfNeeded()
            checks["singleModeView"]=content.subviews.compactMap{$0 as? NSSegmentedControl}.allSatisfy{$0.isHidden} && gallery.window!.title.hasPrefix("Life List")
            checks["noEmptyActionBar"]=content.subviews.compactMap{$0 as? NSScrollView}.first?.frame.height == content.bounds.height
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
