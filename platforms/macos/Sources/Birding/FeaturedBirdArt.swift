import AppKit
import BirdingCore

/// The 20 additions use the existing pixel density, palette and foot anchor.
/// Projecting crests, ribbons, sails and bills are anatomy; pigment stays clipped.
enum FeaturedBirdArt {
    typealias Anatomy = ExpansionBirdArt.Anatomy
    static let profiles: [SpeciesID: Anatomy] = [
        .blackNapedOriole: Anatomy("song", ["yellow", "black", "yellow", "yellow", "pink"], [19, 11, 8, 7, 13, 6, 40]),
        .amurParadiseFlycatcher: Anatomy("ribbon", ["white", "white", "black", "white", "cyan"], [13, 10, 7, 7, 12, 2, 44]),
        .blueTailedBeeEater: Anatomy("pointed", ["green", "green", "green", "olive", "black"], [17, 9, 7, 6, 14, 3, 43]),
        .orientalDollarbird: Anatomy("pointed", ["slate", "navy", "umber", "slate", "red"], [21, 12, 9, 8, 12, 10, 36]),
        .blackCappedKingfisher: Anatomy("kingfisher", ["blue", "navy", "black", "buff", "red"], [17, 12, 11, 8, 12, 13, 34]),
        .bohemianWaxwing: Anatomy("song", ["tan", "black", "tan", "gray", "black"], [20, 13, 9, 8, 13, 10, 39]),
        .goldcrest: Anatomy("song", ["olive", "dark", "olive", "cream", "dark"], [14, 11, 8, 7, 16, 12, 38]),
        .eurasianSiskin: Anatomy("finch", ["olive", "black", "yellow", "yellow", "pink"], [15, 11, 8, 7, 15, 9, 39]),
        .brambling: Anatomy("finch", ["black", "black", "black", "white", "yellow"], [18, 12, 8, 7, 14, 8, 40]),
        .commonRosefinch: Anatomy("finch", ["brown", "brown", "red", "white", "dark"], [18, 12, 9, 8, 14, 9, 40]),
        .yellowThroatedBunting: Anatomy("finch", ["brown", "umber", "black", "white", "dark"], [17, 11, 8, 7, 14, 7, 40]),
        .greyWagtail: Anatomy("wagtail", ["slate", "black", "gray", "yellow", "dark"], [16, 9, 7, 6, 16, 2, 43]),
        .eurasianJay: Anatomy("crow", ["tan", "black", "tan", "tan", "dark"], [21, 13, 9, 8, 12, 7, 40]),
        .redCrossbill: Anatomy("finch", ["rust", "umber", "red", "rust", "dark"], [19, 13, 10, 8, 13, 10, 39]),
        .mandarinDuck: Anatomy("duck", ["brown", "navy", "green", "cream", "red"], [24, 11, 9, 8, 14, 9, 34]),
        .piedAvocet: Anatomy("wader", ["white", "black", "white", "white", "black"], [18, 8, 6, 5, 9, 12, 28]),
        .whiteBreastedWaterhen: Anatomy("rail", ["slate", "dark", "slate", "white", "olive"], [20, 11, 8, 7, 14, 12, 29]),
        .goldenPheasant: Anatomy("pheasant", ["green", "blue", "yellow", "red", "cream"], [15, 10, 7, 6, 12, 2, 44]),
        .redCrownedCrane: Anatomy("crane", ["white", "white", "white", "white", "olive"], [16, 8, 6, 4.5, 5, 14, 27]),
        .crestedIbis: Anatomy("ibis", ["white", "white", "white", "white", "black"], [19, 9, 7, 5, 11, 12, 30]),
    ]

    static func make(_ frame:String, species id:SpeciesID, anatomy a:Anatomy) -> CGImage {
        let c=BirdPainter(size:max(48,Int((48*SpeciesCatalog.standard.profile(id).relativeScale).rounded())))
        // Restrained additions to the existing palette, for iridescence and pale pink flight feathers.
        c.palette["teal"]=0x3D7272FF; c.palette["violet"]=0x61435FFF; c.palette["blush"]=0xE6C4BCFF
        let phase=Int(String(frame.last!)) ?? 0
        let flying=frame.hasPrefix("fly") || frame.hasPrefix("glide") || frame.hasPrefix("bank") || frame == "bound"
        let glide=frame.hasPrefix("glide") || frame.hasPrefix("bank") || frame == "bound"
        let landing=frame.hasPrefix("land"), preening=frame.hasPrefix("preen")
        let active=frame.hasPrefix("idle"), amount=active ? [0.18,0.58,1.0][min(phase,2)]:0
        let action=SpeciesBehavior.motion(id).action
        let opening=active && action == .wing
        let folded=BirdPlumage.folded(frame) && !opening
        let longLeg=["crane","ibis","wader"].contains(a.family)
        let bob=frame == "breathe" ? -0.55:0.0
        let by=flying ? 22.0 : (longLeg ? 18.0:(a.family == "duck" ? 25.0:22.0))+bob
        let bh=flying ? a.height*0.57:a.height
        let bw=flying ? a.width*0.9:a.width
        let bodyX=34-bw
        let hw=flying ? a.headWidth*0.87:a.headWidth
        let hh=flying ? a.headHeight*0.87:a.headHeight
        var hx=35-hw, hy=a.headY+bob
        if flying {
            hx=longLeg ? (id == .redCrownedCrane ? 37:33):min(33,38-hw)
            hy=longLeg ? 20:18
        }
        if active {
            switch action {
            case .call: hy-=amount*3; hx-=amount*0.8
            case .glean:hy-=amount*4;hx+=amount*1.4
            case .crack:
                hy+=amount*(id == .bohemianWaxwing ? -3:4)
                hx+=amount*(id == .redCrossbill ? -2:1.2)
            case .probe:
                hy+=amount*(longLeg ? 14:(id == .goldenPheasant ? 10:6))
                hx+=amount*(id == .piedAvocet ? -3:1.5)
            case .dabble:hy+=amount*9;hx+=amount
            case .stalk:hy-=amount*2;hx+=amount
            case .wing:hy+=amount*(id == .orientalDollarbird ? 2:-1.5)
            case .tail:hy-=amount*0.9
            default:break
            }
        }
        if preening {hx=22;hy=by+2+Double(phase)*1.2}
        if flying {
            c.ctx.saveGState();c.ctx.translateBy(x:27,y:24)
            let tilt=frame.hasPrefix("bank") ? Double(phase-1)*0.09 : (glide ? -0.025:[0.02,0,-0.025,-0.04,0,0.025,0.04,0.015][phase%8])
            c.ctx.rotate(by:tilt);c.ctx.translateBy(x:-27,y:-24)
            wing(c,id,a,phase:phase,glide:glide,far:true)
        }
        tail(c,id,a,bodyX:bodyX,y:by+bh*0.6,flying:flying,phase:phase,amount:amount)
        let leg: String = [.blackCappedKingfisher,.crestedIbis,.orientalDollarbird].contains(id) ? "red" :
            (id == .mandarinDuck ? "orange" : (id == .whiteBreastedWaterhen || id == .goldenPheasant ? "yellow" : (id == .piedAvocet ? "slate":"dark")))
        if !flying {
            for (i,x) in [27.0,31.0].enumerated() {
                let lift=(id == .redCrownedCrane || id == .whiteBreastedWaterhen) && i == 0 ? amount*(longLeg ? 5:3):0
                c.line([(x,by+bh-2),(x-0.7,35-lift),(x,39-lift)],leg,width:longLeg ? 0.75:0.9)
                if a.family == "duck" {c.poly([(x,36-lift),(x-2,39-lift),(x+3,39-lift)],leg)}
                else {c.line([(x-2,39-lift),(x,38.6-lift),(x+(a.family == "rail" ? 3.5:2),39-lift)],leg,width:0.65)}
            }
        }
        let back=id == .orientalDollarbird ? "teal":a.back
        BirdPlumage.torso(c,x:bodyX,y:by,w:bw,h:bh,back:back,belly:a.belly,flying:flying)
        // Cranes and ibises keep an extended neck in flight, unlike the existing herons.
        let neckColor=id == .redCrownedCrane ? "black":a.belly
        if longLeg {
            if flying {
                c.curve([(30,by+2),(34,by),(hx-1,hy+2),(hx+2,hy+hh*0.6)],neckColor,width:id == .redCrownedCrane ? 2.5:2.8)
                if id == .redCrownedCrane {c.curve([(29,by+1),(34,by-1),(hx-1,hy+1),(hx+2,hy+1)],"white",width:1.2)}
            } else {
                c.curve([(29,by+4),(35,by+1),(hx-3,hy+hh),(hx+2,hy+hh*0.6)],neckColor,width:id == .redCrownedCrane ? 2.6:3.0)
                if id == .redCrownedCrane {c.curve([(28,by+3),(31,by),(hx-3,hy+hh),(hx+1,hy+2)],"white",width:1.25)}
            }
        } else {
            c.poly([(26,by+2),(hx+1,hy+hh*0.6),(hx+hw-1,hy+hh*0.65),(33,by+7)],a.belly)
        }
        bodyMarks(c,id,by,bh,flying)
        if folded {
            BirdPlumage.foldedWing(c,y:by,height:bh,fill:a.wing,coverts:back) {foldedMarks(c,id,by)}
            if id == .mandarinDuck {sail(c,y:by,amount:amount)}
            if id == .redCrownedCrane {
                // Drooping black tertials cover a white tail, not an all-black tail.
                c.poly([(22,by+2),(22,by+7),(17,by+12),(13,by+10),(17,by+4)],"black",outline:true)
                c.line([(20,by+4),(16,by+10)],"slate",width:0.7)
            }
        }
        // Face and bill turn together when preening; the neck remains connected.
        c.ctx.saveGState()
        if preening {c.ctx.translateBy(x:hx+hw/2,y:0);c.ctx.scaleBy(x:-1,y:1);c.ctx.translateBy(x:-(hx+hw/2),y:0)}
        crests(c,id,x:hx,y:hy,w:hw,h:hh,amount:amount)
        c.oval(hx,hy,hw,hh,a.head,outline:true)
        headMarks(c,id,x:hx,y:hy,w:hw,h:hh)
        let bx=hx+hw-0.4, yy=hy+hh*0.56
        bill(c,id,a,x:bx,y:yy,amount:amount,action:action)
        let ex=hx+hw*0.69,ey=hy+hh*0.38
        if id == .amurParadiseFlycatcher {c.oval(ex-0.9,ey-0.9,2.8,2.8,"cyan")}
        if id == .blackNapedOriole || id == .whiteBreastedWaterhen {c.oval(ex-0.5,ey-0.5,2.0,2.0,"red")}
        if id == .goldcrest {c.oval(ex-0.7,ey-0.7,2.5,2.5,"cream")}
        if frame == "blink" {c.line([(ex-0.3,ey+0.4),(ex+1,ey+0.4)],"eye")}
        else {c.oval(ex,ey,1.1,1.1,"eye");c.oval(ex+0.45,ey,0.4,0.4,"white")}
        c.ctx.restoreGState()
        if flying {
            let feetFamily=longLeg ? "wader":a.family
            let toeDrop=id == .greyWagtail ? 0.8:0.0
            BirdPlumage.flightFeet(c,family:feetFamily,x:bodyX+bw*0.32,y:by+bh*0.90+toeDrop,color:leg)
        }
        if flying || (landing && !folded) || opening {
            wing(c,id,a,phase:opening ? 18+phase:(landing ? 15+phase:phase),glide:glide,far:false)
        }
        if flying {c.ctx.restoreGState()}
        return c.image
    }

    static func tail(_ c:BirdPainter,_ id:SpeciesID,_ a:Anatomy,bodyX:Double,y:Double,flying:Bool,phase:Int,amount:Double) {
        if id == .amurParadiseFlycatcher {
            // Two separately outlined central feathers; changing curvature, not a rigid tail triangle.
            for i in 0..<2 {
                let d=Double(i)*2.2
                let wave=flying ? sin(Double(phase)*Double.pi/4+Double(i))*1.4:amount*6
                let points: [(Double,Double)] = flying ?
                    [(bodyX+4,y+d*0.3),(15,y+wave+d),(9,y-wave+d),(3+d,y+2+wave)] :
                    [(23+d*0.3,28),(15-d,34-wave),(12+d,44-wave),(3+d,44-wave*0.4)]
                c.curve(points,"outline",width:2.1);c.curve(points,"white",width:1.1)
            }
            return
        }
        let longTail=["pheasant","wagtail","pointed"].contains(a.family) && id != .orientalDollarbird
        var ty=flying ? y:min(44,a.tailY), tx=flying ? max(2.5,a.tailX-1):max(2.5,a.tailX)
        // The bee-eater's narrow central streamers project beyond its ordinary tail fan.
        if id == .blueTailedBeeEater {tx=9;ty=flying ? y:36}
        if id == .greyWagtail {ty-=amount*12;tx+=amount}
        if id == .whiteBreastedWaterhen {ty-=amount*8;tx+=amount*1.5}
        let color:String = id == .blueTailedBeeEater ? "blue" : (id == .goldenPheasant ? "brown":(id == .redCrownedCrane ? "white":a.wing))
        let root=flying ? bodyX+5:24.0
        let fork=a.family == "finch" ? 2.4:0
        let edge:[(Double,Double)]=flying ? [(root+2,y-1),(tx,ty-1.8),(tx+fork,ty),(tx,ty+1.8),(root+2,y+2)] :
            [(24,27),(tx,ty-1),(tx+fork,ty+0.6),(tx+1,ty+2),(tx+(longTail ? 4:6),ty+1),(27,31)]
        c.poly(edge,color,outline:true)
        c.within(edge) {
            c.line([(root,y),(tx+1,ty)],id == .goldenPheasant ? "tan":a.back,width:0.8)
            if id == .bohemianWaxwing {c.line([(tx,ty-2),(tx+3,ty+2)],"yellow",width:2.5)}
            if id == .greyWagtail {c.line([(tx,ty),(root,y+1.4)],"white",width:0.9)}
            if id == .eurasianSiskin {c.line([(root,y),(tx+4,ty)],"yellow",width:1.2)}
            if id == .goldenPheasant {
                for n in 0..<10 {
                    let t=Double(n)/11,xx=tx+(root-tx)*t,yy=ty+(y-ty)*t
                    c.line([(xx,yy-1.5),(xx+1,yy+1.5)],n%2 == 0 ? "black":"buff",width:0.8)
                }
            }
        }
        if id == .blueTailedBeeEater {
            let tipY=flying ? y+1:43.0
            c.line([(flying ? root:23,flying ? y:29),(2.3,tipY)],"outline",width:1.5)
            c.line([(flying ? root:23,flying ? y:29),(2.3,tipY)],"blue",width:0.8)
        }
        if id == .whiteBreastedWaterhen && !flying {
            c.poly([(20,27),(tx,ty+2),(18,32),(24,31)],"rust")
        }
    }

    static func bodyMarks(_ c:BirdPainter,_ id:SpeciesID,_ y:Double,_ h:Double,_ flying:Bool) {
        c.pigment {
            switch id {
            case .blackCappedKingfisher:c.line([(29,y),(33,y+3)],"white",width:3)
            case .brambling:c.oval(26,y-1,10,h*0.6,"orange");c.oval(14,y+1,5,h*0.7,"white")
            case .commonRosefinch:c.oval(27,y-1,8,h*0.55,"red");c.oval(15,y,6,3,"red")
            case .eurasianSiskin,.yellowThroatedBunting:
                for i in 0..<4 {let xx=25+Double(i)*1.8;c.line([(xx,y+h*0.52),(xx-0.5,y+h*0.8)],"umber",width:0.7)}
            case .greyWagtail:c.oval(17,y,6,4,"yellow")
            case .eurasianJay:c.oval(13,y+1,6,4,"white")
            case .bohemianWaxwing:c.oval(20,y+h-4,5,4,"rust")
            case .mandarinDuck:
                c.oval(28,y-1,8,h*0.85,"violet")
                c.line([(28,y+2),(28,y+h*0.8)],"white",width:1.3)
                c.line([(25.5,y+2),(25.5,y+h*0.85)],"black",width:0.8)
                for i in 0..<5 {let yy=y+4+Double(i)*0.9;c.line([(16,yy),(24,yy+0.5)],"tan",width:0.45)}
            case .whiteBreastedWaterhen:c.oval(17,y+h-5,8,5,"rust")
            case .goldenPheasant:c.oval(19,y,5,3,"yellow")
            case .crestedIbis:c.oval(16,y+h*0.5,11,h*0.45,"blush")
            default:break
            }
        }
    }

    static func crests(_ c:BirdPainter,_ id:SpeciesID,x:Double,y:Double,w:Double,h:Double,amount:Double) {
        switch id {
        case .amurParadiseFlycatcher:c.poly([(x+1,y+3),(x-1,y-2),(x+4,y),(x+6,y+3)],"black",outline:true)
        case .bohemianWaxwing:c.poly([(x+1,y+5),(x-3,y-3-amount*2),(x+4,y-1),(x+7,y+3)],"tan",outline:true)
        case .yellowThroatedBunting:c.poly([(x,y+4),(x+1,y-3),(x+4,y-1),(x+6,y+3)],"black",outline:true)
        case .mandarinDuck:
            c.poly([(x+4,y),(x-3,y+3),(x-4,y+7),(x+3,y+6)],"green",outline:true)
            c.poly([(x+2,y+4),(x+w-1,y+6),(x+1,y+h+6),(x-2,y+h+2)],"orange",outline:true)
            for n in 0..<4 {let t=Double(n);c.line([(x+2+t,y+6),(x-0.5+t*0.6,y+h+4)],"buff",width:0.65)}
        case .goldenPheasant:
            let crown=[(x+5,y+3),(x-5,y+4),(x-2,y-0.8),(x+3,y-0.4),(x+6,y+1.5)]
            c.poly(crown,"yellow",outline:true)
            c.within(crown) {
                for n in 0..<3 {let d=Double(n);c.line([(x+3,y+d),(x-3,y+2+d*0.6)],"buff",width:0.55)}
            }
            let cape=[(x+2,y+3),(x+w-1,y+6),(x+1-amount,y+12),(x-5-amount,y+7)]
            c.poly(cape,"orange",outline:true)
            c.within(cape) {for n in 0..<5 {let t=Double(n)*1.6;c.line([(x-4,y+4+t),(x+4,y+6+t)],"black",width:0.8)}}
        case .crestedIbis:
            for n in 0..<3 {let d=Double(n);c.curve([(x+2,y+1+d),(x-2,y+2+d),(x-3,y+6+d),(x-5,y+7+d)],"silver",width:0.9)}
        default:break
        }
    }

    static func headMarks(_ c:BirdPainter,_ id:SpeciesID,x:Double,y:Double,w:Double,h:Double) {
        c.pigment {
            func cheek(_ color:String) {c.poly([(x,y+h*0.5),(x+w,y+h*0.5),(x+w-1,y+h),(x+1,y+h)],color)}
            func mask() {c.line([(x,y+h*0.4),(x+w,y+h*0.4)],"black",width:1.6)}
            func bib(_ color:String) {c.poly([(x+w*0.4,y+h*0.7),(x+w,y+h*0.55),(x+w,y+h+4),(x+w*0.3,y+h+2)],color)}
            switch id {
            case .blackNapedOriole:mask();c.line([(x+1,y+1),(x+1,y+h*0.5)],"black",width:2)
            case .blueTailedBeeEater:
                c.line([(x,y+h*0.2),(x+w,y+h*0.3)],"cyan",width:1);mask()
                c.line([(x+1,y+h*0.65),(x+w,y+h*0.58)],"cyan",width:0.8)
                bib("rust");c.line([(x+w-3,y+h-1),(x+w,y+h-1)],"yellow",width:1.1)
            case .orientalDollarbird:bib("blue")
            case .blackCappedKingfisher:bib("white");c.line([(x,y+h-1),(x-1,y+h+4)],"white",width:2.5)
            case .bohemianWaxwing:mask();bib("black");c.line([(x+2,y+h*0.63),(x+w,y+h*0.6)],"white",width:0.7)
            case .goldcrest:
                c.line([(x+1,y+1),(x+w-2,y+1)],"black",width:3)
                c.line([(x+1,y),(x+w-2,y)],"yellow",width:2)
                c.line([(x+3,y),(x+w-2,y)],"orange",width:0.9)
            case .eurasianSiskin:c.oval(x,y-1,w,3.5,"black");bib("black")
            case .commonRosefinch:c.oval(x+w*0.3,y+h*0.3,w*0.4,h*0.5,"rust");bib("red")
            case .yellowThroatedBunting:
                c.line([(x+1,y+h*0.2),(x+w-1,y+h*0.2)],"yellow",width:1.6);bib("yellow")
                c.line([(x+w*0.4,y+h+2),(x+w,y+h+3)],"black",width:2)
                c.line([(x+1,y+h*0.7),(x+2,y+h)],"white",width:1)
            case .greyWagtail:
                c.line([(x+1,y+h*0.2),(x+w,y+h*0.2)],"white",width:1);bib("black")
                c.line([(x+1,y+h*0.75),(x+w*0.5,y+h)],"white",width:1)
            case .eurasianJay:
                c.oval(x+1,y,w-2,3,"cream")
                for n in 0..<4 {let xx=x+2+Double(n);c.line([(xx,y),(xx+0.5,y+2)],"umber",width:0.6)}
                c.line([(x+w-2,y+h*0.6),(x+w-3,y+h)],"black",width:1.5)
            case .mandarinDuck:
                c.poly([(x,y+h*0.35),(x+w-1,y+h*0.2),(x+w,y+h*0.45),(x+1,y+h*0.8),(x-2,y+h*0.7)],"white")
                c.line([(x+1,y+h*0.7),(x+2,y+h)],"rust",width:1)
            case .piedAvocet:c.oval(x,y-1,w,h*0.65,"black")
            case .whiteBreastedWaterhen:cheek("white");c.oval(x+w*0.5,y+1,w*0.5,h*0.8,"white");bib("white")
            case .goldenPheasant:c.line([(x+1,y+1),(x+w-1,y+1)],"yellow",width:2)
            case .redCrownedCrane:cheek("black");c.oval(x+1,y,w-2,1.5,"red")
            case .crestedIbis:c.oval(x+w*0.35,y+h*0.2,w*0.7,h*0.75,"red")
            default:break
            }
        }
    }

    static func bill(_ c:BirdPainter,_ id:SpeciesID,_ a:Anatomy,x:Double,y:Double,amount:Double,action:SpeciesBehavior.Action) {
        let open=amount*(action == .call || action == .crack ? 1.8:0)
        if id == .piedAvocet {
            let length=9.5-amount*3
            c.curve([(x,y),(x+length*0.5,y+1),(x+length*0.8,y-1),(min(46,x+length),y-4)],"black",width:0.75)
        } else if id == .crestedIbis {
            c.curve([(x,y),(x+6,y),(min(45,x+8),y+2),(min(46,x+9),y+5)],"black",width:1.1)
            c.line([(min(45,x+8.5),y+4),(min(46,x+9),y+5)],"red",width:0.8)
        } else if id == .blueTailedBeeEater {
            c.curve([(x,y),(x+3,y-0.6),(x+6,y),(min(46,x+7),y+1.4)],"black",width:1)
        } else if id == .redCrossbill {
            c.poly([(x,y-1.7),(x+3,y-1),(x+4,y+1.6),(x+2.5,y+2.5),(x+2.8,y+0.5),(x,y+0.4)],"dark",outline:true)
            c.line([(x,y+1+open),(x+3.5,y+0.6+open),(x+4.4,y-1.2+open)],"gray",width:1.1)
        } else if a.family == "duck" {
            c.poly([(x,y-0.8),(x+5,y-0.3),(x+5,y+1.4),(x,y+1.5)],"red")
            c.line([(x+4.7,y),(x+4.7,y+1)],"cream",width:0.9)
        } else {
            let length:Double = id == .blackCappedKingfisher ? 9 : (id == .redCrownedCrane ? 4.5:(id == .orientalDollarbird ? 4.5:(a.family == "finch" ? 3.8:3.4)))
            let depth:Double = id == .blackCappedKingfisher || id == .orientalDollarbird || a.family == "finch" ? 1.6:0.7
            c.poly([(x,y-depth),(min(46,x+length),y),(x,y+depth)],a.bill,outline:a.family == "finch")
            if open>0 {c.poly([(x,y+0.8),(x+length*0.8,y+open+1),(x,y+open+1.6)],a.bill)}
            if id == .orientalDollarbird || id == .brambling {c.line([(x+length-1,y),(x+length,y)],"black",width:0.8)}
            if id == .whiteBreastedWaterhen {c.oval(x-0.4,y-1,1.5,1.5,"red")}
        }
    }

    static func sail(_ c:BirdPainter,y:Double,amount:Double) {
        let edge=[(17.0,y+7),(13,y-6-amount),(18,y-4),(22,y+5),(20,y+8)]
        c.poly(edge,"orange",outline:true)
        c.within(edge) {
            for i in 0..<5 {let d=Double(i);c.line([(14+d*0.5,y-4+d),(19+d*0.4,y+6)],"buff",width:0.6)}
            c.line([(13,y-5),(17,y-4),(21,y+4)],"cream",width:1)
        }
    }

    static func foldedMarks(_ c:BirdPainter,_ id:SpeciesID,_ y:Double) {
        switch id {
        case .blackNapedOriole:c.line([(17,y+8),(23,y+4)],"yellow",width:1.5)
        case .amurParadiseFlycatcher:
            for n in 0..<4 {let d=Double(n);c.line([(24-d,y+4),(18-d*0.5,y+9)],"slate",width:0.55)}
        case .blueTailedBeeEater:c.line([(18,y+2),(25,y+4)],"olive",width:1.5)
        case .orientalDollarbird:c.line([(19,y+7),(22,y+5)],"cyan",width:1.6)
        case .blackCappedKingfisher:c.oval(19,y+1,8,4,"black");c.line([(18,y+7),(23,y+5)],"blue",width:2)
        case .bohemianWaxwing:
            c.line([(18,y+4),(25,y+5)],"white",width:1)
            c.line([(17,y+8),(20,y+7)],"yellow",width:1.3)
            for i in 0..<3 {let d=Double(i);c.line([(20+d,y+6),(19.5+d,y+7)],"red",width:0.8)}
        case .goldcrest:c.line([(18,y+3),(25,y+4)],"white",width:1);c.line([(17,y+6),(23,y+7)],"white",width:1)
        case .eurasianSiskin:c.line([(18,y+3),(25,y+4)],"yellow",width:1.7);c.line([(17,y+7),(22,y+6)],"yellow",width:1.4)
        case .brambling:c.oval(18,y+1,8,4,"orange");c.line([(18,y+5),(24,y+6)],"white",width:1.2)
        case .commonRosefinch:c.line([(18,y+4),(25,y+5)],"pink",width:0.8)
        case .yellowThroatedBunting:c.line([(18,y+3),(25,y+4)],"buff",width:1);c.line([(17,y+6),(23,y+7)],"cream",width:0.8)
        case .greyWagtail:c.line([(18,y+3),(25,y+4)],"white",width:1.1);c.line([(17,y+6),(23,y+7)],"white",width:0.8)
        case .eurasianJay:
            c.oval(18,y+2,8,5,"cyan")
            for i in 0..<5 {let xx=18+Double(i)*1.6;c.line([(xx,y+2),(xx+1,y+7)],"black",width:0.7)}
            c.line([(17,y+8),(22,y+7)],"white",width:1.3)
        case .mandarinDuck:c.line([(17,y+7),(23,y+5)],"green",width:2);c.line([(17,y+9),(23,y+7)],"white",width:0.8)
        case .piedAvocet:c.line([(18,y+4),(24,y+3)],"white",width:2)
        case .goldenPheasant:c.oval(18,y+1,6,4,"green");c.line([(17,y+7),(23,y+5)],"blue",width:2)
        case .crestedIbis:c.line([(18,y+7),(23,y+5)],"blush",width:2)
        default:break
        }
    }

    static func wing(_ c:BirdPainter,_ id:SpeciesID,_ a:Anatomy,phase:Int,glide:Bool,far:Bool) {
        let broad=["crane","ibis","crow","pheasant"].contains(a.family)
        let pointed=["pointed","kingfisher","duck","wader"].contains(a.family)
        let span:Double=broad ? 23:(pointed ? 21:18)
        let closing=phase == 15 || phase == 16, opening=phase>=18
        let beat=[-0.93,-0.6,0,0.62,0.92,0.6,0,-0.65][phase%8]
        let spread:Double,reach:Double,chord:Double
        if opening {
            let amount=[0.2,0.6,1.0][min(2,phase-18)]
            spread = -3+amount*8; reach=7-amount*15;chord=5+amount
        } else if closing {
            spread=phase == 15 ? 6:-3.5;reach=phase == 15 ? 13:9;chord=(broad ? 9.5:6)*(phase == 15 ? 0.72:0.48)
        } else {
            spread=(far ? -0.65:0.68)*span*(glide ? 1:1-abs(beat)*0.55)
            reach=span*(glide ? (far ? -0.6:0.78):(beat*0.8+(far ? -0.6:0.8)*(1-abs(beat))))
            chord=(broad ? 9.5:(pointed ? 5:6.5))*(far ? 0.7:1)
        }
        func p(_ u:Double,_ v:Double)->(Double,Double) {(27+spread*u-v*chord,24+reach*u+v*1.5+(far ? -1:0))}
        var edge:[(Double,Double)]=[(0,0),(0.35,-0.16),(0.7,-0.1),(1,0.05)]
        if broad {edge += [(0.98,0.25),(0.84,0.22),(0.95,0.46),(0.78,0.4),(0.87,0.68),(0.68,0.6),(0.72,0.87),(0.52,0.74),(0.5,1),(0.25,0.85),(0,0.4)]}
        else {edge += [(pointed ? 0.8:0.94,0.43),(0.65,0.75),(0.4,0.95),(0,0.4)]}
        let primary=id == .crestedIbis ? "blush":a.wing
        let covert=id == .orientalDollarbird ? "teal":a.back
        let base=far ? BirdPlumage.mix(c,primary,"outline",amount:0.20,key:"farBase"):primary
        let light=far ? BirdPlumage.mix(c,covert,"outline",amount:0.18,key:"farCoverts"):covert
        c.poly(edge.map{p($0.0,$0.1)},base,outline:true)
        c.within(edge.map{p($0.0,$0.1)}) {
            c.poly([(0,0),(0.35,-0.1),(0.59,0.02),(0.57,0.35),(0.3,0.5),(0,0.4)].map{p($0.0,$0.1)},light)
            let feather=BirdPlumage.mix(c,base,primary == "white" ? "slate":"silver",amount:0.18,key:"feather")
            for n in 0..<7 {let u=0.27+Double(n)*0.10;c.line([p(u,0.33),p(u+0.06,0.74)],feather,width:Double(c.unit))}
            switch id {
            case .blackNapedOriole:c.line([p(0.22,0.4),p(0.68,0.33)],"yellow",width:1.3)
            case .blueTailedBeeEater:
                c.poly([(0.22,0.4),(0.65,0.15),(0.83,0.3),(0.5,0.8)].map{p($0.0,$0.1)},far ? "rust":"orange")
            case .orientalDollarbird:
                // Elliptical silver-blue dollar patch follows the wing plane.
                c.poly((0..<16).map{n in let t=Double(n)*Double.pi/8;return p(0.70+cos(t)*0.11,0.30+sin(t)*0.16)},"cyan")
            case .blackCappedKingfisher:c.line([p(0.45,0.35),p(0.74,0.29)],"white",width:2.5)
            case .bohemianWaxwing:
                c.line([p(0.52,0.45),p(0.85,0.28)],"yellow",width:1)
                c.line([p(0.25,0.5),p(0.48,0.45)],"white",width:1)
                c.line([p(0.28,0.64),p(0.45,0.59)],"red",width:1.2)
            case .goldcrest,.greyWagtail,.yellowThroatedBunting:
                c.line([p(0.2,0.4),p(0.58,0.32)],"white",width:1)
                c.line([p(0.2,0.6),p(0.5,0.5)],"cream",width:0.8)
            case .eurasianSiskin:c.line([p(0.26,0.45),p(0.74,0.27)],"yellow",width:2)
            case .brambling:c.line([p(0.12,0.25),p(0.5,0.15)],"orange",width:2.3);c.line([p(0.2,0.5),p(0.65,0.35)],"white",width:1)
            case .commonRosefinch:c.line([p(0.2,0.4),p(0.55,0.32)],"pink",width:0.7)
            case .eurasianJay:
                c.poly([(0.15,0.08),(0.52,0.02),(0.5,0.4),(0.12,0.5)].map{p($0.0,$0.1)},"cyan")
                for i in 0..<5 {let u=0.15+Double(i)*0.07;c.line([p(u,0.06),p(u-0.02,0.5)],"black",width:0.6)}
                c.line([p(0.3,0.65),p(0.55,0.5)],"white",width:1.7)
            case .mandarinDuck:c.line([p(0.25,0.5),p(0.55,0.4)],"green",width:2.2);c.line([p(0.25,0.68),p(0.55,0.58)],"white",width:0.8)
            case .piedAvocet:c.poly([(0,0),(0.65,0),(0.6,0.3),(0.25,0.4),(0.45,0.7),(0.2,0.8)].map{p($0.0,$0.1)},"white")
            case .goldenPheasant:c.line([p(0.2,0.35),p(0.58,0.25)],"blue",width:2)
            case .redCrownedCrane:
                c.poly([(0.10,0.42),(0.54,0.25),(0.67,0.64),(0.4,1),(0.12,0.85)].map{p($0.0,$0.1)},"black")
            default:break
            }
        }
    }
}
