import Foundation

public enum GalleryPose {
    public static func frame(_ id:SpeciesID,age:Double,fps:Double) -> String {
        var phases:[(Double,[String],Double)]=[(2,["stand","breathe"],1.8),(0.4,["blink"],1),(3,(0..<8).map{"fly\($0)"},fps),(0.42,(0..<3).map{"land\($0)"},1/0.14),(3,["idle0","idle1","idle2","idle1"],SpeciesBehavior.motion(id).rate),(2,["preen0","preen1"],4)]
        if id == .nightHeron {phases += [(2,["stretch"],1),(1,["shake","stand"],8),(1,["poop0","poop1"],6)]}
        if id == .greatSpottedWoodpecker {phases += [(2,["cling0"],1),(2,["peck0","peck1"],12)]}
        var t=max(0,age).truncatingRemainder(dividingBy:phases.reduce(0){$0+$1.0})
        for (duration,frames,rate) in phases {if t<duration{return frames[Int(t*rate)%frames.count]};t-=duration}
        return "stand"
    }
}
