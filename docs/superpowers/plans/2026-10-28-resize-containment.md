# Host resize containment

AI-generated plan and changes; insufficiently validated. See AI-NOTICE.md.

1. Preserve the accepted release commit with a backup tag and an external Git bundle; use a personal feature branch.
2. Reproduce disappearance using isolated HWNDs: fixed relative offsets can place the artwork beyond a smaller host, after which the existing region clips it completely.
3. Cache resting artwork bounds from the existing independent character layout and Uniform source aspect ratio. Refresh for character/layout changes and physical pixel dimensions, including DPI changes with unchanged logical dimensions.
4. Clamp in the existing native host-follow/musical-offset path and normal placement path. Keep transparent bubble margins, native movement flags, capture, physics, quota and scheduling contracts. Center oversized artwork when containment is physically impossible. No extra timer, scan, per-frame layout query or setting write.
5. Run resize/native, drag, gravity, music, startup and Node checks; measure the enabled native path serially. Request review, document limitations, audit source, synchronize and reload. Source only; no release requested.

Acceptance does not imply testing every display configuration or hardware input. User feedback takes precedence over short synthetic performance samples. If this worsens interaction, preserve the experiment and revert it independently.
