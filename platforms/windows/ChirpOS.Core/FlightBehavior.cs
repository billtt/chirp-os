namespace ChirpOS.Core;

public static class FlightBehavior {
    public record Motion(string Style, double Transit, double Cycle, double Powered, double Rate, double Wave, double Orbit, double Period);
    public static Motion Profile(string id) => id switch {
        "redWhiskeredBulbul" => new("bounding", 2.4, 1.2, 0.72, 1.6, 10, 0, 0),
        "treeSparrow" => new("bounding", 1.8, 0.8, 0.80, 1.6, 7, 0, 0),
        "lightVentedBulbul" => new("bounding", 2.6, 1.3, 0.74, 1.7, 11, 0, 0),
        "spottedDove" => new("direct", 3.0, 3.0, 0.86, 2.0, 0, 0, 0),
        "chineseBlackbird" => new("bounding", 2.5, 1.5, 0.80, 1.7, 8, 0, 0),
        "magpieRobin" => new("bounding", 2.2, 1.0, 0.78, 1.6, 9, 0, 0),
        "longTailedShrike" => new("bounding", 2.8, 1.8, 0.72, 1.6, 12, 0, 0),
        "nightHeron" => new("steady", 5.8, 5.0, 0.88, 1.5, 0, 0, 0),
        "plumbeousWaterRedstart" => new("bounding", 2.1, 0.9, 0.82, 1.6, 8, 0, 0),
        "littleEgret" => new("steady", 5.4, 4.5, 0.90, 1.6, 0, 0, 0),
        "greyHeron" => new("steady", 7.0, 6.0, 0.90, 1.4, 0, 0, 0),
        "commonKestrel" => new("raptor", 4.0, 5.0, 0.40, 1.7, 0, 18, 9),
        "peregrineFalcon" => new("raptor", 3.6, 6.0, 0.30, 1.6, 0, 20, 10),
        "blackKite" => new("raptor", 5.0, 10.0, 0.16, 1.6, 0, 36, 12),
        "commonBuzzard" => new("raptor", 5.8, 12.0, 0.14, 1.5, 0, 42, 14),
        "orientalMagpie" => new("bounding", 3.6, 2.0, 0.82, 1.5, 14, 0, 0),
        "azureWingedMagpie" => new("bounding", 3.1, 1.6, 0.78, 1.6, 12, 0, 0),
        "largeBilledCrow" => new("direct", 4.3, 4.5, 0.70, 1.5, 0, 0, 0),
        "hoopoe" => new("bounding", 3.0, 1.8, 0.65, 1.5, 20, 0, 0),
        "barnSwallow" => new("aerial", 7.0, 2.8, 0.50, 1.6, 25, 0, 0),
        "mallard" => new("direct", 3.4, 4.0, 1.0, 2.2, 0, 0, 0),
        "asianKoel" => new("direct", 3.7, 3.0, 0.78, 1.5, 0, 0, 0),
        "swinhoesWhiteEye" => new("bounding", 1.9, 0.7, 0.82, 1.7, 6, 0, 0),
        "blackHeadedGull" => new("soaring", 6.0, 7.0, 0.30, 1.5, 0, 16, 8),
        "whimbrel" => new("steady", 4.6, 4.0, 0.92, 1.8, 0, 0, 0),
        "piedKingfisher" => new("direct", 3.0, 2.5, 0.90, 1.8, 0, 0, 0),
        "eurasianWoodcock" => new("direct", 2.8, 2.0, 0.94, 1.8, 0, 0, 0),
        "blackDrongo" => new("aerial", 4.5, 2.2, 0.58, 1.6, 18, 0, 0),
        "chinesePondHeron" => new("steady", 4.8, 4.0, 0.92, 1.6, 0, 0, 0),
        "yellowRumpedFlycatcher" => new("bounding", 2.0, 0.9, 0.80, 1.7, 10, 0, 0),
        "yellowBrowedWarbler" => new("bounding", 1.7, 0.7, 0.84, 1.8, 6, 0, 0),
        "greatTit" => new("bounding", 2.0, 0.8, 0.78, 1.8, 9, 0, 0),
        "commonMoorhen" => new("direct", 3.8, 3.0, 1.0, 1.8, 0, 0, 0),
        "greatSpottedWoodpecker" => new("bounding", 3.5, 1.6, 0.55, 1.6, 22, 0, 0),
        "vinousThroatedParrotbill" => new("bounding", 2.1, 0.9, 0.82, 1.7, 9, 0, 0),
        "blackWingedStilt" => new("steady", 4.5, 3.5, 0.94, 1.7, 0, 0, 0),
        "eurasianCoot" => new("direct", 4.0, 3.0, 1.0, 2.0, 0, 0, 0),
        "redBilledLeiothrix" => new("bounding", 2.2, 1.0, 0.80, 1.7, 8, 0, 0),
        "blackCollaredStarling" => new("direct", 2.8, 2.5, 0.90, 1.9, 0, 0, 0),
        "commonKingfisher" => new("direct", 2.0, 2.0, 1.0, 1.875, 0, 0, 0),
        "littleRingedPlover" => new("direct", 2.4, 2.2, 0.95, 1.9, 0, 0, 0),
        "yellowBilledGrosbeak" => new("bounding", 2.7, 1.3, 0.75, 1.7, 12, 0, 0),
        "redFlankedBluetail" => new("bounding", 2.0, 0.9, 0.80, 1.7, 8, 0, 0),
        "collaredScopsOwl" => new("owl", 4.6, 4.0, 0.55, 1.7, 0, 0, 0),
        "asianBarredOwlet" => new("owl", 4.0, 3.5, 0.62, 1.8, 0, 0, 0),
        "littleOwl" => new("owl", 3.5, 2.8, 0.68, 1.8, 6, 0, 0),
        _ => throw new ArgumentOutOfRangeException(nameof(id), id, "Choose an explicit flight profile for each new species")
    };
    public static string Frame(string id, double age, double fps, bool powered=false, double banking=0) {
        var m=Profile(id); var rate=Math.Max(4,fps); var t=Math.Max(0,age)%m.Cycle;
        var burst=Math.Max(8/rate,Math.Round(m.Cycle*m.Powered*rate/8,MidpointRounding.AwayFromZero)*8/rate);
        if(powered || m.Powered>=1 || t<burst)return "fly"+(((int)((powered?Math.Max(0,age):t)*rate)+3)%8);
        if(m.Style=="bounding")return "bound";
        if(Math.Abs(banking)>.3)return "bank"+(banking<0?0:2);
        return "glide1";
    }
    public static double Smooth(double t) {var u=Math.Clamp(t,0,1);return u*u*(3-2*u);}
}
