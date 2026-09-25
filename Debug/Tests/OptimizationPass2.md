# Optimization Pass 2 validation

Run `lua Tests/OptimizationPass2.lua` from the repository root with Lua 5.4.
The harness covers targeted appearance versus layout refresh, controller refresh
contracts, precise reset descriptors, idempotent typed registration, generated
typed targets, owner-scoped/coalesced border resnapping, and global fallback
accounting. It is not loaded by the addon TOC.

The debug counters are silent during normal play. `/nskin debug refresh` dumps
fallback totals by reason and scope; `/nskin debug refresh reset` clears them.

Client visual and Perfy validation remains required. After `/reload`, repeat the
same Collections reopen x10, Skinning Mode interaction, and Options UI captures
used for Pass 1. Confirm that local element edits do not refresh unrelated modules
and that `ResnapAllPixelBorders` appears only for global/structural work or display
scale changes, not ordinary selection and inspector edits.
