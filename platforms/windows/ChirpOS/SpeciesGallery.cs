using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Text.Json;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed class SpeciesGallery:Form {
    readonly System.Windows.Forms.Timer timer=new(){Interval=33};
    readonly Dictionary<string,Bitmap> art=[];
    readonly Dictionary<string,double> standTops=[];
    readonly Dictionary<string,int> frames;
    DateTime started=DateTime.UtcNow;
    GalleryAction action=GalleryAction.Resting;
    public SpeciesGallery(Desktop desktop) {
        AutoScaleDimensions=new SizeF(96,96);AutoScaleMode=AutoScaleMode.Dpi;
        Text=desktop.LifeList.Enabled ? desktop.T("Life List（鸟种记录）", "Life List") : desktop.T("图鉴","Field guide");ClientSize=new(900,690);MinimumSize=new(920,400);BackColor=Color.FromArgb(238,238,238);
        using(var stream=Program.Resource("art/manifest.json")){using var doc=JsonDocument.Parse(stream);frames=doc.RootElement.GetProperty("frames").EnumerateArray().Select((v,i)=>(v.GetString()!,i)).ToDictionary(x=>x.Item1,x=>x.i);}
        var scroll=new Panel{Dock=DockStyle.Fill,AutoScroll=true,BackColor=Color.FromArgb(238,238,238)};Controls.Add(scroll);
        var grid=new Panel{Location=new(0,0),BackColor=Color.FromArgb(238,238,238),Margin=Padding.Empty};scroll.Controls.Add(grid);
        var actions=new FlowLayoutPanel{Dock=DockStyle.Top,Height=52,Padding=new Padding(12,10,0,0),BackColor=Color.FromArgb(238,238,238)};Controls.Add(actions);
        var labels=new[]{desktop.T("休息","Rest"),desktop.T("飞行","Flight"),desktop.T("振翅","Flapping"),desktop.T("滑翔","Gliding"),desktop.T("着陆","Landing"),desktop.T("理羽","Preening"),desktop.T("其他","Other")};
        foreach(var value in Enum.GetValues<GalleryAction>()) {
            var button=new RadioButton{Text=labels[(int)value],Appearance=Appearance.Button,AutoSize=true,Checked=value==GalleryAction.Resting,TextAlign=ContentAlignment.MiddleCenter};
            button.CheckedChanged+=(_,_)=>{if(button.Checked){action=value;started=DateTime.UtcNow;foreach(Control cell in grid.Controls)cell.Invalidate();}};
            actions.Controls.Add(button);
        }
        double dpi=1,maxScale=1,previewScale=1,topTrim=0;int cellHeight=220;
        bool layoutDirty=true,layingOut=false;
        void LayoutBirds() {
            if(layingOut)return;
            layingOut=true;
            try {
                dpi=DeviceDpi/96d;
                var layout=GalleryLayout.Calculate(Math.Max(4,scroll.ClientSize.Width),desktop.Species.Length,dpi,
                    desktop.Species.Max(s=>desktop.EffectiveProfile(s).Scale)*desktop.Settings.Scale);
                previewScale=layout.PreviewScale;maxScale=layout.MaxScale;
                topTrim=desktop.LifeList.Enabled ? desktop.Species.Min(s=>{
                    var scale=desktop.EffectiveProfile(s).Scale*desktop.Settings.Scale*dpi*previewScale;
                    return 39*maxScale-39*scale+standTops.GetValueOrDefault(s.Id)*scale;
                }):0;
                var height=layout.CellHeight-(int)Math.Floor(topTrim);
                layout=layout with{CellHeight=height,Height=((desktop.Species.Length+3)/4)*height};
                if(!layoutDirty && grid.Width==layout.Width && cellHeight==layout.CellHeight && grid.Height==layout.Height)return;
                layoutDirty=false;cellHeight=layout.CellHeight;grid.SuspendLayout();
                grid.SetBounds(0,scroll.AutoScrollPosition.Y,layout.Width,layout.Height);
                for(var i=0;i<grid.Controls.Count;i++) {
                    var bounds=layout.Cell(i);
                    grid.Controls[i].SetBounds(bounds.X,bounds.Y,bounds.Width,bounds.Height);
                }
                grid.ResumeLayout();
            } finally {layingOut=false;}
        }
        scroll.ClientSizeChanged+=(_,_)=>LayoutBirds();
        foreach(var species in desktop.Species) {
            using var stream=Program.Resource("art/"+species.Id+".png");using var image=Image.FromStream(stream);art[species.Id]=new Bitmap(image);
            var bitmap=art[species.Id];var tile=bitmap.Height;var first=tile;
            for(var y=0;y<tile && first==tile;y++)for(var x=0;x<tile;x++)if(bitmap.GetPixel(frames["stand"]*tile+x,y).A>0){first=y;break;}
            standTops[species.Id]=first*48d/tile;
            var cell=new GalleryCell{Width=220,Height=220,Margin=Padding.Empty,BackColor=Color.FromArgb(238,238,238),Tag=species};grid.Controls.Add(cell);
            cell.Paint+=(_,e)=>{
                var record=desktop.LifeList.Enabled ? desktop.LifeList.Records.GetValueOrDefault(species.Id) : null;
                var hidden=desktop.LifeList.Enabled && record is null;
                var profile=desktop.EffectiveProfile(species);
                var scale=desktop.Settings.Scale*profile.Scale*dpi*previewScale;
                var side=Math.Max(1,(int)Math.Ceiling(48*scale));
                var top=8*dpi+39*maxScale-topTrim-39*scale;
                var labelY=(int)Math.Ceiling(48*maxScale-topTrim+8*dpi);
                var cellWidth=cell.Width;
                int Px(int value)=>(int)Math.Round(value*dpi);
                var pose=desktop.LifeList.Enabled?"stand":GalleryPose.Frame(species.Id,(DateTime.UtcNow-started).TotalSeconds,profile.FlapFPS,action,profile.Speed);
                e.Graphics.InterpolationMode=InterpolationMode.NearestNeighbor;e.Graphics.PixelOffsetMode=PixelOffsetMode.Half;
                using var attributes=new ImageAttributes();
                if(hidden) attributes.SetColorMatrix(new ColorMatrix(new float[][]{[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,1,0],[.25f,.25f,.25f,0,1]}));
                var atlas=art[species.Id];
                e.Graphics.DrawImage(atlas,new Rectangle((cellWidth-side)/2,(int)Math.Round(top),side,side),frames[pose]*atlas.Height,0,atlas.Height,atlas.Height,GraphicsUnit.Pixel,attributes);
                TextRenderer.DrawText(e.Graphics,hidden?desktop.T("未记录", "Unrecorded"):desktop.Name(species),Font,new Rectangle(Px(5),labelY,cellWidth-Px(10),Px(32)),Color.Black,TextFormatFlags.HorizontalCenter|TextFormatFlags.WordBreak);
                if(record is not null) {
                    var badge=$"x{record.Count}";
                    var badgeSize=TextRenderer.MeasureText(e.Graphics,badge,Font);
                    var badgeX=Math.Min(cellWidth-badgeSize.Width-Px(5),(cellWidth+side)/2+Px(3));
                    var badgeY=(int)Math.Round(top)+side-badgeSize.Height;
                    TextRenderer.DrawText(e.Graphics,badge,Font,new Point(badgeX,badgeY),Color.DimGray);
                }
                var detail=record is not null ? record.FirstRecordedAt.ToLocalTime().ToString("yyyy/MM/dd") : hidden?"":ActionName(pose,desktop);
                TextRenderer.DrawText(e.Graphics,detail,Font,new Rectangle(Px(5),labelY+Px(32),cellWidth-Px(10),Px(24)),Color.DimGray,TextFormatFlags.HorizontalCenter|TextFormatFlags.WordBreak);

            };
        }
        LifeList? previousList=null;bool? previousEnglish=null;
        void RefreshRecords() {
            if(ReferenceEquals(previousList,desktop.LifeList) && previousEnglish==desktop.Settings.English)return;
            previousList=desktop.LifeList;previousEnglish=desktop.Settings.English;
            actions.Visible=!desktop.LifeList.Enabled;
            var translated=new[]{desktop.T("休息","Rest"),desktop.T("飞行","Flight"),desktop.T("振翅","Flapping"),desktop.T("滑翔","Gliding"),desktop.T("着陆","Landing"),desktop.T("理羽","Preening"),desktop.T("其他","Other")};
            for(var i=0;i<actions.Controls.Count;i++)actions.Controls[i].Text=translated[i];
            var count=desktop.Species.Count(s=>desktop.LifeList.Records.ContainsKey(s.Id));
            Text=desktop.LifeList.Enabled ? desktop.T($"Life List（鸟种记录）· {count} / {desktop.Species.Length} 种",$"Life List · {count} / {desktop.Species.Length} species") : desktop.T("图鉴", "Field guide");
            grid.SuspendLayout();
            var cells=grid.Controls.Cast<Control>().ToArray();
            var ordered=desktop.LifeList.Enabled ? cells.OrderByDescending(c=>desktop.LifeList.Records.GetValueOrDefault(((Species)c.Tag!).Id)?.FirstRecordedAt ?? DateTimeOffset.MinValue).ThenBy(c=>((Species)c.Tag!).Id,StringComparer.Ordinal).ToArray() : cells.OrderBy(c=>Array.IndexOf(desktop.Species,(Species)c.Tag!)).ToArray();
            for(var i=0;i<ordered.Length;i++){var cell=ordered[i];grid.Controls.SetChildIndex(cell,i);cell.Visible=true;}
            grid.ResumeLayout();layoutDirty=true;
        }
        RefreshRecords();LayoutBirds();
        timer.Tick+=(_,_)=>{RefreshRecords();LayoutBirds();foreach(Control cell in grid.Controls)if(cell.Bounds.IntersectsWith(new Rectangle(0,-scroll.AutoScrollPosition.Y,grid.Width,scroll.ClientSize.Height)))cell.Invalidate();};timer.Start();
    }
    static string ActionName(string pose,Desktop d)=>pose.StartsWith("bank")?d.T("盘旋展翼","Banking"):pose.StartsWith("glide")?d.T("展开翅膀滑翔","Gliding"):pose=="bound"?d.T("收翅起伏飞行","Bounding"):pose.StartsWith("idle")?d.T("习性动作","Characteristic action"):pose.StartsWith("fly")?d.T("振翅飞行","Flapping flight"):pose.StartsWith("land")?d.T("着陆","Landing"):pose.StartsWith("preen")?d.T("理羽","Preening"):pose.StartsWith("peck")?d.T("啄击","Pecking"):pose.StartsWith("cling")?d.T("侧边停靠","Clinging"):pose.StartsWith("poop")?d.T("挤洗手液","Dropping"):pose=="stretch"?d.T("伸颈","Stretching"):pose=="shake"?d.T("抖毛","Shaking"):d.T("休息与张望","Resting & watching");
    protected override void Dispose(bool disposing){if(disposing){timer.Dispose();foreach(var image in art.Values)image.Dispose();}base.Dispose(disposing);}
    sealed class GalleryCell:Panel {public GalleryCell(){DoubleBuffered=true;}}
}
