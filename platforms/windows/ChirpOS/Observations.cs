using System.Drawing.Imaging;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed partial class Desktop {
    internal LifeList LifeList=new();
    bool lifeListAvailable=true, observationIntroductionPending, observationIntroductionVisible;
    int feedbackWidth=140;
    readonly ObservationVisits<Bird> observationVisits=new();
    readonly Overlay cameraTarget=new(true), observationFeedback=new();
    double feedbackStarted=-10;
    string feedbackText="";
    bool feedbackNew;
    Point feedbackPoint;
    static string LifeListPath=>Path.Combine(Program.DataFolder,"life-list.json");
    internal Species EffectiveProfile(Species species)=>LifeList.Enabled?species:Settings.Resolve(species);
    void LoadLifeList() {
        try {
            var loaded=LifeList.Load(LifeListPath);
            var introduce=loaded.PrepareIntroduction();
            if(introduce)loaded.Save(LifeListPath);
            LifeList=loaded;observationIntroductionPending=introduce;
        }
        catch(Exception error){lifeListAvailable=false;Error(error);}
        cameraTarget.Photograph=Photograph;
        cameraTarget.CanPhotograph=()=>CanPhotograph(HitBird());
    }
    void ShowObservationIntroduction() {
        if(!observationIntroductionPending)return;
        observationIntroductionPending=false;
        observationIntroductionVisible=true;
        try { MessageBox.Show(T("将鼠标移到小鸟身上，点击取景框即可记录。首次发现的鸟种会加入 Life List（鸟种记录）。\n\n观鸟模式下鸟种设置不生效。你可以随时在菜单中关闭“观鸟模式”，恢复自己的设置，已有记录会保留。", "Hover over a bird and click the viewfinder to record it. Newly discovered species join your Life List.\n\nCustom bird settings do not apply in birdwatching mode. Turn it off anytime in the menu to restore your settings. Your observations will be kept."), T("欢迎进入观鸟模式", "Welcome to birdwatching mode"),MessageBoxButtons.OK,MessageBoxIcon.Information); }
        finally { observationIntroductionVisible=false; }
    }
    void ToggleObservations() {
        if(!lifeListAvailable)return;
        var next=LifeList.Copy();next.Enabled=!next.Enabled;
        try{next.Save(LifeListPath);}catch(Exception e){Error(e);return;}
        LifeList=next;observationVisits.Reset();cameraTarget.Hide();observationFeedback.Hide();feedbackStarted=-10;
        if(next.Enabled){foreach(var (bird,_) in flock)Depart(bird);}
        BuildMenu();settingsWindow?.RefreshMode();
    }
    bool CanPhotograph(Bird? bird) => LifeList.Enabled && !observationIntroductionVisible && bird!=null && observationVisits.Contains(bird)
        && !menu.Visible && !Application.OpenForms.Cast<Form>().Any(f=>f is not Overlay && f.Visible && f.Bounds.Contains(Cursor.Position));
    void UpdateCamera(Bird? bird,double now) {
        if(cameraTarget.Capture) return; // Keep the complete click away from the app underneath.
        if(CanPhotograph(bird) && Control.MouseButtons==MouseButtons.None) {
            var p=Cursor.Position;
            using var bitmap=new Bitmap(28,28,PixelFormat.Format32bppPArgb);
            using(var g=Graphics.FromImage(bitmap)) {
                // A nearly transparent interior receives the click; corners form the viewfinder.
                g.Clear(Color.FromArgb(1,0,0,0));
                foreach(var (x,y,dx,dy) in new[]{(3,3,1,1),(24,3,-1,1),(3,24,1,-1),(24,24,-1,-1)}) {
                    using var shadow=new Pen(Color.Black,3);using var light=new Pen(Color.White,1);
                    var points=new[]{new Point(x+dx*6,y),new Point(x,y),new Point(x,y+dy*6)};
                    g.DrawLines(shadow,points);g.DrawLines(light,points);
                }
            }
            cameraTarget.RenderBitmap(bitmap,p.X-14,p.Y-14);
        }else cameraTarget.Hide();
        var age=now-feedbackStarted;
        if(age>=1.2 || !LifeList.Enabled){observationFeedback.Hide();return;}
        using var feedback=new Bitmap(feedbackWidth,110,PixelFormat.Format32bppPArgb);
        using(var g=Graphics.FromImage(feedback)) {
            var alpha=(int)(255*Math.Clamp((1.2-age)*3,0,1));
            using var background=new SolidBrush(Color.FromArgb((int)(alpha*.8),25,27,31));
            using var measureFont=new Font("Segoe UI",10);
            var textWidth=Math.Min(feedbackWidth-8,(int)Math.Ceiling(g.MeasureString(feedbackText,measureFont).Width)+20);
            var textX=(feedbackWidth-textWidth)/2;
            g.FillRectangle(background,textX,48-(float)age*16,textWidth,27);
            using var font=new Font("Segoe UI",10);using var ink=new SolidBrush(Color.FromArgb(alpha,Color.White));
            using var format=new StringFormat{Alignment=StringAlignment.Center};
            g.DrawString(feedbackText,font,ink,new RectangleF(textX+4,52-(float)age*16,textWidth-8,25),format);
            if(age<.2){using var flash=new Pen(Color.FromArgb((int)(255*(1-age/.2)),Color.White),2);g.DrawRectangle(flash,feedbackWidth/2-14,76,28,28);}
            if(feedbackNew)for(var i=0;i<16;i++) {
                var colors=new[]{Color.HotPink,Color.Gold,Color.Turquoise,Color.CornflowerBlue,Color.Orange};
                using var confetti=new SolidBrush(Color.FromArgb(alpha,colors[i%colors.Length]));
                var radius=12+age*42;g.FillRectangle(confetti,feedbackWidth/2+(float)(Math.Cos(i*2.4)*radius),65+(float)(Math.Sin(i*2.4)*radius-age*12),4,3);
            }
        }
        observationFeedback.RenderBitmap(feedback,feedbackPoint.X,feedbackPoint.Y);
    }
    void Photograph() {
        var bird=HitBird();if(!CanPhotograph(bird))return;
        feedbackNew=false;
        if(observationVisits.WasRecorded(bird!))feedbackText=Name(bird!.Species);
        else {
            var next=LifeList.Copy();feedbackNew=next.Record(bird!.Species.Id);
            try{next.Save(LifeListPath);}catch(Exception e){cameraTarget.Hide();Error(e);return;}
            LifeList=next;observationVisits.Commit(bird);
            feedbackText=Name(bird.Species)+(feedbackNew?T(" 加新！", " New!"):" +1");
        }
        var p=Cursor.Position;var screen=Screen.FromPoint(p).WorkingArea;
        using(var measure=new Bitmap(1,1))using(var graphics=Graphics.FromImage(measure))using(var font=new Font("Segoe UI",10)) {
            feedbackWidth=Math.Min(screen.Width,Math.Max(140,(int)Math.Ceiling(graphics.MeasureString(feedbackText,font).Width)+28));
        }
        feedbackPoint=new(Math.Clamp(p.X-feedbackWidth/2,screen.Left,Math.Max(screen.Left,screen.Right-feedbackWidth)),Math.Clamp(p.Y-90,screen.Top,Math.Max(screen.Top,screen.Bottom-110)));
        feedbackStarted=clock.Elapsed.TotalSeconds;
    }
}
