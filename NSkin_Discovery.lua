local _, NSkin = ...

-- Shared-element discovery deliberately owns only registration discovery and
-- registry consistency. Shared components continue to own appearance.
NSkin.registeredElementByFrame = NSkin.registeredElementByFrame
    or setmetatable({}, { __mode = "k" })
NSkin.originalStateByFrame = NSkin.originalStateByFrame
    or setmetatable({}, { __mode = "k" })
NSkin.discoveryAudit = NSkin.discoveryAudit or {}

local registrationByID = {}
local deferredApplications = {}
local ORIGINAL_NIL = {}
local legacyRegisterSkinningElement = NSkin.RegisterSkinningElement
local MAX_DEPTH = 12
local MAX_CANDIDATES = 500

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function SameDefinition(left, right)
    local ignored = { applyState = true, applyError = true,
        definitionVersion = true, _registrationChanged = true }
    for key, value in pairs(left or {}) do
        if not ignored[key] and right[key] ~= value then return false end
    end
    for key, value in pairs(right or {}) do
        if not ignored[key] and left[key] ~= value then return false end
    end
    return true
end

local function AuditLine(data)
    NSkin.discoveryAudit[#NSkin.discoveryAudit + 1] = data
    local parts = { "[Discovery]" }
    for _, key in ipairs({ "id", "type", "stable", "existing",
        "action", "reason" }) do
        if data[key] ~= nil then
            parts[#parts + 1] = key .. "=" .. tostring(data[key])
        end
    end
    if NSkin.discoveryAuditVerbose then NSkin:Print(table.concat(parts, " ")) end
end

function NSkin:GetDiscoveryAudit()
    return self.discoveryAudit
end

function NSkin:ClearDiscoveryAudit()
    wipe(self.discoveryAudit)
end

function NSkin:CaptureOriginalProperty(target, propertyKey, value, restore)
    if not target or type(propertyKey) ~= "string" or propertyKey == "" then
        return false
    end
    local state = self.originalStateByFrame[target]
    if not state then
        state = { properties = {}, restorers = {}, captured = {} }
        self.originalStateByFrame[target] = state
    end
    state.captured = state.captured or {}
    if state.captured[propertyKey] then return false end
    state.captured[propertyKey] = true
    state.properties[propertyKey] = value == nil and ORIGINAL_NIL or value
    if type(restore) == "function" then state.restorers[propertyKey] = restore end
    return true
end

function NSkin:RestoreOriginalProperties(target, requested)
    local state = target and self.originalStateByFrame[target]
    if not state then return false end
    local restored = false
    for key, value in pairs(state.properties) do
        if not requested or requested[key] then
            local restore = state.restorers[key]
            if restore then
                if value == ORIGINAL_NIL then value = nil end
                local ok = pcall(restore, target, value)
                restored = ok or restored
            end
        end
    end
    local data = self:GetSkinData(target, "components", false)
    if data then
        for _, key in ipairs({ "flatBackground", "flatButtonGlow",
            "dropdownArrow", "scrollTrack", "scrollThumb" }) do
            local region = data[key]
            if region and region.Hide then region:Hide() end
        end
        for _, key in ipairs({ "NSkinFlatBackgroundBorder",
            "NSkinSharedDropdownMenuBorder" }) do
            local border = data[key]
            if type(border) == "table" then
                for _, region in pairs(border) do
                    if region and region.Hide then region:Hide() end
                end
            end
        end
    end
    return restored
end

local function ValidateDefinition(definition)
    return type(definition) == "table"
        and type(definition.id) == "string" and definition.id ~= ""
        and definition.target ~= nil
        and (definition.source == "explicit"
            or definition.source == "discovered")
end

function NSkin:UpsertComponentRegistration(definition)
    if not ValidateDefinition(definition) then
        return nil, false, "invalid-definition"
    end

    local target = definition.target
    local existing = self.registeredElementByFrame[target]
    local idOwner = registrationByID[definition.id]
        or self:GetSkinningElement(definition.id)
    if idOwner and idOwner.target ~= target then
        AuditLine({ id = definition.id, type = definition.componentType,
            action = "error", reason = "id-conflict" })
        return nil, false, "id-conflict"
    end

    if existing and existing.source == "explicit"
        and definition.source == "discovered"
    then
        return existing, false
    end

    local proposed = CopyTable(existing or {})
    if existing and definition.source == "explicit" then
        for key in pairs(proposed) do proposed[key] = nil end
    end
    for key, value in pairs(definition) do proposed[key] = value end
    proposed.source = definition.source
    proposed.applyState = proposed.applyState or "pending"
    proposed.definitionVersion = (existing and existing.definitionVersion or 0)
        + (existing and SameDefinition(existing, proposed) and 0 or 1)

    if existing and SameDefinition(existing, proposed) then return existing, false end
    if existing and existing.id ~= proposed.id then
        registrationByID[existing.id] = nil
    end
    if existing then
        for key in pairs(existing) do existing[key] = nil end
        for key, value in pairs(proposed) do existing[key] = value end
        proposed = existing
    end
    self.registeredElementByFrame[target] = proposed
    registrationByID[proposed.id] = proposed
    return proposed, true
end

function NSkin:RegisterSkinningElement(elementID, definition)
    if type(definition) ~= "table" then return false end
    definition.id = elementID
    definition.window = definition.window or definition.owner
    definition.target = definition.target or definition.container
        or definition.owner
    definition.source = definition.source or "explicit"
    if definition.source == "explicit" and not definition.componentType
        and definition.applyState == nil
    then
        definition.applyState = "applied"
    end
    local indexed = definition.target
        and self.registeredElementByFrame[definition.target]
    local idOwner = self:GetSkinningElement(elementID)
    if idOwner and idOwner.target ~= definition.target then
        AuditLine({ id = elementID, type = definition.componentType,
            action = "error", reason = "id-conflict" })
        return false
    end
    -- Existing composite registrations can intentionally share a layout
    -- target (for example a window and its tab-group controller). They are
    -- not ordinary discoverable components and must retain separate IDs.
    if indexed and indexed.id ~= elementID
        and not definition.componentType
    then
        return legacyRegisterSkinningElement(self, elementID, definition)
    end
    local previousID = indexed and indexed.id
    local record, changed = self:UpsertComponentRegistration(definition)
    if not record then return false end
    record._registrationChanged = changed
    if not changed and self:GetSkinningElement(record.id) then return true end
    if previousID and previousID ~= record.id
        and self:GetSkinningElement(previousID) == record
    then
        self:RekeySkinningElement(previousID, record.id, record)
    end
    return legacyRegisterSkinningElement(self, record.id, record)
end

function NSkin:GetComponentRegistrationByFrame(frame)
    return frame and self.registeredElementByFrame[frame] or nil
end

function NSkin:GetComponentRegistrationByID(id)
    return type(id) == "string" and registrationByID[id] or nil
end

local function CaptureCommonState(target)
    if target.GetAlpha then
        NSkin:CaptureOriginalProperty(target, "alpha", target:GetAlpha(),
            function(frame, value) frame:SetAlpha(value) end)
    end
    if target.IsShown then
        NSkin:CaptureOriginalProperty(target, "shown", target:IsShown(),
            function(frame, value) frame:SetShown(value) end)
    end
    if target.GetSize then
        NSkin:CaptureOriginalProperty(target, "size", { target:GetSize() },
            function(frame, value) frame:SetSize(value[1], value[2]) end)
    end
end

local function CaptureFontString(target, key)
    if not target or not target.GetFont then return end
    NSkin:CaptureOriginalProperty(target, key .. ".font", { target:GetFont() },
        function(frame, value) frame:SetFont(unpack(value)) end)
    if target.GetTextColor then
        NSkin:CaptureOriginalProperty(target, key .. ".textColor",
            { target:GetTextColor() }, function(frame, value)
                frame:SetTextColor(unpack(value))
            end)
    end
end

local function CaptureRegionState(owner, region, key)
    if not region or not region.GetObjectType then return end
    local ownerState = NSkin.originalStateByFrame[owner]
    if not ownerState then
        ownerState = { properties = {}, restorers = {}, captured = {} }
        NSkin.originalStateByFrame[owner] = ownerState
    end
    ownerState.regionKeys = ownerState.regionKeys
        or setmetatable({}, { __mode = "k" })
    local regionKey = ownerState.regionKeys[region]
    if not regionKey then
        ownerState.regionSequence = (ownerState.regionSequence or 0) + 1
        regionKey = "region." .. ownerState.regionSequence
        ownerState.regionKeys[region] = regionKey
    end
    key = regionKey
    local objectType = region:GetObjectType()
    local value = { region = region, objectType = objectType }
    if region.GetAlpha then value.alpha = region:GetAlpha() end
    if region.IsShown then value.shown = region:IsShown() end
    if region.GetSize then value.size = { region:GetSize() } end
    if region.GetNumPoints then
        value.points = {}
        for index = 1, region:GetNumPoints() do
            value.points[index] = { region:GetPoint(index) }
        end
    end
    if objectType == "Texture" then
        value.texture = region.GetTexture and region:GetTexture()
        value.atlas = region.GetAtlas and region:GetAtlas()
        value.texCoord = region.GetTexCoord and { region:GetTexCoord() }
        value.vertex = region.GetVertexColor and { region:GetVertexColor() }
        value.drawLayer = region.GetDrawLayer and { region:GetDrawLayer() }
    elseif objectType == "FontString" then
        value.font = region.GetFont and { region:GetFont() }
        value.textColor = region.GetTextColor and { region:GetTextColor() }
    end
    NSkin:CaptureOriginalProperty(owner, key, value, function(_, saved)
        local target = saved.region
        if not target then return end
        if saved.objectType == "Texture" then
            if saved.atlas and target.SetAtlas then
                target:SetAtlas(saved.atlas)
            elseif target.SetTexture then
                target:SetTexture(saved.texture)
            end
            if saved.texCoord and target.SetTexCoord then
                target:SetTexCoord(unpack(saved.texCoord))
            end
            if saved.vertex and target.SetVertexColor then
                target:SetVertexColor(unpack(saved.vertex))
            end
            if saved.drawLayer and target.SetDrawLayer then
                target:SetDrawLayer(unpack(saved.drawLayer))
            end
        elseif saved.objectType == "FontString" then
            if saved.font and target.SetFont then target:SetFont(unpack(saved.font)) end
            if saved.textColor and target.SetTextColor then
                target:SetTextColor(unpack(saved.textColor))
            end
        end
        if saved.points and target.ClearAllPoints then
            target:ClearAllPoints()
            for _, point in ipairs(saved.points) do target:SetPoint(unpack(point)) end
        end
        if saved.size and target.SetSize then target:SetSize(unpack(saved.size)) end
        if saved.alpha ~= nil and target.SetAlpha then target:SetAlpha(saved.alpha) end
        if saved.shown ~= nil and target.SetShown then target:SetShown(saved.shown) end
    end)
end

local function CaptureVisualState(target)
    local visited, sequence = {}, 0
    local function Capture(frame, depth)
        if not frame or visited[frame] or depth > 2 then return end
        visited[frame] = true
        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do
                sequence = sequence + 1
                CaptureRegionState(target, region, "region." .. sequence)
            end
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                sequence = sequence + 1
                CaptureRegionState(target, child, "child." .. sequence)
                Capture(child, depth + 1)
            end
        end
    end
    Capture(target, 0)
end

local function GetButtonFontString(target)
    return target.GetFontString and target:GetFontString()
        or target.Text or target.text
end

local COMPONENTS = {
    button = { kind = "BUTTON", skin = function(target)
        NSkin:SkinFlatButton(target)
    end },
    dropdown = { kind = "DROPDOWN", skin = function(target)
        NSkin:SkinDropdown(target)
    end },
    editBox = { kind = "SEARCH_GROUP", skin = function(target)
        NSkin:SkinSearchBox(target)
    end },
    scrollBar = { kind = "SCROLLBAR", skin = function(target)
        NSkin:SkinScrollBar(target)
    end },
    tab = { kind = "BUTTON", skin = function(target)
        NSkin:SkinTab(target, false)
    end },
}

local function ApplyRegistration(record)
    if not record or not record.target then return false, "invalid-target" end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        record.applyState, record.applyError = "pending", nil
        deferredApplications[record] = {
            id = record.id, version = record.definitionVersion,
            target = record.target,
        }
        AuditLine({ id = record.id, type = record.componentType,
            action = "defer", reason = "combat-lockdown" })
        return false, "combat-lockdown"
    end
    local component = COMPONENTS[record.componentType]
    if not component then
        record.applyState, record.applyError = "failed", "unsupported-component"
        return false, record.applyError
    end
    CaptureCommonState(record.target)
    CaptureVisualState(record.target)
    CaptureFontString(GetButtonFontString(record.target), "text")
    local ok, result = pcall(component.skin, record.target, record)
    if ok then
        record.applyState, record.applyError = "applied", nil
        return result ~= false
    end
    record.applyState, record.applyError = "failed", tostring(result)
    return false, record.applyError
end

function NSkin:GetComponentRegistrar(componentType)
    local method = ({ button = "RegisterButton", editBox = "RegisterEditBox",
        dropdown = "RegisterDropdown", checkbox = "RegisterCheckbox",
        scrollBar = "RegisterScrollBar", tab = "RegisterTab" })[componentType]
    return method and self[method] or nil
end

local function RegisterTyped(componentType, definition)
    local component = COMPONENTS[componentType]
    if not component or type(definition) ~= "table" then return nil end
    definition = CopyTable(definition)
    definition.componentType = componentType
    definition.kind = definition.kind or component.kind
    definition.source = definition.source or "explicit"
    definition.restoreGeometry = definition.restoreGeometry or function(element)
        local restored = NSkin:RestoreOriginalProperties(element.target)
        return NSkin:RestoreComponentBaseline(element.id) or restored
    end
    if not NSkin:RegisterSkinningElement(definition.id, definition) then return nil end
    local record = NSkin.registeredElementByFrame[definition.target]
    if record and record.source == definition.source
        and (record._registrationChanged or record.applyState ~= "applied")
    then
        ApplyRegistration(record)
    end
    if record then record._registrationChanged = nil end
    return record
end

function NSkin:RegisterButton(definition) return RegisterTyped("button", definition) end
function NSkin:RegisterEditBox(definition) return RegisterTyped("editBox", definition) end
function NSkin:RegisterDropdown(definition) return RegisterTyped("dropdown", definition) end
function NSkin:RegisterCheckbox(definition) return RegisterTyped("checkbox", definition) end
function NSkin:RegisterScrollBar(definition) return RegisterTyped("scrollBar", definition) end
function NSkin:RegisterTab(definition) return RegisterTyped("tab", definition) end

local unsafeFieldKeys = {
    parent = true, owner = true, owningMenu = true, menu = true,
    pool = true, framePool = true, mixin = true, __index = true,
}

local function IsFrame(value)
    if not value or type(value) ~= "table" then return false end
    local ok, result = pcall(function()
        return value.IsObjectType and value:IsObjectType("Frame")
    end)
    return ok and result == true
end

local function FindStableFieldPath(target, roots, maxDepth)
    local best
    local visited = {}
    local function Visit(value, path, depth)
        if value == target then
            if not best or #path < #best or (#path == #best and path < best) then
                best = path
            end
            return
        end
        if type(value) ~= "table" or visited[value] or depth >= maxDepth then return end
        visited[value] = true
        local keys = {}
        for key in pairs(value) do
            if type(key) == "string" and not unsafeFieldKeys[key]
                and key:sub(1, 1) ~= "_"
            then keys[#keys + 1] = key end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local ok, child = pcall(function() return value[key] end)
            if ok and type(child) == "table" then
                Visit(child, path == "" and key or path .. "." .. key, depth + 1)
            end
        end
    end
    for _, root in ipairs(roots) do Visit(root.value, root.path or "", 0) end
    return best
end

local function NormalizePath(path)
    return path and path:gsub("[^%w_.]", ""):gsub("%.+", ".")
end

function NSkin:ResolveDiscoveredElementIdentity(windowID, rootFrame, frame, context)
    context = context or {}
    local existing = self.registeredElementByFrame[frame]
    if existing then
        return { id = existing.id, stable = true, source = "existing",
            fieldName = existing.id:match("([^.]+)$") }
    end
    local semantic = context.semanticIDs and context.semanticIDs[frame]
    if type(semantic) == "string" and semantic ~= "" then
        return { id = semantic, stable = true, source = "semantic",
            fieldName = semantic:match("([^.]+)$") }
    end
    local indexed = context.identityByFrame and context.identityByFrame[frame]
    if indexed then
        return { id = windowID .. "." .. NormalizePath(indexed),
            stable = true, source = "field-path", fieldPath = indexed,
            fieldName = indexed:match("([^.]+)$") }
    end
    local roots = { { value = rootFrame, path = "" } }
    for _, root in ipairs(context.identityRoots or {}) do
        roots[#roots + 1] = type(root) == "table" and root.value
            and root or { value = root, path = "" }
    end
    local path = FindStableFieldPath(frame, roots,
        tonumber(context.identityDepth) or 4)
    if path and path ~= "" then
        return { id = windowID .. "." .. NormalizePath(path), stable = true,
            source = "field-path", fieldPath = path,
            fieldName = path:match("([^.]+)$") }
    end
    local ok, name = pcall(function() return frame:GetName() end)
    if ok and type(name) == "string" and name ~= ""
        and not name:match("%x%x%x%x%x%x%x+")
    then
        return { id = windowID .. "." .. name, stable = true,
            source = "global-name", globalName = name,
            fieldName = name:match("([^.]+)$") }
    end
    return { stable = false }
end

function NSkin:ClassifySharedElement(frame, context)
    context = context or {}
    local forced = context.classifyAs and context.classifyAs[frame]
    if COMPONENTS[forced] or forced == "checkbox" then return forced end
    local role = (context.fieldName or ""):lower()
    if frame.SetupMenu and (role:find("dropdown", 1, true)
        or role:find("filter", 1, true) or role:find("difficulty", 1, true))
    then return "dropdown" end
    if frame.GetChecked and (role:find("check", 1, true)
        or role:find("toggle", 1, true)) then return "checkbox" end
    if frame.IsObjectType and frame:IsObjectType("EditBox")
        and (role:find("search", 1, true) or role:find("editbox", 1, true))
    then return "editBox" end
    if role:find("scrollbar", 1, true) and (frame.GetThumbTexture
        or frame.Track or frame.ScrollBox) then return "scrollBar" end
    if role:match("tab%d*$") and frame.IsObjectType
        and frame:IsObjectType("Button") then return "tab" end
    if frame.IsObjectType and frame:IsObjectType("Button")
        and (role:find("button", 1, true) or role == "home"
            or role == "previous" or role == "next")
    then return "button" end
    return nil
end

function NSkin:IsSharedElementDiscoverable(frame, componentType, context)
    context = context or {}
    if not frame or not componentType then return false, "unknown-component" end
    if context.exclude and context.exclude[frame] then return false, "excluded" end
    if not context.identity or not context.identity.stable then
        return false, "no-stable-identity"
    end
    if frame.owningMenu or frame.frameTemplateOrFrameType then
        return false, "compositor"
    end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok then return false, "unsafe-frame-access" end
        if forbidden then return false, "forbidden" end
    end
    if componentType == "checkbox" then return false, "incomplete-reset-support" end
    if not COMPONENTS[componentType] then return false, "unsupported-component" end
    return true
end

local function IsExcludedAncestor(frame, roots)
    local current = frame
    for _ = 1, 32 do
        if roots and roots[current] then return true end
        local ok, parent = pcall(function() return current:GetParent() end)
        if not ok or not parent or parent == current then break end
        current = parent
    end
    return false
end

function NSkin:DiscoverSharedElements(windowID, rootFrame, options)
    if type(windowID) ~= "string" or windowID == "" or not rootFrame then
        return nil, "invalid-root"
    end
    options = options or {}
    local identityByFrame = setmetatable({}, { __mode = "k" })
    local identityVisited = {}
    local function IndexFields(value, path, depth)
        if type(value) ~= "table" or identityVisited[value]
            or depth > (tonumber(options.identityDepth) or 4)
        then return end
        identityVisited[value] = true
        local keys = {}
        for key in pairs(value) do
            if type(key) == "string" and not unsafeFieldKeys[key]
                and key:sub(1, 1) ~= "_"
            then keys[#keys + 1] = key end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local ok, child = pcall(function() return value[key] end)
            if ok and type(child) == "table" then
                local childPath = path == "" and key or path .. "." .. key
                if IsFrame(child) then
                    local current = identityByFrame[child]
                    if not current or #childPath < #current
                        or (#childPath == #current and childPath < current)
                    then identityByFrame[child] = childPath end
                end
                IndexFields(child, childPath, depth + 1)
            end
        end
    end
    IndexFields(rootFrame, "", 0)
    for _, root in ipairs(options.identityRoots or {}) do
        local value = type(root) == "table" and root.value or root
        local path = type(root) == "table" and root.path or ""
        IndexFields(value, path or "", 0)
    end
    options = CopyTable(options)
    options.identityByFrame = identityByFrame
    local maxDepth = tonumber(options.maxDepth) or MAX_DEPTH
    local maxCandidates = tonumber(options.maxCandidates) or MAX_CANDIDATES
    local visited, candidates, summary = {}, 0,
        { candidate = 0, registered = 0, preserved = 0, skipped = 0,
            errors = 0, deferred = 0 }
    local enabled = {
        button = options.buttons ~= false, editBox = options.editBoxes ~= false,
        scrollBar = options.scrollBars ~= false,
        dropdown = options.dropdowns ~= false,
        checkbox = options.checkboxes ~= false, tab = options.tabs ~= false,
    }

    local function Process(frame)
        local identity = self:ResolveDiscoveredElementIdentity(
            windowID, rootFrame, frame, options)
        local context = CopyTable(options)
        context.identity = identity
        context.fieldPath = identity.fieldPath
        context.fieldName = identity.fieldName
        context.globalName = identity.globalName
        local ok, componentType = pcall(self.ClassifySharedElement,
            self, frame, context)
        if not ok then
            summary.errors = summary.errors + 1
            AuditLine({ action = "skip", reason = "unsafe-frame-access" })
            return
        end
        if not componentType or not enabled[componentType] then return end
        local eligible, reason = self:IsSharedElementDiscoverable(
            frame, componentType, context)
        local existing = self.registeredElementByFrame[frame]
        if not eligible then
            summary.skipped = summary.skipped + 1
            AuditLine({ id = identity.id, type = componentType,
                stable = identity.stable, action = "skip", reason = reason })
            return
        end
        if existing and existing.source == "explicit" then
            summary.preserved = summary.preserved + 1
            AuditLine({ id = existing.id, type = componentType, stable = true,
                existing = "explicit", action = "preserve" })
            return
        end
        summary.candidate = summary.candidate + 1
        if options.auditOnly then
            AuditLine({ id = identity.id, type = componentType, stable = true,
                existing = existing and existing.source or "none",
                action = "candidate" })
            return
        end
        local registrar = self:GetComponentRegistrar(componentType)
        local definition = {
            id = identity.id, source = "discovered", target = frame,
            window = rootFrame, module = options.module,
            appearanceWindowID = options.appearanceWindowID or windowID,
            label = identity.fieldName or identity.globalName or identity.id,
            priority = tonumber(options.priority) or 0,
            isEditable = options.isEditable,
        }
        local registered = registrar and registrar(self, definition)
        if registered then
            summary.registered = summary.registered + 1
            AuditLine({ id = identity.id, type = componentType, stable = true,
                action = registered.applyState == "pending" and "defer"
                    or "register",
                reason = registered.applyState == "pending"
                    and "combat-lockdown" or nil })
        else
            summary.errors = summary.errors + 1
            AuditLine({ id = identity.id, type = componentType,
                action = "error", reason = "registration-failed" })
        end
    end

    local function Walk(frame, depth)
        if not frame or visited[frame] or depth > maxDepth
            or candidates >= maxCandidates
        then return end
        visited[frame] = true
        candidates = candidates + 1
        local ok = pcall(Process, frame)
        if not ok then
            summary.errors = summary.errors + 1
            AuditLine({ action = "skip", reason = "unsafe-frame-access" })
        end
        if options.excludeChildrenOf and options.excludeChildrenOf[frame] then return end
        local childrenOK, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if not childrenOK then
            summary.skipped = summary.skipped + 1
            AuditLine({ action = "skip", reason = "unsafe-frame-access" })
            return
        end
        for _, child in ipairs(children) do Walk(child, depth + 1) end
    end
    Walk(rootFrame, 0)
    summary.scanned = candidates
    return summary
end

NSkin:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for record, queued in pairs(deferredApplications) do
        deferredApplications[record] = nil
        if record.target == queued.target and record.id == queued.id
            and record.definitionVersion == queued.version
            and NSkin.registeredElementByFrame[queued.target] == record
            and registrationByID[queued.id] == record
            and (not record.module or NSkin:IsModuleEnabled(record.module))
        then
            ApplyRegistration(record)
        end
    end
end)
