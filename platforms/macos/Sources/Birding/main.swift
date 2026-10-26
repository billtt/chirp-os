import AppKit
import BirdingCore

func argument(_ flag:String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of:flag),i+1<CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i+1]
}
if let token=argument("--apply-update") { exit(UpdateInstaller.runHelper(token:token)) }
if let path=argument("--verify-update-archive") {
    do { let expanded=try UpdateArchive.validate(Data(contentsOf:URL(fileURLWithPath:path),options:.mappedIfSafe));print("Update archive structure: PASS (\(expanded) expanded bytes)");exit(0) }
    catch { print("Update archive structure: FAIL — \(error)");exit(1) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if let path = argument("--verify-art") {
    do { try BirdArt.verifyArt(to:URL(fileURLWithPath:path)); exit(0) }
    catch { fputs("Art verification failed: \(error)\n",stderr); exit(1) }
}
if let path = argument("--export-shared") {
    do { try BirdArt.exportShared(to:URL(fileURLWithPath:path)); exit(0) }
    catch { fputs("Shared export failed: \(error)\n",stderr); exit(1) }
}
if let path = argument("--export-icon") {
    do {
        try BirdArt().exportAppIcon(to:URL(fileURLWithPath:path),macOSMask:CommandLine.arguments.contains("--macos-mask"))
        exit(0)
    } catch { fputs("Icon export failed: \(error)\n",stderr); exit(1) }
}
if let path = argument("--export-art") {
    do { try BirdArt().export(to:URL(fileURLWithPath:path)); exit(0) }
    catch { fputs("Art export failed: \(error)\n",stderr); exit(1) }
}
if let path = argument("--export-species") {
    do { try BirdArt.exportSpecies(to:URL(fileURLWithPath:path)); exit(0) }
    catch { fputs("Species export failed: \(error)\n",stderr); exit(1) }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    var desktop: DesktopController?
    var fixture: FixtureController?
    var populationCheck: PopulationVerification?
    func applicationDidFinishLaunching(_ notification:Notification) {
        if let path = argument("--verify-updates") { UpdateVerification.run(to:URL(fileURLWithPath:path)); return }
        if let path = argument("--verify-ground") { GroundVerification.run(to:URL(fileURLWithPath:path)); return }
        if let path = argument("--verify-birds") { ExpandedVerification.run(to:URL(fileURLWithPath:path)); return }
        if let path = argument("--verify-observations") { ObservationVerification.run(to:URL(fileURLWithPath:path)); return }
        if let path = argument("--verify-settings") { SettingsVerification.run(to:URL(fileURLWithPath:path)); return }
        if let path = argument("--fixture") {
            fixture = FixtureController(folder:URL(fileURLWithPath:path)); fixture?.start()
        } else {
            let d = DesktopController(); desktop = d
            d.diagnosticPath = argument("--diagnostics"); d.start()
            UpdateInstaller.confirmHealthy(desktop:d)
            if Bundle.main.bundleURL.pathExtension == "app" && !CommandLine.arguments.contains(where:{$0.hasPrefix("--verify") || $0 == "--integration"}) {
                d.updater=UpdateController(desktop:d);d.updater?.start();d.makeMenu()
            }
            if let path = argument("--verify-population") {
                populationCheck = PopulationVerification(desktop:d,path:path); populationCheck?.start()
            }
            if let path = argument("--integration") {
                let check = IntegrationCheck(desktop:d,folder:URL(fileURLWithPath:path))
                d.integration = check; check.start()
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
