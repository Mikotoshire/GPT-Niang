using System;
using System.Windows.Media;

// Use WPF's render clock: a 16 ms dispatcher timer plus handler time can miss every other frame.
public sealed class GptGravityRenderLoop {
    public bool IsEnabled { get; private set; }
    public event EventHandler Tick;
    TimeSpan last = TimeSpan.MinValue;
    public void Start() { if(IsEnabled)return; IsEnabled=true;last=TimeSpan.MinValue;CompositionTarget.Rendering+=Render; }
    public void Stop() { if(!IsEnabled)return;IsEnabled=false;CompositionTarget.Rendering-=Render; }
    void Render(object sender,EventArgs args) {
        var frame=args as RenderingEventArgs;
        if(frame!=null){if(frame.RenderingTime==last)return;last=frame.RenderingTime;}
        var handler=Tick;if(handler!=null)handler(this,EventArgs.Empty);
    }
}
