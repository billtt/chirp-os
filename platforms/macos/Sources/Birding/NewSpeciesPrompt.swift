import AppKit
import BirdingCore

extension DesktopController {
    func promptNewSpecies() {
        guard !lifeList.enabled else { return }
        guard let ids=settings.pendingSpecies,!ids.isEmpty else{return}
        let alert=NSAlert()
        alert.messageText=t("发现 \(ids.count) 种新鸟","\(ids.count) new bird species")
        let share=String(format:"%.2f",100*Double(ids.count)/Double(catalog.species.count))
        alert.informativeText=t("如何分配出现概率？\n恢复默认：重置所有概率并解除锁定，保留体型与动作设置。\n按数量分配：新鸟合计获得 \(share)%，内部按默认比例分配；旧鸟等比缩放（包括锁定项，锁定状态保留）。\n手动设置：保留旧概率，新鸟为 0%，打开并定位到第一种新鸟。", "Choose arrival probabilities.\nDefaults: reset all probabilities and unlock them; keep size and behavior settings.\nBy count: new species share \(share)% using default proportions; scale existing probabilities, including locked values, keeping locks.\nManual: keep existing probabilities, set new species to 0%, and jump to the first new species.")
        alert.addButton(withTitle:t("所有概率恢复默认","Restore default probabilities"))
        alert.addButton(withTitle:t("按鸟种数量分配","Allocate by species count"))
        alert.addButton(withTitle:t("手动设置…","Set manually…"))
        NSApp.activate(ignoringOtherApps:true)
        let answer=alert.runModal()
        if answer == .alertThirdButtonReturn {
            showSpeciesSettings();settingsWindow?.scrollToSpecies(ids[0]);return
        }
        var value=settings
        if answer == .alertFirstButtonReturn {value.probabilities=ProbabilityDistribution(catalog:.standard)}
        else if answer == .alertSecondButtonReturn {value.probabilities.allocateNewSpecies(ids,catalog:.standard)}
        else {return}
        do {try applySettings(value)} catch {
            let errorAlert=NSAlert();errorAlert.messageText=t("无法保存，请重试","Could not save; please try again");errorAlert.runModal()
        }
    }
}
