using ChirpOS.Core;
namespace ChirpOS;

internal sealed class SettingsWindow : Form
{
    readonly Desktop desktop;
    readonly Preferences draft;
    readonly List<TrackBar> sliders = [];
    readonly List<NumericUpDown> values = [];
    readonly List<CheckBox> locks = [];
    readonly List<NumericUpDown[]> details = [];
    readonly Label total = new();
    readonly TabControl tabs = new() { Dock = DockStyle.Fill };
    bool refreshing;

    public SettingsWindow(Desktop d)
    {
        desktop = d; draft = d.Clone();
        Text = d.T("啾啾 · 鸟种设置", "ChirpOS · Bird settings");
        AutoScaleDimensions = new SizeF(96,96); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new(920, 610); MinimumSize = new(760, 540); StartPosition = FormStartPosition.CenterScreen;
        using (var stream = Program.Resource("AppIcon.ico")) Icon = new Icon(stream);
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new(16), ColumnCount = 1, RowCount = 4 };
        layout.RowStyles.Add(new(SizeType.AutoSize)); layout.RowStyles.Add(new(SizeType.Percent, 100));
        layout.RowStyles.Add(new(SizeType.AutoSize)); layout.RowStyles.Add(new(SizeType.AutoSize)); Controls.Add(layout);
        var header=new TableLayoutPanel{Dock=DockStyle.Fill,AutoSize=true,ColumnCount=2};
        header.ColumnStyles.Add(new(SizeType.Percent,100));header.ColumnStyles.Add(new(SizeType.Absolute,40));
        layout.Controls.Add(header);
        var unlock=new Label{Dock=DockStyle.Fill,MinimumSize=new(40,40)};
        long? lastDoubleClick=null;
        unlock.MouseDoubleClick+=(_,e)=>{
            if(e.Button!=MouseButtons.Left || tabs.TabPages.Count>2)return;
            var now=Environment.TickCount64;
            if(lastDoubleClick is {} previous && now-previous<=3000)EnableDebug();
            lastDoubleClick=now;
        };
        header.Controls.Add(unlock,1,0);
        header.Controls.Add(new Label { AutoSize = true, MaximumSize = new(850, 0), Text = d.T(
            "设置保存后，新飞入的小鸟将使用这些参数。调整概率时，其他未锁定鸟种按比例变化，合计始终为 100%。",
            "Saved settings apply to new arrivals. Probability changes redistribute the remainder among unlocked species; the total stays at 100%.") },0,0);
        layout.Controls.Add(tabs);
        var probabilities = new TabPage(d.T("出现概率", "Probabilities")) { Padding = new(8) };
        var behavior = new TabPage(d.T("体型与动作", "Size & behavior")) { Padding = new(8) };
        tabs.TabPages.AddRange([probabilities, behavior]);
        var table = new TableLayoutPanel { Dock = DockStyle.Fill, AutoScroll = true, ColumnCount = 4, RowCount = d.Species.Length };
        table.ColumnStyles.Add(new(SizeType.Percent, 32)); table.ColumnStyles.Add(new(SizeType.Percent, 43));
        table.ColumnStyles.Add(new(SizeType.Absolute, 110)); table.ColumnStyles.Add(new(SizeType.Absolute, 80)); probabilities.Controls.Add(table);
        for (var i = 0; i < d.Species.Length; i++)
        {
            var index = i; table.RowStyles.Add(new(SizeType.Absolute, 49));
            table.Controls.Add(new Label { Text = d.Name(d.Species[i]), AutoSize = true, Anchor = AnchorStyles.Left }, 0, i);
            var slider = new TrackBar { Minimum = 0, Maximum = 10000, TickStyle = TickStyle.None, SmallChange = 10, LargeChange = 100, Dock = DockStyle.Fill };
            sliders.Add(slider); table.Controls.Add(slider, 1, i);
            var number = Number(0,100,0,2,.1m); values.Add(number); table.Controls.Add(number, 2, i);
            var locked = new CheckBox { Text = d.T("锁定", "Lock"), AutoSize = true, Anchor = AnchorStyles.Left };
            locks.Add(locked); table.Controls.Add(locked, 3, i);
            slider.ValueChanged += (_, _) => { if (!refreshing) { draft.Probability.Adjust(index, slider.Value); RefreshRows(); } };
            number.ValueChanged += (_, _) => { if (!refreshing) { draft.Probability.Adjust(index, (int)Math.Round(number.Value * 100)); RefreshRows(); } };
            locked.CheckedChanged += (_, _) => { if (!refreshing) { draft.Probability.Locked[index] = locked.Checked; RefreshRows(); } };
        }
        var detailLayout = new TableLayoutPanel { Dock=DockStyle.Fill,ColumnCount=1,RowCount=2 };
        detailLayout.RowStyles.Add(new(SizeType.AutoSize)); detailLayout.RowStyles.Add(new(SizeType.Percent,100)); behavior.Controls.Add(detailLayout);
        detailLayout.Controls.Add(new Label { AutoSize=true,MaximumSize=new(820,0),Text=d.T(
            "体长 8–110 cm · 振翅 0.5–7.5 次/秒 · 飞速 0.5–2×\n最短停留 2–300 秒 · 最长停留不超过 600 秒，且不能小于最短停留。",
            "Length 8–110 cm · Beats 0.5–7.5/sec · Speed 0.5–2×\nMinimum perch 2–300 sec · Maximum up to 600 sec, and no shorter than minimum.") });
        var detailTable = new TableLayoutPanel { Dock=DockStyle.Fill,AutoScroll=true,ColumnCount=6,RowCount=d.Species.Length+1 };
        detailTable.ColumnStyles.Add(new(SizeType.Percent,100));
        for(var j=0;j<5;j++) detailTable.ColumnStyles.Add(new(SizeType.Absolute,110));
        detailTable.RowStyles.Add(new(SizeType.Absolute,48));
        var headers=new[]{d.T("鸟种","Species"),d.T("体长 cm","Length cm"),d.T("振翅 次/秒","Beats / sec"),d.T("飞速 倍率","Speed ×"),d.T("最短停留 秒","Min perch s"),d.T("最长停留 秒","Max perch s")};
        for(var j=0;j<headers.Length;j++)detailTable.Controls.Add(new Label{Text=headers[j],AutoSize=true,Anchor=AnchorStyles.Left},j,0);
        for(var i=0;i<d.Species.Length;i++)
        {
            detailTable.RowStyles.Add(new(SizeType.Absolute,44));
            detailTable.Controls.Add(new Label{Text=d.Name(d.Species[i]),AutoSize=true,Anchor=AnchorStyles.Left},0,i+1);
            var s=draft.Resolve(d.Species[i]);
            var row=new[]{Number(8,110,(decimal)s.AdultLengthCM,2,.1m),Number(.5m,7.5m,(decimal)s.FlapFPS/8,3,.125m),Number(.5m,2,(decimal)s.Speed,2,.05m),Number(2,300,(decimal)s.PerchMin,1,1),Number(2,600,(decimal)s.PerchMax,1,1)};
            details.Add(row);for(var j=0;j<row.Length;j++)detailTable.Controls.Add(row[j],j+1,i+1);
        }
        detailLayout.Controls.Add(detailTable);
        var options = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, WrapContents = true }; layout.Controls.Add(options);
        total.AutoSize = true; total.Margin = new(3, 8, 20, 3); options.Controls.Add(total);
        options.Controls.Add(new Label { Text = d.T("鸟群范围", "Population"), AutoSize = true, Margin = new(3, 8, 3, 3) });
        var min = Number(1,50,draft.Minimum,0,1); var max = Number(1,50,draft.Maximum,0,1); min.Width=max.Width=60;
        options.Controls.Add(min); options.Controls.Add(new Label { Text = "–", AutoSize = true }); options.Controls.Add(max);
        options.Controls.Add(new Label { Text = d.T("大小", "Size"), AutoSize = true, Margin = new(16, 8, 3, 3) });
        var scale = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 66 }; scale.Items.AddRange(["1×", "1.5×"]); scale.SelectedIndex = draft.Scale == 1 ? 0 : 1; options.Controls.Add(scale);
        var buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Dock = DockStyle.Fill }; layout.Controls.Add(buttons);
        var save = new Button { Text = d.T("保存并应用", "Save & Apply"), AutoSize = true };
        save.Click += (_, _) => {
            ValidateChildren();
            draft.Minimum=(int)min.Value; draft.Maximum=(int)max.Value; draft.Scale=scale.SelectedIndex==0?1:1.5;
            if(draft.Minimum>draft.Maximum){MessageBox.Show(d.T("最小数量不能大于最大数量。","Minimum must not exceed maximum."));return;}
            for(var i=0;i<details.Count;i++){
                var r=details[i];var b=new Behavior((double)r[0].Value,(double)r[1].Value*8,(double)r[2].Value,(double)r[3].Value,(double)r[4].Value);
                if(!b.Valid){tabs.SelectedIndex=1;r[4].Focus();MessageBox.Show(d.Name(d.Species[i])+d.T("：最长停留不能小于最短停留。",": Maximum perch time must not be below minimum."));return;}
                draft.Behaviors[d.Species[i].Id]=b;
            }
            draft.PendingSpeciesIds=[];if(d.Apply(draft))Close();
        }; buttons.Controls.Add(save);
        var cancel=new Button{Text=d.T("取消","Cancel"),AutoSize=true};cancel.Click+=(_,_)=>Close();buttons.Controls.Add(cancel);
        var reset=new Button{Text=d.T("恢复本页默认值","Reset this tab"),AutoSize=true};
        reset.Click+=(_,_)=>{
            if(tabs.SelectedIndex==0){draft.Probability=Probabilities.From(d.Species);RefreshRows();}
            else if(tabs.SelectedIndex==1) for(var i=0;i<details.Count;i++){var s=d.Species[i];var v=new[]{s.AdultLengthCM,s.FlapFPS/8,s.Speed,s.PerchMin,s.PerchMax};for(var j=0;j<5;j++)details[i][j].Value=(decimal)v[j];}
        };buttons.Controls.Add(reset);AcceptButton=save;CancelButton=cancel;RefreshRows();
    }
    void EnableDebug() {
        var page=new TabPage(desktop.T("调试","Debug")){Padding=new(20)};
        var content=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};
        content.Controls.Add(new Label{AutoSize=true,MaximumSize=new(650,0),Text=desktop.T(
            "更新提示预览\n\n模拟更新会显示通知和图标红点。点击通知或菜单中的安装更新可查看确认框；选择安装后结束模拟，选择晚点再说则保留提示。不会下载、安装或重启。",
            "Update notification preview\n\nSimulate a ready update with a notification and icon badge. Click the notification or install menu item to review it. Confirm to end the simulation, or choose Later to keep the prompt. No download, installation or restart occurs.")});
        var simulate=new Button{Text=desktop.T("模拟有更新","Simulate update"),AutoSize=true,Margin=new(3,20,3,3)};
        var status=new Label{AutoSize=true,MaximumSize=new(650,0)};
        simulate.Click+=(_,_)=>status.Text=desktop.SimulateUpdate()?desktop.T("已显示模拟更新，可点击通知或菜单查看。","Simulated update ready; click the notification or menu to review."):desktop.T("更新器正在忙碌，请稍后重试。","The updater is busy; try again shortly.");
        content.Controls.Add(simulate);content.Controls.Add(status);page.Controls.Add(content);tabs.TabPages.Add(page);
    }
    internal void ScrollToSpecies(string id) {
        var i=Array.FindIndex(desktop.Species,s=>s.Id==id);if(i<0)return;
        tabs.SelectedIndex=0;
        if(values[i].Parent is ScrollableControl sc)sc.ScrollControlIntoView(values[i]);
        values[i].Focus();
    }
    static NumericUpDown Number(decimal min,decimal max,decimal value,int decimals,decimal increment)=>new(){Minimum=min,Maximum=max,Value=value,DecimalPlaces=decimals,Increment=increment,Width=100,Anchor=AnchorStyles.Left,ThousandsSeparator=false};
    void RefreshRows()
    {
        refreshing=true;
        for(var i=0;i<sliders.Count;i++){sliders[i].Value=draft.Probability.Points[i];values[i].Value=draft.Probability.Points[i]/100m;locks[i].Checked=draft.Probability.Locked[i];sliders[i].Enabled=values[i].Enabled=draft.Probability.CanAdjust(i);}
        total.Text=desktop.T("合计：","Total: ")+(draft.Probability.Points.Sum()/100m).ToString("F2")+"%";refreshing=false;
    }
}
