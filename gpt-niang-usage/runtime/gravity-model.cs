using System;

// Pure physics, in design-space DIP and seconds. No WPF, HWND, clock or files.
public sealed class GptGravityModel {
    public const double Gravity = 1800.0;
    public const double TapHeight = 24.0;
    public const double CompressionSeconds = 0.22;
    public const double ChargeSeconds = 1.2;
    public const double Restitution = 0.64;
    public double Height { get; private set; }
    public double Velocity { get; private set; }
    public double ScaleX { get; private set; }
    public double ScaleY { get; private set; }
    public double PeakHeight { get; private set; }
    public double Charge { get; private set; }
    public int Rebounds { get; private set; }
    public bool IsPressed { get; private set; }
    public bool ReleasePending { get; private set; }
    public bool Dragging { get; private set; }
    public bool Active { get { return IsPressed || ReleasePending || flying || impact > 0; } }
    double age, held, impact, relax, releasedX, releasedY;
    bool flying, multiple;

    public GptGravityModel() { Reset(); }
    public void Reset() {
        Height = Velocity = PeakHeight = Charge = age = held = impact = relax = 0;
        ScaleX = ScaleY = 1; Rebounds = 0;
        IsPressed = ReleasePending = Dragging = flying = multiple = false;
    }
    public void BeginPress() {
        IsPressed = true; ReleasePending = Dragging = flying = multiple = false;
        Velocity = age = held = Charge = impact = relax = 0; Rebounds = 0; UpdatePose();
    }
    public void ReleasePress() {
        if (!IsPressed) return;
        IsPressed = false; ReleasePending = true;
        if (age >= CompressionSeconds - 1e-9) Launch();
    }
    public void BeginDrag() {
        IsPressed = ReleasePending = flying = false; Dragging = true;
        Velocity = Charge = held = age = impact = relax = 0; ScaleX = ScaleY = 1;
    }
    public void DragTo(double height) { Height = Math.Max(0, height); }
    public void DropFrom(double height) {
        Reset(); Height = PeakHeight = Math.Max(0, height);
        multiple = true; flying = Height > 0;
    }
    public void CancelPress() { DropFrom(Height); }
    void Launch() {
        releasedX = ScaleX; releasedY = ScaleY; relax = 0.1;
        Charge = Math.Max(0, Math.Min(1, (held - CompressionSeconds) / ChargeSeconds));
        double jump = TapHeight + 260 * Charge * Charge;
        Velocity = Math.Sqrt(2 * Gravity * jump);
        PeakHeight = Height + jump; multiple = Charge > 1e-8;
        flying = true; ReleasePending = false; UpdatePose();
    }
    public void Advance(double seconds, double maximumHeight) {
        if (double.IsNaN(seconds) || double.IsInfinity(seconds) || seconds <= 0) return;
        maximumHeight = double.IsNaN(maximumHeight) ? 0 : Math.Max(0, maximumHeight);
        if (maximumHeight <= 0) { Reset(); return; }
        if (Height > maximumHeight) { Height = maximumHeight; Velocity = Math.Min(0, Velocity); }
        PeakHeight = Math.Min(PeakHeight, maximumHeight);
        // Pause rather than fast-forward across a hidden/busy UI interval.
        double remaining = Math.Min(seconds, 0.1);
        while (remaining > 1e-9) {
            double dt = Math.Min(remaining, 1.0 / 120);
            if (ReleasePending && age < CompressionSeconds)
                dt = Math.Min(dt, CompressionSeconds - age);
            remaining -= dt;
            impact = Math.Max(0, impact - dt);
            relax = Math.Max(0, relax - dt);
            if (IsPressed || ReleasePending) {
                age += dt;
                if (IsPressed) held += dt;
                Charge = Math.Max(0, Math.Min(1, (held - CompressionSeconds) / ChargeSeconds));
                if (ReleasePending && age >= CompressionSeconds - 1e-9) Launch();
            } else if (flying) AdvanceFlight(dt, maximumHeight);
        }
        UpdatePose();
    }
    void AdvanceFlight(double seconds, double ceiling) {
        double left = seconds;
        while (flying && left > 1e-9) {
            double floorTime = (Velocity + Math.Sqrt(Velocity * Velocity + 2 * Gravity * Height)) / Gravity;
            double ceilingTime = double.PositiveInfinity;
            double discriminant = Velocity * Velocity - 2 * Gravity * (ceiling - Height);
            if (Velocity > 0 && discriminant >= 0)
                ceilingTime = Math.Max(0, (Velocity - Math.Sqrt(discriminant)) / Gravity);
            double time = Math.Min(left, Math.Min(floorTime, ceilingTime));
            Height += Velocity * time - 0.5 * Gravity * time * time;
            Velocity -= Gravity * time; left -= time;
            if (ceilingTime <= time + 1e-9) {
                Height = ceiling; Velocity = 0; PeakHeight = ceiling;
            } else if (floorTime <= time + 1e-9) {
                Height = 0; impact = 0.12;
                // Stop after the small jump has actually landed, not before it occurs.
                if (!multiple || PeakHeight <= TapHeight + 1e-8) {
                    Velocity = 0; flying = false;
                } else {
                    Velocity = Math.Abs(Velocity) * Restitution;
                    PeakHeight = Velocity * Velocity / (2 * Gravity); Rebounds++;
                }
            }
        }
        Height = Math.Max(0, Math.Min(ceiling, Height));
    }
    void UpdatePose() {
        if (IsPressed || ReleasePending) {
            double t = Math.Min(1, age / CompressionSeconds);
            double ease = t * t * (3 - 2 * t);
            ScaleY = 1 - 0.12 * ease - 0.4 * Charge;
            ScaleX = 1 + 0.05 * ease + 0.4 * Charge;
        } else {
            double stretch = flying ? Math.Min(0.06, Math.Abs(Velocity) / 14000) : 0;
            double pulse = impact > 0 ? Math.Sin(Math.PI * (1 - impact / 0.12)) : 0;
            ScaleX = 1 - stretch * 0.5 + pulse * 0.08;
            ScaleY = 1 + stretch - pulse * 0.15;
            if (relax > 0) {
                double blend = relax / 0.1;
                blend = blend * blend * (3 - 2 * blend);
                ScaleX += (releasedX - ScaleX) * blend;
                ScaleY += (releasedY - ScaleY) * blend;
            }
        }
    }
}
