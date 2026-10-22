import AppKit
import BirdingCore

enum GroundVerification {
    static func run(to folder:URL) {
        do {
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let d=DesktopController(),screens=NSScreen.screens
            guard let screen=screens.first else { throw NSError(domain:"GroundVerification",code:1) }
            let grounds=d.groundSurfaces(),display=d.displayRects[0],work=d.screenRects[0]
            var checks:[String:Bool]=[:]
            checks["groundPerDisplay"]=grounds.count==screens.count
            checks["stableGroundIdentity"]=grounds.map(\.id)==d.groundSurfaces().map(\.id)
            func bird(_ id:SpeciesID = .treeSparrow) -> Bird {
                let b=Bird(position:CGPoint(x:work.midX,y:work.midY),fraction:0.5,profile:d.catalog.profile(id));d.birds.append(b);return b
            }
            func settles(_ b:Bird) -> Bool {
                d.chooseDestination(b);b.tick(b.flightDuration);b.tick(0.5)
                return b.state == .perched && !b.needsDestination && grounds.contains(where:{$0.id==b.hostID})
            }
            for (label,windows) in [("emptyDesktop",[Surface]()),("maximizedWindow",[Surface(id:10,rect:work)])] {
                d.surfaces=windows+grounds;d.birds=[]
                for id:SpeciesID in [.treeSparrow,.blackKite,.nightHeron,.greatSpottedWoodpecker] {
                    let b=bird(id)
                    checks["\(label)_\(id.rawValue)"]=settles(b)
                    checks["\(label)_visible_\(id.rawValue)"]=d.displayRects.contains{ $0.contains(Geometry.landingFootprint(at:b.position,scale:d.spriteScale(for:b))) }
                }
                let footprints=d.birds.map{Geometry.landingFootprint(at:$0.position,scale:d.spriteScale(for:$0))}
                checks["\(label)_spaced"]=footprints.indices.allSatisfy { i in footprints.indices.allSatisfy { j in i==j || !footprints[i].intersects(footprints[j]) } }
            }
            let normal=Surface(id:11,rect:CGRect(x:work.midX-300,y:work.midY,width:600,height:200))
            d.surfaces=[normal]+grounds;d.birds=[]
            let preferred=bird();d.chooseDestination(preferred)
            checks["usableWindowsRemainPreferred"]=preferred.hostID==normal.id
            let crowded=Surface(id:12,rect:CGRect(x:work.midX-100,y:work.midY,width:200,height:200))
            d.surfaces=[crowded]+grounds;d.birds=[]
            let occupant=bird(.greyHeron);occupant.perch(on:crowded,spriteScale:d.spriteScale(for:occupant))
            checks["crowdedWindowFallsBack"]=settles(bird())
            // Render a real nonactivating overlay, with a neutral backing only for the snapshot.
            d.surfaces=grounds;d.birds=[]
            for id:SpeciesID in [.treeSparrow,.blackKite,.nightHeron,.greatSpottedWoodpecker] { _=settles(bird(id)) }
            let panel=OverlayPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.ignoresMouseEvents=true;panel.isOpaque=false;panel.backgroundColor = .clear
            let view=DesktopView(frame:CGRect(origin:.zero,size:screen.frame.size));view.controller=d;view.desktopRect=display
            panel.contentView=view;view.layer?.backgroundColor=NSColor(calibratedWhite:0.94,alpha:1).cgColor
            let floor=CALayer();floor.frame=CGRect(x:0,y:work.maxY-display.minY,width:display.width,height:max(1,display.maxY-work.maxY));floor.backgroundColor=NSColor(calibratedWhite:0.78,alpha:1).cgColor
            view.layer?.addSublayer(floor);panel.orderFrontRegardless();view.updateSprites()
            checks["overlayPassesInput"]=panel.ignoresMouseEvents && !panel.canBecomeKey && !panel.canBecomeMain
            try SettingsVerification.snapshot(panel,to:folder.appendingPathComponent("ground-perching.png"));panel.orderOut(nil)
            d.rebuildScreens()
            checks["screenRebuildKeepsGroundBirdsResting"]=d.birds.allSatisfy{$0.state == .perched && $0.startledCount == 0}
            d.panels.forEach{$0.orderOut(nil)}
            saveJSON(["passed":checks.values.allSatisfy{$0},"checks":checks],to:folder.appendingPathComponent("report.json"))
            print("Ground desktop: \(checks.values.allSatisfy{$0} ? "PASS":"FAIL") — \(checks.count) checks")
            exit(checks.values.allSatisfy{$0} ? 0:1)
        } catch { print(error);exit(1) }
    }
}
