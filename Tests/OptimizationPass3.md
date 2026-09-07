# Optimization Pass 3 validation

Run `lua Tests/OptimizationPass3.lua` from the repository root with Lua 5.4.
The harness verifies appearance-scope ancestry, owning-module window refresh,
shared-style fan-out, exact component-type routing (including same-style
controls), global dependency fallback, scoped versus global border resnapping,
and typed-registration comparison correctness.

Client and Perfy validation remains required. Re-run the exact Pass 2 Options UI,
Skinning Mode, and Collections captures with the same client, profile, enabled
addons, and interaction sequence. Window/type edits should no longer enter broad
cross-module branches, Skinning Mode element-edit traces should remain scoped,
and Collections reopen x10 should remain materially unchanged from Pass 2.
