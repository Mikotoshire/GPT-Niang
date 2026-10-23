using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Media;

// AI-generated maintenance; insufficiently validated. See AI-NOTICE.md.
// One active write and one replaceable pending snapshot; no UI callbacks/runspace.
public sealed class GptLatestFileWriter {
    readonly object gate = new object();
    readonly Action<string> write;
    string pending, error;
    bool running, closed;
    long writes, failures;
    public int PendingCount { get { lock (gate) return pending == null ? 0 : 1; } }
    public string LastError { get { lock (gate) return error; } }
    public long Writes { get { lock (gate) return writes; } }
    public long Failures { get { lock (gate) return failures; } }
    public GptLatestFileWriter(Action<string> sink) { if (sink == null) throw new ArgumentNullException("sink"); write = sink; }
    public GptLatestFileWriter(string path) : this(delegate(string text) {
        string temp = path + ".async.tmp";
        try {
            System.IO.File.WriteAllText(temp, text, new System.Text.UTF8Encoding(false));
            if (System.IO.File.Exists(path)) System.IO.File.Replace(temp, path, path + ".bak", true);
            else System.IO.File.Move(temp, path);
        } finally {
            // A failed write is reported by the worker; cleanup is best effort.
            try { if (System.IO.File.Exists(temp)) System.IO.File.Delete(temp); } catch { }
        }
    }) { }
    public bool Submit(string text) {
        if (text == null) throw new ArgumentNullException("text");
        lock (gate) {
            if (closed) return false;
            pending = text;
            if (!running) {
                running = true;
                try { System.Threading.Tasks.Task.Run((Action)Run); }
                catch { running = false; pending = null; System.Threading.Monitor.PulseAll(gate); throw; }
            }
            return true;
        }
    }
    void Run() {
        while (true) {
            string text;
            lock (gate) {
                text = pending; pending = null;
                if (text == null) { running = false; System.Threading.Monitor.PulseAll(gate); return; }
            }
            try { write(text); lock (gate) { writes++; error = null; } }
            catch (Exception e) { lock (gate) { failures++; error = e.GetType().Name; } }
        }
    }
    public bool Drain(int milliseconds) {
        var watch = Stopwatch.StartNew();
        lock (gate) {
            while (running) {
                int remaining = milliseconds - (int)Math.Min(int.MaxValue, watch.ElapsedMilliseconds);
                if (remaining <= 0) return false;
                System.Threading.Monitor.Wait(gate, remaining);
            }
            return true;
        }
    }
    public bool Close(int milliseconds) { lock (gate) closed = true; return Drain(milliseconds); }
}

// AI-generated maintenance; insufficiently validated. See AI-NOTICE.md.
// Process path/start-time inspection can stall; never wait for it on the UI thread.
public sealed class GptWorkerHealthCheck {
    readonly System.Threading.Tasks.Task<bool> task;
    public bool IsCompleted { get { return task.IsCompleted; } }
    public bool Healthy { get { return task.Status == System.Threading.Tasks.TaskStatus.RanToCompletion && task.Result; } }
    public GptWorkerHealthCheck(Func<bool> check) { task = System.Threading.Tasks.Task.Run(check); }
    public GptWorkerHealthCheck(int pid, string expectedPath, long startedAt, int parentPid) : this(delegate {
        try {
            using (var process = Process.GetProcessById(pid)) {
                if (!String.Equals(process.MainModule.FileName, expectedPath, StringComparison.OrdinalIgnoreCase) || process.StartTime.ToUniversalTime() > DateTimeOffset.FromUnixTimeMilliseconds(startedAt).UtcDateTime) return false;
            }
            if (parentPid > 0) using (var parent = Process.GetProcessById(parentPid)) { if (parent.HasExited) return false; }
            return true;
        } catch { return false; }
    }) { }
}

// AI-generated diagnostics; insufficiently validated. Numeric bounded data only.
public sealed class GptFrameGapMetrics {
    readonly long[] histogram = new long[1001];
    double last = double.NaN, total;
    public long Count { get; private set; }
    public long Over25Ms { get; private set; }
    public long Over50Ms { get; private set; }
    public long Over100Ms { get; private set; }
    public double MaxMs { get; private set; }
    public double MeanMs { get { return Count == 0 ? 0 : total / Count; } }
    public double P95Ms { get { return Percentile(.95); } }
    public double P99Ms { get { return Percentile(.99); } }
    double Percentile(double fraction) {
        if (Count == 0) return 0;
        long target = (long)Math.Ceiling(Count * fraction), n = 0;
        for (int i = 0; i < histogram.Length; i++) { n += histogram[i]; if (n >= target) return i; }
        return 1000;
    }
    public void Record(double milliseconds) {
        if (double.IsNaN(milliseconds) || double.IsInfinity(milliseconds)) return;
        if (double.IsNaN(last)) { last = milliseconds; return; }
        if (milliseconds <= last) return;
        double gap = milliseconds - last; last = milliseconds;
        Count++; total += gap; MaxMs = Math.Max(MaxMs, gap);
        histogram[(int)Math.Min(1000, Math.Ceiling(gap))]++;
        if (gap > 25) Over25Ms++; if (gap >= 50) Over50Ms++; if (gap >= 100) Over100Ms++;
    }
    public void Break() { last = double.NaN; }
    public void Reset() { Array.Clear(histogram, 0, histogram.Length); Count = Over25Ms = Over50Ms = Over100Ms = 0; MaxMs = total = 0; Break(); }
}
public sealed class GptFrameWorkEvent {
    public string Kind { get; set; }
    public double AtMs { get; set; }
    public double DurationMs { get; set; }
}
public sealed class GptFrameWorkSummary {
    public string Kind { get; private set; }
    public long Count { get; private set; }
    public double MaxMs { get; private set; }
    double total;
    public double MeanMs { get { return Count == 0 ? 0 : total / Count; } }
    public GptFrameWorkSummary(string kind) { Kind = kind; }
    public void Add(double milliseconds) { Count++; total += milliseconds; MaxMs = Math.Max(MaxMs, milliseconds); }
}
public sealed class GptFrameProbe : IDisposable {
    readonly Stopwatch clock = Stopwatch.StartNew();
    readonly int seconds;
    readonly System.Collections.Generic.Queue<GptFrameWorkEvent> work = new System.Collections.Generic.Queue<GptFrameWorkEvent>();
    readonly System.Collections.Generic.Queue<GptFrameWorkEvent> stalls = new System.Collections.Generic.Queue<GptFrameWorkEvent>();
    TimeSpan lastPresentation = TimeSpan.MinValue;
    public GptFrameGapMetrics Presentation { get; private set; }
    public GptFrameGapMetrics Delivery { get; private set; }
    public bool IsRunning { get; private set; }
    public string SessionId { get; private set; }
    public bool Paused { get; set; }
    public double ElapsedMs { get { return clock.Elapsed.TotalMilliseconds; } }
    public long WorkCount { get; private set; }
    public double MaxWorkMs { get; private set; }
    public GptFrameWorkEvent[] WorkEvents { get { return work.ToArray(); } }
    public GptFrameWorkEvent[] Stalls { get { return stalls.ToArray(); } }
    double previousDelivery = double.NaN;
    readonly GptFrameWorkSummary[] summary = new[] { new GptFrameWorkSummary("quota"), new GptFrameWorkSummary("maintenance"), new GptFrameWorkSummary("drag"), new GptFrameWorkSummary("menu"), new GptFrameWorkSummary("worker"), new GptFrameWorkSummary("placement"), new GptFrameWorkSummary("persistence") };
    public GptFrameWorkSummary[] WorkSummary { get { return (GptFrameWorkSummary[])summary.Clone(); } }
    public GptFrameProbe(int durationSeconds) {
        seconds = Math.Max(5, Math.Min(120, durationSeconds));
        SessionId = Guid.NewGuid().ToString("N");
        Presentation = new GptFrameGapMetrics(); Delivery = new GptFrameGapMetrics();
        IsRunning = true; CompositionTarget.Rendering += Observe;
    }
    static void AddBounded(System.Collections.Generic.Queue<GptFrameWorkEvent> queue, GptFrameWorkEvent value) {
        if (queue.Count == 32) queue.Dequeue(); queue.Enqueue(value);
    }
    void Observe(object sender, EventArgs args) {
        if (!IsRunning) return;
        var frame = args as RenderingEventArgs;
        if (Paused) { Presentation.Break(); Delivery.Break(); previousDelivery = double.NaN; }
        else if (frame != null && frame.RenderingTime > lastPresentation) {
            lastPresentation = frame.RenderingTime;
            double now = ElapsedMs;
            Presentation.Record(frame.RenderingTime.TotalMilliseconds); Delivery.Record(now);
            if (!double.IsNaN(previousDelivery) && now - previousDelivery > 25)
                AddBounded(stalls, new GptFrameWorkEvent { Kind = "delivery", AtMs = now, DurationMs = now - previousDelivery });
            previousDelivery = now;
        }
        if (ElapsedMs >= seconds * 1000) Dispose();
    }
    public void RecordWork(string kind, double milliseconds) {
        if (!IsRunning || milliseconds < 0 || double.IsNaN(milliseconds) || double.IsInfinity(milliseconds)) return;
        GptFrameWorkSummary item = null;
        for (int i = 0; i < summary.Length; i++) if (summary[i].Kind == kind) { item = summary[i]; break; }
        if (item == null) return;
        item.Add(milliseconds);
        WorkCount++; MaxWorkMs = Math.Max(MaxWorkMs, milliseconds);
        AddBounded(work, new GptFrameWorkEvent { Kind = kind, AtMs = ElapsedMs, DurationMs = milliseconds });
    }
    public void Dispose() { if (!IsRunning) return; IsRunning = false; CompositionTarget.Rendering -= Observe; clock.Stop(); }
}

// AI-generated maintenance; insufficiently validated. See AI-NOTICE.md.
// A short, time-based tracking response keeps genuine fractional motion between
// coalesced cursor targets. Pointer velocity sampling remains independent.
public sealed class GptDragMotion {
    public double X { get; private set; }
    public double Y { get; private set; }
    double targetX, targetY;
    public GptDragMotion(double x, double y) { X=targetX=x; Y=targetY=y; }
    public void SetTarget(double x, double y) {
        if(double.IsNaN(x)||double.IsNaN(y)||double.IsInfinity(x)||double.IsInfinity(y))return;
        targetX=x; targetY=y;
    }
    public void Advance(double seconds, double left, double top, double right, double bottom) {
        double tx=Math.Max(left,Math.Min(right,targetX)),ty=Math.Max(top,Math.Min(bottom,targetY));
        double blend=1-Math.Exp(-Math.Max(0,Math.Min(.1,seconds))/.012);
        X=Math.Max(left,Math.Min(right,X+(tx-X)*blend));
        Y=Math.Max(top,Math.Min(bottom,Y+(ty-Y)*blend));
        if(Math.Abs(tx-X)<.01)X=tx;
        if(Math.Abs(ty-Y)<.01)Y=ty;
    }
}

// AI-generated maintenance; insufficiently validated. See AI-NOTICE.md.
// Preserve the script's existing hit tests. Unrelated messages need no runspace entry.
public sealed class GptWidgetMessageRouter {
    // AI-generated compatibility adaptation: notify native recovery without
    // re-entering PowerShell for every animation position completion.
    public Action<IntPtr> PositionChanged { get; set; }
    readonly System.Windows.Interop.HwndSourceHook next;
    readonly System.Windows.Interop.HwndSourceHook hook;
    public long Messages { get; private set; }
    public long ScriptMessages { get; private set; }
    public System.Windows.Interop.HwndSourceHook Hook { get { return hook; } }
    public GptWidgetMessageRouter(System.Windows.Interop.HwndSourceHook next) {
        if(next==null)throw new ArgumentNullException("next");
        this.next=next;hook=Route;
    }
    IntPtr Route(IntPtr hwnd,int message,IntPtr w,IntPtr l,ref bool handled) {
        Messages++;
        switch(message) {
            case 0x47:
                var observer=PositionChanged;if(observer!=null)observer(l);
                return IntPtr.Zero;
            case 0x84: case 0x21: case 0x2E0: case 0x7E: case 0x1A:
                ScriptMessages++;
                return next(hwnd,message,w,l,ref handled);
            default:return IntPtr.Zero;
        }
    }
}

// Configuration is refreshed by PowerShell at input/layout boundaries, never per frame.
public sealed class GptGravityScene {
    public GptGravityModel Model;
    public TranslateTransform Offset;
    public GptDragMotion Drag;
    public ScaleTransform Scale;
    public IntPtr Widget, Host;
    public bool Follow, Free;
    public int Width, Height, FrameLeft, FrameTop, FrameRight, FrameBottom;
    public double Unit, Padding, Dpi, Left, Right;
    public string Anchor;
    public Func<int[]> ReadFrame;
    public Action<int,int,int,string> Move;
    public bool HasPose;
    public double PoseLeft, PoseRight;
    public int X,Y,Bottom;
}

// Model, image pose and native movement stay in C#. Script notifications are limited to 4 Hz.
public sealed class GptGravityRenderLoop {
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentThread();
    [DllImport("kernel32.dll")] static extern bool GetThreadTimes(IntPtr thread,out long created,out long exited,out long kernel,out long user);
    public bool IsEnabled { get; private set; }
    // A presentation observer must use the same active window and ignore nested
    // layout callbacks while the outer frame is still being processed.
    public bool CanObserveFrame { get { return IsEnabled && !rendering; } }
    public GptGravityScene Scene { get; set; }
    public event EventHandler Tick;
    public int TargetFps { get { return 240; } }
    public long FrameCount { get; private set; }
    public long SlowFrames { get; private set; }
    public double Fps { get { double span=(last-first).TotalSeconds;return span>0?(FrameCount-1)/span:0; } }
    public long PositionUpdates { get; private set; }
    public double TotalStepMs { get; private set; }
    public double MeanStepMs { get { return FrameCount>0?TotalStepMs/FrameCount:0; } }
    public double MaxStepMs { get; private set; }
    // AI-generated maintenance diagnostics: numeric timings only, see AI-NOTICE.md.
    public double MeanPhysicsMs { get { return MeanMilliseconds(physicsTicks); } }
    public double MeanPoseMs { get { return MeanMilliseconds(poseTicks); } }
    public double MeanPlacementMs { get { return MeanMilliseconds(placementTicks); } }
    public double MeanCpuMs { get { return FrameCount>0?cpuTicks/10000.0/FrameCount:0; } }
    public bool CpuTimingAvailable { get; private set; }
    long cpuTicks;
    long physicsTicks,poseTicks,placementTicks;
    double MeanMilliseconds(long ticks) { return FrameCount>0?1000.0*ticks/Stopwatch.Frequency/FrameCount:0; }
    static long ThreadCpuTicks() {
        long created,exited,kernel,user;
        return GetThreadTimes(GetCurrentThread(),out created,out exited,out kernel,out user)?kernel+user:-1;
    }
    public string LastError { get; private set; }
    TimeSpan last = TimeSpan.MinValue, first;
    readonly Stopwatch clock=new Stopwatch(), cost=new Stopwatch();
    double previous, notified, cadenceAt, cadenceTokens;
    bool rendering;
    public void Start() {
        if(IsEnabled)return;IsEnabled=true;last=TimeSpan.MinValue;FrameCount=SlowFrames=0;MaxStepMs=TotalStepMs=0;PositionUpdates=0;LastError=null;
        physicsTicks=poseTicks=placementTicks=0;
        cpuTicks=0;CpuTimingAvailable=true;
        previous=notified=0;cadenceAt=double.NaN;cadenceTokens=2;
        clock.Restart();CompositionTarget.Rendering+=Render;
    }
    public void Stop() { if(!IsEnabled)return;IsEnabled=false;CompositionTarget.Rendering-=Render; }
    void Notify(){var handler=Tick;if(handler!=null)handler(this,EventArgs.Empty);}
    bool Step(double seconds) {
        var s=Scene;
        if(!IsWindowVisible(s.Widget) || (s.Follow && (s.Host==IntPtr.Zero || !IsWindowVisible(s.Host) || IsIconic(s.Host))))return false;
        int[] frame=s.ReadFrame==null?null:s.ReadFrame();
        if(frame!=null){s.FrameLeft=frame[0];s.FrameTop=frame[1];s.FrameRight=frame[2];s.FrameBottom=frame[3];}
        if(s.Unit<=0 || s.FrameRight<=s.FrameLeft || s.FrameBottom<=s.FrameTop)return false;
        double ceiling=Math.Max(0,(s.FrameBottom-s.FrameTop-s.Height+s.Padding)/s.Unit);
        double width=Math.Max(0,(s.FrameRight-s.FrameLeft-s.Width)/s.Unit);
        long started=Stopwatch.GetTimestamp();
        if(s.Drag!=null){
            s.Drag.Advance(seconds,s.FrameLeft,s.FrameTop,Math.Max(s.FrameLeft,s.FrameRight-s.Width),Math.Max(s.FrameTop,s.FrameBottom-s.Height+s.Padding));
            s.Model.SetHorizontalPosition((s.Drag.X-s.FrameLeft)/s.Unit);
            s.Model.DragTo((s.FrameBottom-s.Height+s.Padding-s.Drag.Y)/s.Unit);
        }else s.Model.Advance(seconds,ceiling,width);
        physicsTicks+=Stopwatch.GetTimestamp()-started;started=Stopwatch.GetTimestamp();
        if(s.Scale.ScaleX!=s.Model.ScaleX)s.Scale.ScaleX=s.Model.ScaleX;
        if(s.Scale.ScaleY!=s.Model.ScaleY)s.Scale.ScaleY=s.Model.ScaleY;
        poseTicks+=Stopwatch.GetTimestamp()-started;started=Stopwatch.GetTimestamp();
        double exactX=s.Free?s.FrameLeft+s.Model.HorizontalPosition*s.Unit:
            s.Anchor=="right"?s.FrameRight-s.Width-s.Right*s.Dpi:s.FrameLeft+s.Left*s.Dpi;
        exactX=Math.Max(s.FrameLeft,Math.Min(s.FrameRight-s.Width,exactX));
        int x=(int)Math.Round(exactX);
        int bottom=(int)Math.Round(s.Model.Height*s.Unit-s.Padding);
        int y=s.FrameBottom-s.Height-bottom;
        double exactY=s.FrameBottom-s.Height+s.Padding-s.Model.Height*s.Unit;
        // Native HWND coordinates are integers. Preserve the genuine fractional
        // position in the visual tree instead of discarding subpixel motion.
        if(s.Offset!=null){
            double ox=(exactX-x)/s.Unit,oy=(exactY-y)/s.Unit;
            if(s.Offset.X!=ox)s.Offset.X=ox;
            if(s.Offset.Y!=oy)s.Offset.Y=oy;
        }
        string anchor=s.Free?"free":s.Anchor;
        double left=(x-s.FrameLeft)/s.Dpi,right=(s.FrameRight-x-s.Width)/s.Dpi;
        bool moved=!s.HasPose || s.X!=x || s.Y!=y;
        if(s.Move!=null){
            // Compression and rounded subpixel movement can leave the native
            // rectangle unchanged. Keep rendering the pose without repeating
            // host placement/monitor/clipping queries for the same position.
            if(moved || s.PoseLeft!=left || s.PoseRight!=right || s.Bottom!=bottom)
                s.Move((int)Math.Round(left*s.Dpi),(int)Math.Round(right*s.Dpi),bottom,anchor);
        }
        else {
            // SWP_NOSENDCHANGING skips redundant move negotiation; keep completion/DPI messages.
            Rect old;if(!GetWindowRect(s.Widget,out old) || old.Left!=x || old.Top!=y)
                if(!SetWindowPos(s.Widget,IntPtr.Zero,x,y,0,0,0x415))throw new InvalidOperationException("Native animation movement failed");
        }
        if(moved)PositionUpdates++;
        s.X=x;s.Y=y;s.Bottom=bottom;s.PoseLeft=left;s.PoseRight=right;s.HasPose=true;
        placementTicks+=Stopwatch.GetTimestamp()-started;
        return s.Drag!=null || s.Model.Active;
    }
    void Render(object sender,EventArgs args) {
        if(rendering)return;
        rendering=true;try{RenderFrame(sender,args);}finally{rendering=false;}
    }
    void RenderFrame(object sender,EventArgs args) {
        var frame=args as RenderingEventArgs;
        if(frame!=null){if(frame.RenderingTime==last)return;last=frame.RenderingTime;}
        double now=clock.Elapsed.TotalSeconds;
        // Limit presentation frames, not bursty callback arrival times. Native
        // placement can block until composition and compress subsequent arrivals.
        // Physics still advances by real elapsed time below.
        double presentation=frame==null?now:frame.RenderingTime.TotalSeconds;
        // A two-frame token bucket caps sustained work at 240 Hz while retaining
        // normal 60-Hz long/short presentation jitter after a blocked native move.
        // A hard minimum gap would discard valid 8/25-ms pairs averaging 60 Hz.
        // The former 120-Hz budget repeatedly skipped a fast WPF callback, then
        // suffered producer backoff. Keep the bounded budget above that cadence.
        if(Scene!=null){
            if(double.IsNaN(cadenceAt) || presentation<cadenceAt)cadenceTokens=2;
            else cadenceTokens=Math.Min(2,cadenceTokens+(presentation-cadenceAt)*TargetFps);
            cadenceAt=presentation;
            if(cadenceTokens+0.000001<1)return;
            cadenceTokens=Math.Max(0,cadenceTokens-1);
        }
        if(FrameCount==0)first=last;
        FrameCount++;
        double dt=now-previous;previous=now;
        if(dt>1.0/40)SlowFrames++;
        if(Scene==null){Notify();return;}
        long cpuStart=ThreadCpuTicks();cost.Restart();bool active;
        try{active=Step(dt);}catch(Exception e){LastError=e.ToString();active=false;}
        cost.Stop();TotalStepMs+=cost.Elapsed.TotalMilliseconds;MaxStepMs=Math.Max(MaxStepMs,cost.Elapsed.TotalMilliseconds);
        long cpuEnd=ThreadCpuTicks();
        if(cpuStart<0 || cpuEnd<cpuStart)CpuTimingAvailable=false;
        else cpuTicks+=cpuEnd-cpuStart;
        if(!active){Stop();Notify();}
        else if(now-notified>=0.25){notified=now;Notify();}
    }
}
