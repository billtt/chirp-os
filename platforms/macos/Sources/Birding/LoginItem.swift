import AppKit
import ServiceManagement

protocol LoginItemManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItem: LoginItemManaging {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

extension DesktopController: NSMenuDelegate {
    func addLoginItem(to menu:NSMenu) {
        let item = NSMenuItem(title:"",action:#selector(toggleLoginItem),keyEquivalent:"")
        item.target = self; menu.addItem(item); loginItem = item
        let approval = NSMenuItem(title:"",action:#selector(openLoginSettings),keyEquivalent:"")
        approval.target = self; menu.addItem(approval); loginApprovalItem = approval
        refreshLoginItem()
    }
    func menuWillOpen(_ menu:NSMenu) { observationMenuOpen=true; cameraPanel?.orderOut(nil); refreshLoginItem() }
    func menuDidClose(_ menu:NSMenu) { observationMenuOpen=false }
    func refreshLoginItem() {
        let state = loginService.status
        loginItem?.title = state == .requiresApproval
            ? t("随系统启动（需系统批准）","Launch at Login (Approval Required)")
            : t("随系统启动","Launch at Login")
        loginItem?.state = state == .enabled ? .on : (state == .requiresApproval ? .mixed : .off)
        loginApprovalItem?.title = t("在系统设置中允许…","Allow in System Settings…")
        loginApprovalItem?.isHidden = state != .requiresApproval
        settingsWindow?.refreshMode()
    }
    @objc func toggleLoginItem() {
        do {
            switch loginService.status {
            case .enabled, .requiresApproval: try loginService.unregister()
            default: try loginService.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = t("无法更改随系统启动设置","Could Not Change Launch at Login")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle:t("好","OK"))
            NSApp.activate(ignoringOtherApps:true)
            alert.runModal()
        }
        refreshLoginItem()
    }
    @objc func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
}
