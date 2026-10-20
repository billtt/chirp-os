namespace ChirpOS.Core;

// Desktop action schedules. Keep in sync with BirdingCore/SpeciesBehavior.swift.
public static class SpeciesBehavior {
    public readonly record struct Motion(string Action, double Cycle, double Start, double Duration, double Rate, double Hop);
    public static Motion Profile(string id) => id switch {
        "littleOwl" => new("bow", 9.5, 2, 1.8, 3, 0),
        "asianBarredOwlet" => new("scan", 12, 3, 2.2, 2.2, 0),
        "collaredScopsOwl" => new("call", 19, 4, 2.4, 1.6, 0),
        "nightHeron" => new("watch", 53, 20, 2, 1, 0),
        "plumbeousWaterRedstart" => new("tail", 6, 1.5, 1.4, 5, 0),
        "littleEgret" => new("stalk", 19, 4, 2.5, 2, 0),
        "greyHeron" => new("watch", 29, 9, 3, 1, 0),
        "commonKestrel" => new("scan", 13, 3, 2, 2, 0),
        "peregrineFalcon" => new("scan", 21, 6, 2.6, 1, 0),
        "blackKite" => new("scan", 24, 8, 3, 1.2, 0),
        "commonBuzzard" => new("scan", 27, 10, 3.5, 0.8, 0),
        "orientalMagpie" => new("tail", 11, 2, 2, 2, 1),
        "azureWingedMagpie" => new("tail", 8, 1.5, 2, 3, 1.8),
        "largeBilledCrow" => new("bow", 18, 4, 2.4, 1.5, 0),
        "hoopoe" => new("probe", 12, 3, 2.4, 3, 0),
        "barnSwallow" => new("wing", 10, 2, 1.5, 5, 0),
        "mallard" => new("dabble", 22, 5, 3, 1.4, 0),
        "asianKoel" => new("call", 17, 3, 2.8, 2, 0),
        "swinhoesWhiteEye" => new("glean", 6.5, 1, 1.6, 5, 1.5),
        "blackHeadedGull" => new("bow", 16, 4, 2, 2, 0),
        "whimbrel" => new("probe", 15, 4, 2.5, 1.5, 0),
        "piedKingfisher" => new("watch", 14, 3, 2, 3, 0),
        "eurasianWoodcock" => new("rock", 9, 2, 2.8, 3, 0),
        "blackDrongo" => new("tail", 7, 2, 1.6, 4, 0),
        "chinesePondHeron" => new("stalk", 25, 6, 2.6, 1.5, 0),
        "yellowRumpedFlycatcher" => new("wing", 7.5, 1.5, 1.4, 5, 1),
        "yellowBrowedWarbler" => new("glean", 5.5, 1, 1.8, 6, 1.2),
        "greatTit" => new("hammer", 8.5, 2, 2, 5, 1),
        "commonMoorhen" => new("tail", 10.5, 2, 2, 3, 0),
        "greatSpottedWoodpecker" => new("hammer", 12, 4, 1.6, 12, 0),
        "vinousThroatedParrotbill" => new("tail", 6.8, 1, 2, 4, 2),
        "blackWingedStilt" => new("stalk", 18.5, 5, 3, 1.4, 0),
        "eurasianCoot" => new("dabble", 20, 6, 2.5, 1.8, 0),
        "redBilledLeiothrix" => new("glean", 7.8, 2, 1.8, 4, 1.6),
        "blackCollaredStarling" => new("bow", 13.5, 3, 2, 2.4, 0),
        "commonKingfisher" => new("watch", 18, 5, 2, 2, 0),
        "littleRingedPlover" => new("peck", 8, 1, 1.2, 4, 0),
        "yellowBilledGrosbeak" => new("crack", 15.5, 4, 2.5, 3, 0),
        "redFlankedBluetail" => new("tail", 6.2, 1.8, 1.4, 4, 0.8),
        "redWhiskeredBulbul" => new("call", 10, 2, 2.2, 3, 1),
        "treeSparrow" => new("peck", 9, 1, 1, 6, 3),
        "lightVentedBulbul" => new("scan", 11.5, 3, 2, 2.5, 1),
        "spottedDove" => new("bow", 14.5, 2, 2.6, 2, 0),
        "chineseBlackbird" => new("peck", 12.5, 2, 1.8, 3, 0),
        "magpieRobin" => new("tail", 8.8, 1, 2.6, 3.5, 1),
        "longTailedShrike" => new("scan", 16.5, 3, 3, 1.2, 0),
        _ => throw new ArgumentOutOfRangeException(nameof(id), id, "Unknown bird species")
    };
    public static double Hop(string id, double age) {
        var m = Profile(id); var t = Math.Max(0, age) % m.Cycle - m.Start;
        return t > 0 && t < m.Duration ? -m.Hop * Math.Abs(Math.Sin(t / m.Duration * Math.PI * 2)) : 0;
    }
    public static string? Frame(string id, double age, bool side = false) {
        age = Math.Max(0, age);
        if (id == "greatSpottedWoodpecker" && side) { var t = age % 12; return t > 4 && t < 5.6 ? "peck" + ((int)(t * 12) % 2) : "cling0"; }
        if (id == "nightHeron") {
            var t = age % 53;
            if (t > 31 && t < 32) return "poop" + ((int)((t - 31) * 6) % 2);
            if (t > 20 && t < 22) return "stretch";
            if (t > 40 && t < 41) return (int)(t * 8) % 2 == 0 ? "shake" : "stand";
            return t % 7 > 6.8 ? "blink" : "stand";
        }
        var m = Profile(id); var c = age % m.Cycle;
        if (c > m.Start && c < m.Start + m.Duration) {
            int[] poses = [0, 1, 2, 1];
            return "idle" + poses[(int)((c - m.Start) * m.Rate) % 4];
        }
        if (c > m.Cycle - 1.6 && c < m.Cycle - .5) return "preen" + ((int)(c * 3) % 2);
        if (c < .12) return "blink";
        return (int)(age * 1.2) % 2 == 0 ? "stand" : "breathe";
    }
}
