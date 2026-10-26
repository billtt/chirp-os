import AppKit
import BirdingCore

/// Shape and feather primitives shared by both generations of species drawings.
/// Coordinates stay in the 48-unit canvas; the feet keep their (29, 39) anchor.
enum BirdPlumage {
    // Used by the rendered-art regression check to measure exposed foot pixels
    // after the body and both wings have been composited.
    static var omitFlightFeetForVerification = false
    static func folded(_ frame: String) -> Bool {
        !frame.hasPrefix("fly") && !frame.hasPrefix("glide") && !frame.hasPrefix("bank") && frame != "bound"
            && (!frame.hasPrefix("land") || frame == "land2")
    }

    static func torso(_ c: BirdPainter, x: Double, y: Double, w: Double, h: Double,
                      back: String, belly: String, flying: Bool) {
        // A tapered rump and a breast/keel contour, rather than two overlapping
        // ellipses. Colour is clipped to this same silhouette at every density.
        let path = CGMutablePath()
        path.move(to: CGPoint(x:x, y:y+h*0.48))
        path.addCurve(to:CGPoint(x:x+w*0.72,y:y+h*0.04),control1:CGPoint(x:x+w*0.19,y:y-h*0.05),control2:CGPoint(x:x+w*0.50,y:y))
        path.addCurve(to:CGPoint(x:x+w,y:y+h*0.48),control1:CGPoint(x:x+w*0.94,y:y+h*0.06),control2:CGPoint(x:x+w*1.02,y:y+h*0.25))
        path.addCurve(to:CGPoint(x:x+w*0.56,y:y+h*0.96),control1:CGPoint(x:x+w,y:y+h*0.80),control2:CGPoint(x:x+w*0.82,y:y+h))
        path.addCurve(to:CGPoint(x:x,y:y+h*0.48),control1:CGPoint(x:x+w*0.32,y:y+h*(flying ? 0.88:0.96)),control2:CGPoint(x:x+w*0.10,y:y+h*0.64))
        path.closeSubpath()
        c.ctx.addPath(path);c.ctx.setFillColor(c.color(back));c.ctx.setStrokeColor(c.color("outline"));c.ctx.setLineWidth(c.unit);c.ctx.drawPath(using:.fillStroke)
        c.ctx.saveGState();c.ctx.addPath(path);c.ctx.clip()
        c.pigment {
            let breast = CGMutablePath()
            breast.move(to:CGPoint(x:x+w*0.72,y:y))
            breast.addCurve(to:CGPoint(x:x+w*0.33,y:y+h),control1:CGPoint(x:x+w*0.83,y:y+h*0.42),control2:CGPoint(x:x+w*0.67,y:y+h*0.80))
            breast.addLine(to:CGPoint(x:x+w,y:y+h));breast.addLine(to:CGPoint(x:x+w,y:y));breast.closeSubpath()
            c.ctx.addPath(breast);c.ctx.setFillColor(c.color(belly));c.ctx.fillPath()
            let shade = mix(c, belly, "umber", amount:0.13, key:"bellyShade")
            c.curve([(x+w*0.32,y+h*0.82),(x+w*0.56,y+h*1.04),(x+w*0.84,y+h*0.94),(x+w*0.94,y+h*0.69)],shade,width:Double(c.unit)*1.1)
        }
        c.ctx.restoreGState()
    }

    static func foldedWing(_ c:BirdPainter, y:Double, height:Double, fill:String, coverts:String,
                           markings:() -> Void) {
        let bottom = y+height-0.7
        let path=CGMutablePath()
        path.move(to:CGPoint(x:18,y:y+1.7))
        path.addCurve(to:CGPoint(x:28,y:y+3.8),control1:CGPoint(x:21,y:y-0.2),control2:CGPoint(x:26,y:y+0.5))
        path.addCurve(to:CGPoint(x:16,y:bottom),control1:CGPoint(x:27,y:y+height*0.67),control2:CGPoint(x:20,y:bottom))
        path.addCurve(to:CGPoint(x:18,y:y+1.7),control1:CGPoint(x:15.7,y:y+height*0.67),control2:CGPoint(x:16.5,y:y+3))
        path.closeSubpath()
        c.ctx.addPath(path);c.ctx.setFillColor(c.color(fill));c.ctx.setStrokeColor(c.color("outline"));c.ctx.setLineWidth(c.unit);c.ctx.drawPath(using:.fillStroke)
        c.ctx.saveGState();c.ctx.addPath(path);c.ctx.clip()
        c.pigment {
            c.oval(17,y+0.6,10,height*0.55,coverts)
            let edge=mix(c,fill,coverts,amount:0.46,key:"foldedFeather")
            for i in 0..<5 {
                let t=Double(i)
                c.curve([(25.5-t*0.75,y+3.3),(24.5-t*0.8,y+height*0.60),(20.5-t*0.65,bottom-1.6),(18.4-t*0.54,bottom)],edge,width:Double(c.unit))
            }
            markings()
        }
        c.ctx.restoreGState()
    }

    static func flightTail(_ c:BirdPainter, root:Double, tip:Double, y:Double,
                           width:Double, fill:String, light:String, fork:Double=0) {
        c.poly([(root+3,y-1),(tip,y-width/2),(tip+fork,y),
                (tip,y+width/2),(root+3,y+1.8)],fill,outline:true)
        let edge=mix(c,fill,light,amount:0.4,key:"tailFeather")
        c.within([(root+3,y-1),(tip,y-width/2),(tip+fork,y),(tip,y+width/2),(root+3,y+1.8)]) {
            for i in 0..<3 {
                let offset=(Double(i)-1)*width*0.23
                c.line([(root,y+offset*0.3),(tip+max(0.8,fork),y+offset)],edge,width:Double(c.unit))
            }
        }
    }

    /// Feet are layered after the abdomen. Trailing aquatic feet must extend
    /// beyond the rump; compact birds keep short, curled toes under the vent.
    static func flightFeet(_ c:BirdPainter, family:String, x:Double, y:Double, color:String) {
        guard !omitFlightFeetForVerification else { return }
        let trailing=["duck","grebe","gull","wader","rail","egret"].contains(family)
        if trailing {
            let length = family == "egret" ? 18.0 : (family == "wader" ? 14.0 : (family == "grebe" ? 10.0:7.0))
            for i in 0..<2 {
                let offset=Double(i)*1.7, tip=max(1.5,x-length-Double(i)*0.7)
                c.line([(x+1,y-1+offset),(x-2,y+0.6+offset),(tip,y+1.1+offset)],color,width:0.65)
                if family == "duck" || family == "gull" {
                    c.poly([(tip+1,y+0.6+offset),(max(0.8,tip-2),y+0.4+offset),(max(0.8,tip-2),y+2.1+offset),(tip+1.5,y+1.5+offset)],color)
                } else {
                    c.line([(tip+1,y+1+offset),(tip-0.6,y+0.1+offset)],color,width:0.55)
                    c.line([(tip+1,y+1+offset),(tip-0.5,y+2+offset)],color,width:0.55)
                    if family == "grebe" {c.oval(tip-0.3,y+1+offset,1.5,0.7,"gray")}
                }
            }
        } else {
            for i in 0..<2 {
                let offset=Double(i)*1.9
                c.line([(x+2+offset,y-0.8),(x+0.7+offset,y+0.8),(x-1+offset,y+1),(x-0.7+offset,y+0.2)],color,width:0.65)
            }
        }
    }

    @discardableResult
    static func mix(_ c:BirdPainter,_ first:String,_ second:String,amount:Double,key:String) -> String {
        let a=c.palette[first]!,b=c.palette[second]!
        func channel(_ shift:UInt32)->UInt32 {
            let first=Double((a>>shift)&255)*(1-amount)
            let second=Double((b>>shift)&255)*amount
            return UInt32((first+second).rounded())
        }
        c.palette[key]=(channel(24)<<24)|(channel(16)<<16)|(channel(8)<<8)|255
        return key
    }
}
