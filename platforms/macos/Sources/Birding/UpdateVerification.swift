import AppKit
import BirdingCore

enum UpdateVerification {
    static func run(to folder:URL) {
        do {
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            var checks:[String:Bool]=[:]
            let state=folder.appendingPathComponent("notification-state-\(UUID().uuidString).json")
            let desktop=DesktopController();desktop.makeMenu()
            let updater=UpdateController(desktop:desktop,stateFile:state);desktop.updater=updater
            let release=UpdateRelease(version:"1.2.3",notes:"更新内容 / What's new\n\n• 更自然的猛禽盘旋\n• 按鸟种调整振翅频率\n• 保留所有现有设置\n\nThis is a local UI fixture. No download or installation occurs.",assetName:"fixture.zip",downloadURL:"",sha256:String(repeating:"0",count:64),size:1)
            let ready=ReadyUpdate(token:UUID().uuidString,release:release)
            updater.acceptVerifiedUpdate(ready)
            checks["nonactivatingBubble"] = updater.bubble?.canBecomeKey == false && updater.bubble?.isVisible == true
            checks["pendingMenuEntry"] = desktop.status.menu?.items.contains(where:{$0.title.contains("1.2.3") && $0.action == #selector(UpdateController.confirmUpdate)}) == true
            checks["manualCheckMenuEntry"] = desktop.status.menu?.items.contains(where:{$0.title == "检查更新…"}) == true
            if let bubble=updater.bubble { try SettingsVerification.snapshot(bubble,to:folder.appendingPathComponent("update-bubble.png")) }
            let original=NSImage(cgImage:desktop.art.frames["stand"]!,size:NSSize(width:24,height:24))
            let badge=updater.decorate(original)
            checks["redBadgeChangesIcon"] = badge.tiffRepresentation != original.tiffRepresentation
            if let data=badge.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data) { try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("update-badge.png")) }
            let dialog=updater.confirmationDialog(for:ready)
            checks["confirmationHasNotesAndChoices"] = dialog.messageText.contains("1.2.3") && dialog.buttons.map(\.title) == ["安装并重启","晚点再说"] && dialog.accessoryView is NSScrollView
            dialog.layout()
            // Cancel the real presentation through its modal response; installation
            // must not start and the verified update must remain in the menu.
            let cancel=Timer(timeInterval:0.5,repeats:false) { _ in
                if let window=NSApp.modalWindow,let view=window.contentView {
                    window.displayIfNeeded()
                    if let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                        view.cacheDisplay(in:view.bounds,to:bitmap)
                        try? bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("update-confirmation.png"))
                    }
                }
                NSApp.abortModal()
            }
            RunLoop.main.add(cancel,forMode:.modalPanel)
            updater.confirmUpdate()
            checks["laterKeepsUpdateWithoutInstalling"] = updater.pending?.release.version == "1.2.3" && !updater.installing
            let second=UpdateController(desktop:desktop,stateFile:state)
            second.acceptVerifiedUpdate(ready)
            checks["restartDoesNotRepeatNotification"] = second.bubble == nil && second.pending != nil
            let journalBefore=try Data(contentsOf:state)
            let settings=SpeciesSettingsWindow(desktop:desktop)
            let root=settings.window!.contentView!
            let debugButton=root.subviews.compactMap{$0 as? NSButton}.first{$0.tag == 2}!
            checks["debugInitiallyHidden"] = debugButton.isHidden
            let unlock=root.subviews.compactMap{$0 as? DebugUnlockView}.first!
            func click(_ count:Int,_ timestamp:TimeInterval) {
                let event=NSEvent.mouseEvent(with:.leftMouseDown,location:.zero,modifierFlags:[],timestamp:timestamp,windowNumber:settings.window!.windowNumber,context:nil,eventNumber:count,clickCount:count,pressure:1)!
                unlock.mouseDown(with:event)
            }
            click(2,1);checks["oneDoubleClickStaysHidden"] = debugButton.isHidden
            click(4,1.3);checks["twoDoubleClicksUnlock"] = !debugButton.isHidden
            debugButton.performClick(nil)
            checks["debugPageSelectable"] = settings.tabs.selectedTabViewItem?.identifier as? String == "debug"
            try SettingsVerification.snapshot(settings.window!,to:folder.appendingPathComponent("debug-settings.png"))
            settings.simulateUpdate()
            checks["simulationUsesNotificationAndBadge"] = updater.isSimulating && updater.bubble?.isVisible == true && updater.decorate(original).tiffRepresentation != original.tiffRepresentation
            let later=Timer(timeInterval:0.1,repeats:false){_ in NSApp.abortModal()}
            RunLoop.main.add(later,forMode:.modalPanel);updater.confirmUpdate()
            checks["simulationLaterKeepsPrompt"] = updater.isSimulating && !updater.installing
            func confirmSimulation() {
                let confirm=Timer(timeInterval:0.1,repeats:false){_ in NSApp.stopModal(withCode:.alertFirstButtonReturn)}
                RunLoop.main.add(confirm,forMode:.modalPanel);updater.confirmUpdate()
            }
            confirmSimulation()
            checks["simulationRestoresRealPending"] = !updater.isSimulating && updater.pending?.token == ready.token && !updater.installing && updater.bubble?.isVisible == false
            checks["simulationDoesNotChangeJournal"] = try Data(contentsOf:state) == journalBefore
            desktop.updater=second
            let empty=UpdateController(desktop:desktop,stateFile:folder.appendingPathComponent("unused-state.json"));desktop.updater=empty
            _=empty.simulateUpdate()
            let confirm=Timer(timeInterval:0.1,repeats:false){_ in NSApp.stopModal(withCode:.alertFirstButtonReturn)}
            RunLoop.main.add(confirm,forMode:.modalPanel);empty.confirmUpdate()
            checks["simulationClearsBadgeWithoutRealUpdate"] = empty.pending == nil && !empty.installing && empty.decorate(original) === original
            checks["simulationLeavesNoJournal"] = !FileManager.default.fileExists(atPath:folder.appendingPathComponent("unused-state.json").path)
            settings.window?.close()
            desktop.updater=nil;NSStatusBar.system.removeStatusItem(desktop.status)
            saveJSON(["passed":checks.values.allSatisfy{$0},"checks":checks],to:folder.appendingPathComponent("report.json"))
            print("Update UI: \(checks.values.allSatisfy{$0} ? "PASS":"FAIL") — \(checks.count) checks")
            exit(checks.values.allSatisfy{$0} ? 0:1)
        } catch { print("Update UI: FAIL — \(error)");exit(1) }
    }
}
