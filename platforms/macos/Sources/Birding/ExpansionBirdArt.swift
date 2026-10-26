import AppKit
import BirdingCore

/// Species-specific proportions and field marks. Shared drawing primitives describe
/// articulated anatomy, not recoloured copies of another species' finished sprite.
enum ExpansionBirdArt {
    struct Anatomy {
        let family, back, wing, head, belly, bill: String
        let width, height, headWidth, headHeight, headY, tailX, tailY: Double
        init(_ family:String,_ colors:[String],_ shape:[Double]) {
            self.family=family; back=colors[0];wing=colors[1];head=colors[2];belly=colors[3];bill=colors[4]
            width=shape[0];height=shape[1];headWidth=shape[2];headHeight=shape[3];headY=shape[4];tailX=shape[5];tailY=shape[6]
        }
    }
    static let profiles: [SpeciesID:Anatomy] = [
        .silkyStarling: Anatomy("starling", ["gray", "dark", "silver", "silver", "red"], [19.0, 11.0, 8.0, 7.0, 15.0, 10.0, 38.0]),
        .crestedMyna: Anatomy("starling", ["black", "black", "black", "black", "cream"], [20.0, 12.0, 9.0, 8.0, 13.0, 9.0, 39.0]),
        .greatCrestedGrebe: Anatomy("grebe", ["brown", "umber", "white", "white", "pink"], [22.0, 9.0, 7.0, 5.0, 9.0, 15.0, 32.0]),
        .daurianRedstart: Anatomy("song", ["rust", "black", "silver", "orange", "dark"], [16.0, 12.0, 8.0, 7.0, 15.0, 7.0, 42.0]),
        .taiwanBarbet: Anatomy("barbet", ["green", "green", "cyan", "green", "dark"], [19.0, 13.0, 12.0, 10.0, 12.0, 13.0, 35.0]),
        .groundTit: Anatomy("ground", ["tan", "brown", "tan", "cream", "dark"], [19.0, 12.0, 8.0, 7.0, 17.0, 7.0, 38.0]),
        .greatEgret: Anatomy("egret", ["white", "white", "white", "white", "yellow"], [17.0, 8.0, 7.0, 4.0, 4.0, 13.0, 27.0]),
        .uplandBuzzard: Anatomy("raptor", ["brown", "umber", "cream", "buff", "dark"], [19.0, 13.0, 9.0, 8.0, 11.0, 8.0, 40.0]),
        .littleGrebe: Anatomy("grebe", ["umber", "brown", "umber", "buff", "dark"], [21.0, 12.0, 8.0, 7.0, 18.0, 15.0, 34.0]),
        .carrionCrow: Anatomy("crow", ["black", "black", "black", "dark", "dark"], [20.0, 12.0, 9.0, 8.0, 12.0, 6.0, 40.0]),
        .plainLaughingthrush: Anatomy("laugh", ["brown", "brown", "gray", "gray", "yellow"], [20.0, 12.0, 8.0, 7.0, 15.0, 5.0, 42.0]),
        .orientalTurtleDove: Anatomy("dove", ["brown", "umber", "gray", "pink", "dark"], [22.0, 12.0, 7.0, 6.0, 14.0, 5.0, 41.0]),
        .easternSpotBilledDuck: Anatomy("duck", ["brown", "umber", "tan", "buff", "dark"], [24.0, 11.0, 9.0, 7.0, 16.0, 9.0, 33.0]),
        .eurasianNuthatch: Anatomy("nuthatch", ["slate", "slate", "gray", "buff", "dark"], [18.0, 10.0, 8.0, 6.0, 17.0, 12.0, 35.0]),
        .rufousBreastedAccentor: Anatomy("ground", ["brown", "umber", "brown", "cream", "dark"], [18.0, 12.0, 8.0, 7.0, 16.0, 9.0, 39.0]),
        .eurasianMagpie: Anatomy("magpie", ["black", "navy", "black", "white", "dark"], [17.0, 11.0, 8.0, 7.0, 14.0, 1.0, 45.0]),
        .eurasianGreatTit: Anatomy("tit", ["green", "slate", "black", "yellow", "dark"], [17.0, 13.0, 9.0, 8.0, 14.0, 8.0, 41.0]),
        .marshTit: Anatomy("tit", ["brown", "brown", "black", "cream", "dark"], [16.0, 13.0, 9.0, 8.0, 15.0, 10.0, 39.0]),
        .ashyDrongo: Anatomy("drongo", ["slate", "slate", "gray", "slate", "dark"], [17.0, 11.0, 8.0, 7.0, 14.0, 2.0, 44.0]),
        .eurasianCollaredDove: Anatomy("dove", ["tan", "gray", "tan", "cream", "dark"], [21.0, 11.0, 7.0, 6.0, 14.0, 5.0, 42.0]),
        .greyTreepie: Anatomy("magpie", ["brown", "black", "slate", "gray", "dark"], [18.0, 11.0, 8.0, 7.0, 15.0, 1.0, 44.0]),
        .whiteCheekedStarling: Anatomy("starling", ["gray", "dark", "black", "gray", "orange"], [19.0, 11.0, 8.0, 7.0, 14.0, 10.0, 38.0]),
        .henricsLaughingthrush: Anatomy("laugh", ["gray", "slate", "brown", "gray", "orange"], [19.0, 12.0, 8.0, 8.0, 15.0, 5.0, 42.0]),
        .indianWhiteEye: Anatomy("whiteeye", ["olive", "green", "olive", "silver", "dark"], [15.0, 11.0, 8.0, 7.0, 16.0, 12.0, 38.0]),
        .easternCattleEgret: Anatomy("egret", ["white", "white", "buff", "white", "yellow"], [18.0, 10.0, 8.0, 6.0, 12.0, 13.0, 31.0]),
        .commonPheasant: Anatomy("pheasant", ["rust", "brown", "green", "rust", "cream"], [16.0, 10.0, 7.0, 7.0, 12.0, 0.5, 46.0]),
        .sootyHeadedBulbul: Anatomy("bulbul", ["brown", "umber", "black", "silver", "dark"], [19.0, 12.0, 8.0, 7.0, 14.0, 6.0, 41.0]),
        .whiteBrowedLaughingthrush: Anatomy("laugh", ["brown", "umber", "brown", "buff", "dark"], [20.0, 12.0, 9.0, 8.0, 14.0, 5.0, 42.0]),
        .whiteWagtail: Anatomy("wagtail", ["gray", "black", "white", "white", "dark"], [17.0, 10.0, 7.0, 6.0, 16.0, 1.0, 43.0]),
        .blueWhistlingThrush: Anatomy("thrush", ["navy", "blue", "navy", "navy", "yellow"], [20.0, 12.0, 9.0, 8.0, 13.0, 6.0, 41.0]),
        .redBilledChough: Anatomy("crow", ["black", "navy", "black", "black", "red"], [19.0, 11.0, 8.0, 7.0, 14.0, 5.0, 40.0]),
        .redBilledBlueMagpie: Anatomy("magpie", ["blue", "blue", "black", "silver", "red"], [14.0, 10.0, 7.0, 6.0, 13.0, 0.5, 46.0]),
        .blackThroatedBushtit: Anatomy("bushtit", ["brown", "brown", "rust", "cream", "dark"], [14.0, 12.0, 9.0, 8.0, 15.0, 5.0, 42.0]),
        .greenBackedTit: Anatomy("tit", ["green", "black", "black", "yellow", "dark"], [16.0, 13.0, 9.0, 8.0, 14.0, 8.0, 41.0]),
        .blueThroatedBarbet: Anatomy("barbet", ["green", "green", "cyan", "green", "dark"], [20.0, 13.0, 12.0, 10.0, 12.0, 13.0, 35.0]),
        .blueFrontedRedstart: Anatomy("song", ["navy", "navy", "blue", "orange", "dark"], [17.0, 12.0, 8.0, 7.0, 15.0, 6.0, 42.0]),
        .greaterCoucal: Anatomy("coucal", ["black", "rust", "black", "black", "dark"], [20.0, 12.0, 9.0, 8.0, 13.0, 2.0, 44.0]),
        .hornedLark: Anatomy("ground", ["tan", "brown", "buff", "cream", "dark"], [18.0, 11.0, 7.0, 6.0, 17.0, 8.0, 39.0]),
        .redThroatedThrush: Anatomy("thrush", ["gray", "brown", "gray", "cream", "dark"], [20.0, 11.0, 8.0, 7.0, 15.0, 7.0, 40.0]),
        .ruddyShelduck: Anatomy("duck", ["orange", "white", "buff", "orange", "dark"], [23.0, 11.0, 8.0, 7.0, 13.0, 8.0, 34.0]),
        .blackRedstart: Anatomy("song", ["black", "black", "gray", "rust", "dark"], [18.0, 13.0, 8.0, 7.0, 14.0, 6.0, 42.0]),
        .daurianJackdaw: Anatomy("crow", ["black", "black", "black", "cream", "dark"], [20.0, 12.0, 9.0, 8.0, 13.0, 7.0, 40.0]),
        .greyCappedGreenfinch: Anatomy("finch", ["brown", "black", "gray", "buff", "pink"], [18.0, 13.0, 9.0, 8.0, 15.0, 9.0, 39.0]),
        .silverThroatedBushtit: Anatomy("bushtit", ["pink", "black", "buff", "pink", "dark"], [14.0, 12.0, 9.0, 8.0, 15.0, 2.0, 44.0]),
        .commonTailorbird: Anatomy("song", ["olive", "green", "rust", "cream", "dark"], [15.0, 11.0, 7.0, 6.0, 16.0, 5.0, 43.0]),
        .collaredFinchbill: Anatomy("bulbul", ["green", "green", "black", "green", "cream"], [19.0, 13.0, 9.0, 8.0, 13.0, 6.0, 41.0]),
        .himalayanVulture: Anatomy("vulture", ["buff", "umber", "cream", "buff", "cream"], [20.0, 13.0, 6.0, 7.0, 10.0, 12.0, 37.0]),
        .twite: Anatomy("finch", ["tan", "brown", "tan", "buff", "yellow"], [17.0, 12.0, 8.0, 7.0, 16.0, 7.0, 41.0]),
        .yellowBilledBlueMagpie: Anatomy("magpie", ["blue", "blue", "black", "silver", "yellow"], [14.0, 10.0, 7.0, 6.0, 13.0, 0.5, 46.0]),
        .ornateSunbird: Anatomy("sunbird", ["olive", "green", "navy", "yellow", "dark"], [14.0, 11.0, 7.0, 6.0, 16.0, 11.0, 38.0]),
        .brownBreastedBulbul: Anatomy("bulbul", ["brown", "umber", "black", "cream", "dark"], [20.0, 12.0, 8.0, 7.0, 14.0, 6.0, 41.0]),
        .whiskeredYuhina: Anatomy("yuhina", ["olive", "brown", "brown", "buff", "dark"], [16.0, 12.0, 8.0, 8.0, 14.0, 9.0, 39.0]),
        .blackTailedGull: Anatomy("gull", ["white", "slate", "white", "white", "yellow"], [22.0, 9.0, 8.0, 6.0, 16.0, 7.0, 34.0]),
        .blackBulbul: Anatomy("bulbul", ["slate", "dark", "slate", "slate", "red"], [19.0, 11.0, 8.0, 7.0, 13.0, 5.0, 42.0]),
    ]
    static func make(_ frame:String,species id:SpeciesID,anatomy original:Anatomy) -> CGImage {
        let inFlight=frame.hasPrefix("fly") || frame.hasPrefix("glide") || frame.hasPrefix("bank") || frame == "bound"
        let headScale=inFlight && ["duck","raptor","vulture","crow","coucal","thrush","barbet"].contains(original.family) ? 0.88:1.0
        let a=Anatomy(original.family,[original.back,original.wing,original.head,original.belly,original.bill],
                      [original.width,original.height,original.headWidth*headScale,original.headHeight*headScale,original.headY,original.tailX,original.tailY])
        let c=BirdPainter(size:max(48,Int((48*SpeciesCatalog.standard.profile(id).relativeScale).rounded())))
        if id == .eurasianNuthatch && (frame.hasPrefix("cling") || frame.hasPrefix("peck")) {
            nuthatch(c,frame); return c.image
        }
        let phase=Int(String(frame.last!)) ?? 0
        let flying=frame.hasPrefix("fly") || frame.hasPrefix("glide") || frame.hasPrefix("bank") || frame == "bound"
        let landing=frame.hasPrefix("land"), folded=BirdPlumage.folded(frame), glide=frame.hasPrefix("glide") || frame.hasPrefix("bank")
        let active=frame.hasPrefix("idle"), amount=active ? [0.2,0.6,1.0][min(2,phase)]:0
        let action=SpeciesBehavior.motion(id).action
        let aquatic=["grebe","duck","gull"].contains(a.family), egret=a.family == "egret"
        let birdOfPrey=["raptor","vulture"].contains(a.family)
        let bob=frame == "breathe" ? -0.6:0.0
        let by=flying ? 22.0 : (egret ? (id == .greatEgret ? 19.0:22.0):(aquatic ? 25.0:22.0))+bob
        let flightDepth:Double = birdOfPrey ? 0.58 : (aquatic ? 0.55 : (["crow","coucal","dove","thrush"].contains(a.family) ? 0.57:0.62))
        let bh=flying ? a.height*flightDepth:a.height
        let bw=flying ? a.width*(birdOfPrey ? 0.78:(aquatic ? 0.90:0.94)):a.width
        let bodyX=34-bw
        var hx=flying ? min(33.0,41-a.headWidth):37-a.headWidth, hy=flying ? 18.0:a.headY+bob
        if active {
            switch action {
            case .peck,.hammer: hx+=amount*2;hy+=amount*7
            case .probe: hx+=amount*2;hy+=amount*(a.family == "sunbird" ? -4:8)
            case .tail:hy-=amount*1.3
            case .bow: hx+=amount*2;hy+=amount*4
            case .glean:hx+=amount*2;hy-=amount*3
            case .call:hy-=amount*2.8
            case .dabble:hx+=amount*2;hy+=amount*9
            case .stalk:hx+=amount*3;hy+=amount*3
            case .scan:hx-=amount*2;hy-=amount
            default:hy+=amount*2
            }
        }
        if frame.hasPrefix("preen") || (active && a.family == "grebe") {hx=23-amount*2;hy=25+Double(phase)*0.6}
        if flying {
            c.ctx.saveGState();c.ctx.translateBy(x:27,y:24)
            let angle=frame.hasPrefix("bank") ? Double(phase-1)*0.12 : (glide ? -0.04:[0.03,0,-0.03,-0.04,0,0.03,0.04,0.02][phase%8])
            c.ctx.rotate(by:angle);c.ctx.translateBy(x:-27,y:-24)
            wing(c,id,a,phase,glide,true)
        }
        // Short-tailed divers and large soaring birds do not share a passerine tail.
        let shortTail=["duck","gull","raptor","vulture"].contains(a.family)
        var tx=flying ? (shortTail ? max(a.tailX,bodyX-(birdOfPrey ? 4:3)):max(2,a.tailX-2)):max(1.5,a.tailX)
        var ty=flying ? by+bh*0.54:min(a.family == "drongo" ? 42.8:44.5,a.tailY)
        if active && action == .tail {ty-=amount*(id == .commonTailorbird ? 19:11);tx+=amount*2}
        let tailColor:[SpeciesID:String]=[.daurianRedstart:"rust",.blueFrontedRedstart:"rust",.blackRedstart:"rust",.greyTreepie:"gray",.ruddyShelduck:"black",.greaterCoucal:"black",.blackTailedGull:"white"]
        let tail=tailColor[id] ?? a.wing
        if flying {
            let fork=a.family == "drongo" ? 4.5:0.0
            if a.family != "grebe" {
                BirdPlumage.flightTail(c,root:bodyX+5,tip:tx,y:ty,width:birdOfPrey ? 3.5:2.8,fill:tail,light:a.back,fork:fork)
                if [.redBilledBlueMagpie,.yellowBilledBlueMagpie,.blackTailedGull,.eurasianCollaredDove,.whiteWagtail].contains(id) {
                    c.pigment {c.line([(tx+0.7,ty-1),(tx+0.7,ty+1)],id == .blackTailedGull ? "black":"white",width:1)}
                }
            }
        }
        else if a.family == "grebe" { c.oval(34-a.width-1,by+bh*0.3,6,bh*0.55,a.back) }
        else if a.family == "drongo" || id == .twite || id == .greyCappedGreenfinch || id == .blackBulbul {
            c.poly([(23,26),(tx,ty-5),(tx+(id == .blackBulbul ? 2:6),ty),(tx,ty+4),(25,31)],tail,outline:true)
        } else {
            let longTail=["magpie","pheasant","bushtit","coucal","wagtail"].contains(a.family)
            c.poly([(24,27),(tx,ty-1),(tx+1.5,ty+2),(tx+(longTail ? 5:7),ty+1),(27,31)],tail,outline:true)
            c.pigment {
            for i in 0..<3 {c.line([(24+Double(i),28),(tx+1+Double(i)*1.3,ty+0.5)],a.back)}
            if [.redBilledBlueMagpie,.yellowBilledBlueMagpie,.greyTreepie,.blackTailedGull].contains(id) {
                c.line([(tx+1,ty),(tx+5,ty)],"black",width:3)
                if id != .greyTreepie {c.line([(tx+1,ty+1.5),(tx+5,ty+1)],"white",width:1)}
            }
            if [.whiteWagtail,.silverThroatedBushtit,.eurasianCollaredDove,.crestedMyna,.sootyHeadedBulbul].contains(id) {c.line([(tx,ty),(tx+4,ty+1)],"white",width:1.5)}
            if id == .commonPheasant { for n in 0..<7 {let t=Double(n)/8;c.line([(tx+(24-tx)*t,ty+(27-ty)*t),(tx+3+(24-tx)*t,ty+1+(27-ty)*t)],"black",width:0.7)} }
            }
        }
        let legs:[SpeciesID:String]=[.redBilledChough:"red",.redBilledBlueMagpie:"red",.yellowBilledBlueMagpie:"red",.blackBulbul:"red",.henricsLaughingthrush:"yellow",.whiteCheekedStarling:"orange",.crestedMyna:"yellow",.blackTailedGull:"yellow",.easternSpotBilledDuck:"orange",.ruddyShelduck:"dark"]
        let leg=legs[id] ?? (a.family == "vulture" ? "gray":(birdOfPrey ? "yellow":"brown"))
        if !flying {
            let top=egret ? by+bh-1:(by+bh-2)
            for (i,x) in [27.0,31.0].enumerated() {
                let lift=active && action == .stalk && i == 0 ? amount*4:0
                let rear=a.family == "grebe" ? -4.0:0.0
                c.line([(x+rear,top),(x-0.8+rear,35-lift),(x+rear,39-lift)],egret ? "dark":leg,width:egret ? 0.7:1)
                if a.family == "duck" {c.poly([(x+rear,36-lift),(x+3+rear,39-lift),(x-2+rear,39-lift)],leg)}
                else {c.line([(x-2+rear,39-lift),(x+rear,38.5-lift),(x+2+rear,39-lift)],leg,width:0.7)}
            }
        }
        BirdPlumage.torso(c,x:bodyX,y:by,w:bw,h:bh,back:a.back,belly:a.belly,flying:flying)
        // Flexible necks: egrets retract in flight, grebes extend their necks.
        if egret {
            if flying {c.curve([(29,26),(39,30),(33,22),(hx+3,hy+3)],"white",width:3)}
            else {c.curve([(29,by+5),(38,by+3),(27,hy+5),(hx+3,hy+3)],id == .easternCattleEgret ? "buff":"white",width:id == .greatEgret ? 2.6:4)}
        } else if a.family == "grebe" || a.family == "duck" {
            if flying && a.family == "grebe" {hx=37;hy=20}
            c.curve([(29,by+4),(35,by+2),(29,hy+5),(hx+3,hy+4)],a.belly,width:a.family == "duck" ? 5:3)
        } else if a.family == "vulture" {
            c.curve([(29,by+4),(34,19),(29,hy+5),(hx+3,hy+4)],"cream",width:2.7)
            c.oval(25,by-2,9,4,"white")
        } else {c.poly([(25,by+2),(hx+2,hy+4),(hx+a.headWidth-1,hy+5),(33,by+7)],a.belly)}
        if folded {
            BirdPlumage.foldedWing(c,y:by,height:bh,fill:id == .ruddyShelduck ? "black":a.wing,
                                  coverts:id == .greaterCoucal ? "rust":a.back) {
                wingMark(c,id,by)
            }
        }
        c.oval(hx,hy,a.headWidth,a.headHeight,a.head,outline:true)
        marks(c,id,a,hx,hy,by,flying,folded,tx,ty)
        let bx=hx+a.headWidth-0.5, yy=hy+a.headHeight*0.55
        if a.family == "sunbird" || id == .redBilledChough || id == .groundTit || id == .plainLaughingthrush {
            c.curve([(bx,yy),(bx+3,yy),(min(47,bx+6),yy+2),(min(47,bx+6),yy+4)],a.bill,width:id == .redBilledChough ? 1.1:0.8)
        } else if birdOfPrey || a.family == "coucal" {
            c.poly([(bx,yy-1),(bx+3,yy),(bx+3,yy+2),(bx+1.5,yy+3),(bx+2,yy+1.2),(bx,yy+1)],a.bill)
        } else if a.family == "finch" || id == .collaredFinchbill || a.family == "barbet" {
            c.poly([(bx,yy-1.6),(min(47,bx+(a.family == "barbet" ? 6:4)),yy+0.3),(bx,yy+2)],a.bill,outline:true)
        } else if a.family == "duck" {
            c.poly([(bx,yy-1),(bx+5,yy-0.5),(bx+5.5,yy+1),(bx+4,yy+1.8),(bx,yy+1.5)],a.bill)
            if id == .easternSpotBilledDuck {c.poly([(bx+3.5,yy-0.5),(bx+5,yy-0.5),(bx+5.5,yy+1),(bx+3.5,yy+1.5)],"yellow")}
        } else {
            let length=egret ? 8.0:(["grebe","crow","nuthatch","gull"].contains(a.family) ? 5.0:3.0)
            c.poly([(bx,yy-0.7),(min(47,bx+length),yy+0.4),(bx,yy+1.2)],a.bill)
            if id == .blackTailedGull {c.line([(bx+3,yy),(bx+4.5,yy+0.3)],"black",width:1.2);c.line([(bx+4.5,yy),(bx+5.5,yy+0.3)],"red",width:1)}
            if id == .silkyStarling || id == .whiteCheekedStarling {c.line([(bx+2,yy),(bx+3,yy+0.3)],"black")}
        }
        if active && (action == .call || action == .crack) {c.poly([(bx,yy+1),(bx+3,yy+2+amount*2),(bx,yy+2+amount*2)],a.bill)}
        let ex=hx+a.headWidth*0.7, ey=hy+a.headHeight*0.38
        if id == .indianWhiteEye || id == .whiskeredYuhina {c.oval(ex-1,ey-1,2.8,2.8,"white")}
        if [.ashyDrongo,.greaterCoucal,.greatCrestedGrebe].contains(id) {c.oval(ex-0.7,ey-0.7,2.3,2.3,"red")}
        if id == .crestedMyna || id == .blackTailedGull {c.oval(ex-0.6,ey-0.6,2.2,2.2,"yellow")}
        if frame == "blink" {c.line([(ex-0.4,ey+0.5),(ex+1.2,ey+0.5)],"eye")}
        else {c.oval(ex,ey,1,1,"eye");c.oval(ex+0.4,ey,0.4,0.4,"white")}
        if flying {
            BirdPlumage.flightFeet(c,family:a.family,x:bodyX+bw*0.32,y:by+bh*0.88,color:egret ? "dark":leg)
        }
        if flying || (landing && !folded) {wing(c,id,a,landing ? 15+phase:phase,glide,false)}
        if flying {c.ctx.restoreGState()}
        return c.image
    }
    static func wing(_ c:BirdPainter,_ id:SpeciesID,_ a:Anatomy,_ phase:Int,_ glide:Bool,_ far:Bool) {
        let broad=["vulture","raptor","crow","egret"].contains(a.family)
        let pointed=["duck","gull","starling","grebe"].contains(a.family)
        let span=a.family == "vulture" ? 25.0:(broad ? 23:(pointed ? 21:18))
        let closing=phase >= 15
        let beat=[-0.93,-0.6,0,0.62,0.92,0.6,0,-0.65][phase%8]
        let spread=closing ? (phase == 15 ? 6.0 : -3.5) : (far ? -0.65:0.68)*span*(glide ? 1:1-abs(beat)*0.55)
        let reach=closing ? (phase == 15 ? 13.0 : 9.0) : span*(glide ? (far ? -0.6:0.78):(beat*0.8+(far ? -0.6:0.8)*(1-abs(beat))))
        let chord=(broad ? 9.5:(pointed ? 5.0:6.5))*(far ? 0.7:1)*(closing ? (phase == 15 ? 0.72:0.48):1)
        func p(_ u:Double,_ v:Double)->(Double,Double) {(27+spread*u-v*chord,24+reach*u+v*1.5+(far ? -1:0))}
        var pts:[(Double,Double)]=[(0,0),(0.35,-0.16),(0.7,-0.1),(1,0.05)]
        if broad {pts += [(0.98,0.25),(0.84,0.22),(0.95,0.46),(0.78,0.4),(0.87,0.68),(0.68,0.6),(0.72,0.87),(0.52,0.74),(0.5,1),(0.25,0.85),(0,0.4)]}
        else {pts += [(pointed ? 0.8:0.94,0.43),(0.65,0.75),(0.4,0.95),(0,0.4)]}
        let primary=id == .ruddyShelduck || a.family == "vulture" ? "black":a.wing
        let wingBase=far ? BirdPlumage.mix(c,primary,"outline",amount:0.22,key:"farBase"):primary
        let covert=id == .ruddyShelduck ? "white" : (id == .greaterCoucal ? "rust":a.back)
        let wingLight=far ? BirdPlumage.mix(c,covert,"outline",amount:0.18,key:"farCoverts"):covert
        c.poly(pts.map{p($0.0,$0.1)},wingBase,outline:true)
        c.within(pts.map{p($0.0,$0.1)}) {
        c.poly([(0,0),(0.35,-0.1),(0.59,0.02),(0.57,0.35),(0.3,0.5),(0,0.4)].map{p($0.0,$0.1)},wingLight)
        let feather=BirdPlumage.mix(c,wingBase,primary == covert ? (primary == "white" ? "slate":"silver"):wingLight,amount:primary == covert ? 0.18:0.38,key:"primaryEdge")
        for n in 0..<7 {let u=0.27+Double(n)*0.10;c.line([p(u,0.33),p(u+0.06,0.74)],feather,width:Double(c.unit))}
        let white:[SpeciesID]=[.crestedMyna,.daurianRedstart,.eurasianGreatTit,.greenBackedTit,.eurasianMagpie,.greyTreepie,.whiteWagtail,.ruddyShelduck,.silkyStarling,.whiteCheekedStarling]
        if white.contains(id) {c.line([p(0.22,0.4),p(0.55,0.34),p(0.72,0.23)],"white",width:id == .crestedMyna ? 2.7:1.3)}
        if id == .greenBackedTit {c.line([p(0.25,0.22),p(0.6,0.16)],"white",width:0.8)}
        if id == .greyCappedGreenfinch {c.line([p(0.55,0.35),p(0.85,0.28)],"yellow",width:2)}
        if id == .easternSpotBilledDuck {c.line([p(0.3,0.6),p(0.58,0.52)],"navy",width:2.4);c.line([p(0.3,0.73),p(0.58,0.65)],"white",width:0.7)}
        if id == .ruddyShelduck {c.line([p(0.3,0.6),p(0.58,0.52)],"green",width:2)}
        if id == .uplandBuzzard {c.oval(25+spread*0.65-chord*0.3,23+reach*0.65,3,3,"umber")}
        if id == .blackTailedGull {c.line([p(0.88,0.1),p(0.9,0.3)],"black",width:2);c.line([p(0.95,0.15),p(0.94,0.3)],"white",width:0.8)}
        }
    }
    static func wingMark(_ c:BirdPainter,_ id:SpeciesID,_ y:Double) {
        switch id {
        case .daurianRedstart,.greyTreepie,.crestedMyna:c.poly([(20,y+3),(25,y+3),(25,y+6),(20,y+7)],"white")
        case .eurasianGreatTit,.whiteWagtail,.silkyStarling:c.line([(18,y+4),(25,y+5)],"white",width:1.3)
        case .greenBackedTit:c.line([(18,y+3),(25,y+4)],"white",width:1);c.line([(17,y+6),(23,y+7)],"white",width:1)
        case .greyCappedGreenfinch:c.line([(19,y+5),(16,y+10)],"yellow",width:2)
        case .easternSpotBilledDuck:c.poly([(18,y+6),(24,y+5),(22,y+8),(17,y+9)],"navy");c.line([(17,y+9),(22,y+8)],"white")
        case .ruddyShelduck:c.line([(17,y+8),(23,y+6)],"green",width:2)
        case .orientalTurtleDove,.commonPheasant:
            for i in 0..<9 {let x=17+Double(i%3)*2.5,yy=y+2+Double(i/3)*2.5;c.line([(x,yy),(x+1,yy+1.5),(x+2,yy)],"tan",width:0.8)}
        case .henricsLaughingthrush:c.line([(17,y+8),(23,y+4)],"slate",width:1)
        case .twite:c.line([(18,y+4),(25,y+5)],"buff",width:1)
        default:break
        }
    }
    // Head-first bark probing: the toes stay on the window edge at x=29,
    // with no woodpecker-style supporting tail or upright hammering pose.
    static func nuthatch(_ c:BirdPainter,_ frame:String) {
        let reach=frame == "peck1" ? 2.5:0.0
        c.poly([(19,24),(17,12),(21,15),(24,25)],"slate",outline:true)
        c.oval(13,19,13,15,"slate",outline:true)
        c.oval(22,24,5,10,"buff")
        c.poly([(15,20),(20,20),(22,29),(18,32),(14,28)],"slate",outline:true)
        c.curve([(22,28),(23,31),(22+reach,33),(23+reach,34)],"buff",width:3)
        c.oval(20+reach,31,8,6,"gray",outline:true)
        c.poly([(21+reach,34),(28+reach,33),(28+reach,35),(21+reach,36)],"black")
        c.poly([(27+reach,34),(34+reach,37),(27+reach,36)],"dark")
        c.oval(25+reach,33,1,1,"eye")
        c.line([(23,25),(26,28),(29,28),(28,29)],"brown",width:0.8)
        c.line([(23,30),(26,38),(29,38),(29,39)],"brown",width:0.8)
    }
    static func marks(_ c:BirdPainter,_ id:SpeciesID,_ a:Anatomy,_ x:Double,_ y:Double,_ by:Double,_ flying:Bool,_ folded:Bool,_ tx:Double,_ ty:Double) {
        let w=a.headWidth,h=a.headHeight
        func cheek(_ color:String) {c.poly([(x+1,y+h*0.5),(x+w-1,y+h*0.45),(x+w-1,y+h*0.83),(x+2,y+h)],color)}
        func mask(_ color:String="black") {c.poly([(x,y+h*0.25),(x+w,y+h*0.32),(x+w,y+h*0.58),(x+1,y+h*0.65)],color)}
        func bib(_ color:String) {c.poly([(x+w*0.5,y+h*0.75),(x+w,y+h*0.65),(33,by+6),(29,by+7)],color)}
        func crown(_ color:String) {c.poly([(x,y+2),(x+2,y),(x+w-2,y),(x+w,y+2)],color)}
        func crest(_ color:String,_ size:Double=4) {c.poly([(x,y+3),(x+1,y-size),(x+3,y-1),(x+5,y-size*0.3),(x+6,y+2)],color)}
        func chest(_ color:String) {c.line([(29,by+4),(33,by+5)],color,width:2)}
        func vent(_ color:String) {c.oval(20,by+(flying ? 4:8),5,flying ? 1.8:3,color)}
        func streaks(_ color:String) {for i in 0..<6 {let xx=27+Double(i%3)*2,yy=by+2+Double(i/3)*(flying ? 1.4:3);c.line([(xx,yy),(xx+0.6,yy+1.8)],color,width:0.65)}}
        switch id {
        case .crestedMyna: c.poly([(x+w-4,y+2),(x+w-3,y-4),(x+w-1,y-3),(x+w,y+2)],"black")
        case .greatCrestedGrebe: c.poly([(x,y+2),(x-2,y-4),(x+1,y-1),(x+4,y-4),(x+5,y+2)],"black")
            c.poly([(x-2,y+4),(x+2,y+3),(x+w,y+4),(x+3,y+10),(x-2,y+8)],"rust")
            c.line([(x-2,y+5),(x-2,y+8),(x+2,y+10)],"black",width:1.3)
        case .sootyHeadedBulbul: crest("black",2)
        case .whiskeredYuhina: crest("brown",5)
        case .blackBulbul: crest("slate",4)
        case .hornedLark: c.poly([(x+1,y+2),(x,y-3),(x+3,y)],"black");c.poly([(x+4,y+1),(x+5,y-2),(x+6,y+2)],"black")
        default: break
        }
        c.pigment {
        switch id {
        case .silkyStarling:
            c.line([(x+1,y+2),(x+4,y+1)],"white");c.line([(29,by+3),(30,by+7)],"silver")
        case .crestedMyna: break
        case .greatCrestedGrebe:
            cheek("white")
        case .daurianRedstart:
            cheek("black");bib("black");c.line([(tx+2,ty),(22,29)],"black",width:1)
        case .taiwanBarbet:
            crown("yellow");mask();c.oval(x+w-2,y+2,2,2,"red");bib("yellow");chest("red")
        case .groundTit:
            c.poly([(x+w-4,y),(x+w-1,y+1),(x+w-1,y+3),(x+w-4,y+2)],"cream");cheek("buff")
            c.line([(x+1,y+3),(x+w,y+3)],"brown",width:0.7)
        case .greatEgret:
            c.line([(x+w-3,y+2),(x+w,y+2)],"yellow",width:0.8)
        case .uplandBuzzard:
            cheek("cream");streaks("brown");c.line([(26,33),(27,36)],"buff",width:2);c.line([(30,33),(31,36)],"buff",width:2)
            c.line([(tx+1,ty),(tx+5,ty)],"umber",width:1.3)
        case .littleGrebe:
            cheek("rust");bib("rust");c.oval(x+w-1.5,y+h*0.55,2,1.5,"yellow")
        case .carrionCrow:
            c.line([(x,y+3),(x+4,y+1.5)],"slate",width:0.6)
        case .plainLaughingthrush:
            c.line([(x+1,y+2),(x+w-1,y+1.5)],"silver",width:0.7)
            c.poly([(x+w-2,y+h-1),(x+w,y+h-1),(x+w-1,y+h+1)],"dark")
        case .orientalTurtleDove:
            c.poly([(x,y+h-1),(x+3,y+h-2),(x+4,y+h+3),(x+1,y+h+4)],"black")
            for i in 0..<3 {c.line([(x+0.5+Double(i),y+h),(x+1.5+Double(i),y+h+3)],"white",width:0.6)}
        case .easternSpotBilledDuck:
            mask("umber");c.line([(x+1,y+1.5),(x+w-1,y+1.5)],"cream",width:1);cheek("buff");streaks("brown")
        case .eurasianNuthatch:
            mask();c.line([(x,y+3),(x-4,y+6)],"black",width:1);c.line([(29,by+7),(31,by+10)],"rust",width:1)
        case .rufousBreastedAccentor:
            c.line([(x,y+1.5),(x+w-4,y+1)],"buff",width:1)
            c.line([(x+w-4,y+1),(x+w-1,y+1)],"white",width:0.8)
            chest("rust");streaks("umber");c.line([(17,by+2),(20,by+5)],"umber")
        case .eurasianMagpie:
            if folded {c.oval(18,by+1,7,4,"white")};c.line([(tx+2,ty),(19,30)],"green",width:0.7)
        case .eurasianGreatTit,.greenBackedTit:
            cheek("white");bib("black");c.line([(32,by+4),(31,by+(flying ? 7:12))],"black",width:id == .eurasianGreatTit ? 1.5:1.1)
        case .marshTit:
            cheek("cream");c.poly([(x+w-3,y+h-1),(x+w,y+h-2),(x+w-1,y+h+1),(x+w-2,y+h+1)],"black")
        case .ashyDrongo:
            c.line([(x+1,y+1),(x+4,y)],"silver",width:0.6)
        case .eurasianCollaredDove:
            c.curve([(x-1,y+h-1),(x-2,y+h+3),(x+2,y+h+3),(x+2,y+h+1)],"black",width:1)
        case .greyTreepie:
            mask();bib("dark");if folded {c.oval(15,by+2,5,4,"brown")}
        case .whiteCheekedStarling:
            cheek("white");c.oval(14,by+5,5,3,"white")
        case .henricsLaughingthrush:
            cheek("rust");c.line([(x,y+2),(x+w-1,y+1.5)],"white",width:0.7)
            c.line([(x+1,y+h-1),(x+w-2,y+h-1)],"white",width:1)
            bib("gray");vent("rust");c.line([(tx,ty),(tx+5,ty)],"white",width:1)
        case .indianWhiteEye:
            bib("yellow");vent("yellow");c.line([(31,by+6),(30,by+10)],"yellow",width:0.8);c.line([(x+w-2,y+3),(x+w,y+3)],"dark",width:0.7)
        case .easternCattleEgret:
            c.oval(22,by+1,8,4,"buff");c.line([(x,y+1),(x+3,y)],"orange",width:0.7)
        case .commonPheasant:
            mask("red");c.line([(x,y+h),(x+w-1,y+h+1)],"white",width:1.5)
            for i in 0..<6 {let xx=27+Double(i%2)*3,yy=by+3+Double(i/2)*2.5;c.line([(xx,yy),(xx+1.5,yy+1),(xx+3,yy)],"black",width:0.7)}
        case .sootyHeadedBulbul:
            cheek("silver");bib("white");vent("red")
        case .whiteBrowedLaughingthrush:
            mask("umber");cheek("cream");c.line([(x,y+2),(x+w-1,y+1.5)],"cream",width:1);vent("rust")
        case .whiteWagtail:
            crown("black");bib("black");c.line([(x+w-2,y+3),(x+w,y+3)],"black",width:0.7)
        case .blueWhistlingThrush:
            for i in 0..<12 {let xx=27+Double(i%4)*1.5,yy=by+2+Double(i/4)*2;c.oval(xx,yy,0.7,0.8,"cyan")}
            c.line([(x+1,y+1),(x+5,y+1)],"blue",width:1)
        case .redBilledChough:
            c.line([(x+1,y+2),(x+4,y+1)],"navy",width:1)
        case .redBilledBlueMagpie,.yellowBilledBlueMagpie:
            c.poly([(x,y+1),(x+2,y+1),(x+2,y+5),(x,y+7),(x-1,y+5)],"white")
            c.line([(tx+1,ty-0.5),(tx+5,ty)],"black",width:2)
            c.line([(tx+1,ty+1.5),(tx+5,ty+1.5)],"white",width:1)
        case .blackThroatedBushtit:
            mask();cheek("white");bib("black");chest("rust")
        case .blueThroatedBarbet:
            crown("red");c.oval(x+3,y,3,1.5,"navy");bib("cyan");c.oval(30,by+2,2,2,"red")
        case .blueFrontedRedstart:
            bib("navy");c.line([(x+2,y+1),(x+w-1,y+1)],"cyan",width:0.8);c.line([(tx+2,ty),(23,28)],"black",width:1);c.line([(tx,ty),(tx+5,ty+1)],"black",width:1.5)
        case .greaterCoucal:
            c.line([(x+2,y+2),(x+5,y+1)],"navy",width:0.7)
        case .hornedLark:

            mask();bib("buff");chest("black")
        case .redThroatedThrush:
            bib("rust");chest("rust");c.line([(tx,ty),(21,29)],"rust",width:1.5)
        case .ruddyShelduck:
            // Follow the actual bent neck, not the width of the head. A cross
            // section near its upper end stays attached while dabbling/preening.
            let t=0.72, u=1-t
            let p0=(29.0,by+4), p1=(35.0,by+2), p2=(29.0,y+5), p3=(x+3,y+4)
            let cx=u*u*u*p0.0+3*u*u*t*p1.0+3*u*t*t*p2.0+t*t*t*p3.0
            let cy=u*u*u*p0.1+3*u*u*t*p1.1+3*u*t*t*p2.1+t*t*t*p3.1
            let dx=3*u*u*(p1.0-p0.0)+6*u*t*(p2.0-p1.0)+3*t*t*(p3.0-p2.0)
            let dy=3*u*u*(p1.1-p0.1)+6*u*t*(p2.1-p1.1)+3*t*t*(p3.1-p2.1)
            let length=max(0.001,hypot(dx,dy)), nx = -dy/length, ny=dx/length
            c.curve([(cx-nx*2,cy-ny*2),(cx-nx,cy-ny+0.6),
                     (cx+nx,cy+ny+0.6),(cx+nx*2,cy+ny*2)],"black",width:0.65)
        case .blackRedstart:
            cheek("black");bib("black");c.line([(tx+2,ty),(23,29)],"black",width:0.7)
        case .daurianJackdaw:
            c.poly([(x,y+h-2),(x+2,y+h-1),(x+1,y+h+5),(x-3,y+h+3)],"cream")
        case .greyCappedGreenfinch:
            c.line([(tx,ty),(19,29)],"yellow",width:1.2);cheek("tan");vent("yellow")
        case .silverThroatedBushtit:
            c.line([(x,y+2),(x+2,y),(x+5,y+0.5)],"black",width:1.3);cheek("silver");bib("silver")
        case .commonTailorbird:
            cheek("cream");bib("cream");c.line([(x+2,y+1),(x+5,y+1)],"orange",width:0.8)
        case .collaredFinchbill:
            c.line([(x,y+h-1),(x+2,y+h+2),(x+w-1,y+h+1)],"white",width:1.5);c.line([(tx,ty),(tx+5,ty+1)],"black",width:2)
        case .himalayanVulture:
            c.line([(x+1,y+2),(x+3,y+1)],"tan",width:0.7);c.oval(25,by-1,9,3,"cream")
            for i in 0..<4 {c.line([(27+Double(i)*1.5,by+3),(27+Double(i)*1.5,by+7)],"tan",width:0.7)}
        case .twite:
            streaks("umber");c.oval(14,by+5,5,3,"pink");cheek("buff")
        case .ornateSunbird:
            bib("navy");c.line([(x+w-3,y+h-1),(31,by+4)],"blue",width:0.8)
        case .brownBreastedBulbul:
            cheek("brown");bib("white");chest("brown");vent("yellow");c.oval(x+w-0.5,y+h*0.65,0.7,0.7,"red")
        case .whiskeredYuhina:
            cheek("cream");c.line([(x+w-3,y+4),(x+3,y+h+1)],"black",width:1)
            c.line([(x,y+h),(x-1,y+h+4),(x+2,y+h+4)],"buff",width:1.5)
        case .blackTailedGull:
            c.line([(x+1,y+1),(x+4,y+1)],"silver",width:0.6)
        case .blackBulbul:
            c.line([(x+1,y+3),(x+3,y+2)],"gray",width:0.6)
        default: preconditionFailure("Every expansion species needs field marks")
        }
        }
    }
}
