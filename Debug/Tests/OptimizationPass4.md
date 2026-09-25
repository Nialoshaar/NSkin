# Optimization Pass 4 validation

Run `lua Tests/OptimizationPass4.lua` from the repository root with Lua 5.4.
The harness verifies unchanged-value skips, isolated resolved-style cache reuse,
window/type cache invalidation, scope-chain copy safety, guarded pixel-border
geometry/color operations, and fully live Options slider handlers.

The Pass 4 harness also covers the slider-drag regression: live changes from
the active docked inspector carry a scoped origin, preserve that option view's
slider/value-label state for appearance and layout updates, retain full refresh
for structural or external changes, and restore the origin guard after errors.

Also rerun Passes 1–3 to preserve their routing and lifecycle guarantees.

Client and Perfy validation remains required. First repeat the Pass 3 Skinning
Mode capture once to confirm whether its memory increase reproduces. Then rerun
Collections reopen x10, Skinning Mode, and Options UI using the same client,
profile, enabled addons, and interaction sequences as the earlier captures.
