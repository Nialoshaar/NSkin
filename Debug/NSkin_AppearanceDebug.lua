local _, NSkin = ...

local refreshFallbacks = {
    total = 0,
    reasons = {},
    classifications = {},
    scopes = {},
}

local function Increment(bucket, key)
    key = key or "unknown"
    bucket[key] = (bucket[key] or 0) + 1
end

local function ClassifyFallback(change, reason)
    if reason == "global_change" or reason == "broad_scope"
        or reason == "compatibility_refresh"
    then return "global_or_broad" end
    if reason == "structural_change" or reason == "structural_element"
        or reason == "structural_module"
    then return "structural" end
    if reason == "unresolved_element" or reason == "unknown_component_type"
        or reason == "style_mismatch"
    then return "resolution" end
    if reason == "custom_adapter" or reason == "module_disabled" then
        return "safety"
    end
    if reason == "missing_refresh_contract" or reason == "targeted_refresh_failed" then
        return "execution"
    end
    return change and change.scope or "unknown"
end

function NSkin:DebugAppearanceRefresh(change, reason)
    refreshFallbacks.total = refreshFallbacks.total + 1
    Increment(refreshFallbacks.reasons, reason)
    Increment(refreshFallbacks.classifications, ClassifyFallback(change, reason))
    Increment(refreshFallbacks.scopes, change and change.scope or "unspecified")
end

function NSkin:GetAppearanceRefreshDebugCounters()
    return refreshFallbacks
end

function NSkin:ResetAppearanceRefreshDebugCounters()
    refreshFallbacks.total = 0
    wipe(refreshFallbacks.reasons)
    wipe(refreshFallbacks.classifications)
    wipe(refreshFallbacks.scopes)
end

local function FormatBucket(label, bucket)
    local keys = {}
    for key in pairs(bucket) do keys[#keys + 1] = key end
    table.sort(keys)
    local values = {}
    for i = 1, #keys do
        values[#values + 1] = keys[i] .. "=" .. bucket[keys[i]]
    end
    return label .. ": " .. (#values > 0 and table.concat(values, ", ") or "none")
end

function NSkin:DumpAppearanceRefreshDebugCounters()
    self:Print("appearance refresh fallbacks: " .. refreshFallbacks.total)
    self:Print(FormatBucket("reasons", refreshFallbacks.reasons))
    self:Print(FormatBucket("classes", refreshFallbacks.classifications))
    self:Print(FormatBucket("scopes", refreshFallbacks.scopes))
end
