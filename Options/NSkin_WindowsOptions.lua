local _, NSkin = ...

local WINDOW_ID = "PlayerSpells.SpellBook"

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

NSkin:RegisterOptionGroup("encounterJournal.journeyCardsBackground", {
    controls = {
        {
            type = "DROPDOWN",
            key = "backgroundMode",
            label = "Background",
            values = {
                { value = "DEFAULT", label = "Blizzard default" },
                { value = "IMAGES", label = "Images" },
                { value = "BLACK", label = "Black" },
            },
        },
        { type = "RESET", label = "Reset Background", compactLabel = "Reset" },
    },
    get = function()
        return { backgroundMode = NSkin:GetJourneyCardsBackgroundMode() }
    end,
    set = function(_, values)
        return NSkin:SetJourneyCardsBackgroundMode(values.backgroundMode)
    end,
    reset = function()
        return NSkin:ResetJourneyCardsBackgroundMode()
    end,
})

local dispositionOptions = {
    controllerID = "SpellBook.Spells.Disposition",
    label = "Icons disposition",
    formatChoice = function(count) return count .. " icons per row" end,
}
NSkin:RegisterColumnDispositionOptionGroup("spellbook.settings",
    dispositionOptions)

NSkin:RegisterOptionGroup("spellbook.appearance", {
    controls = {
        { type = "COLOR", key = "searchBackground", label = "Search background" },
        { type = "SLIDER", key = "searchOpacity", label = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
    },
    get = function()
        local style = NSkin:GetAppearanceStyle("searchBox", WINDOW_ID)
        return { searchBackground = CopyColor(style.background),
            searchOpacity = style.background[4] or 1 }
    end,
    set = function(_, values)
        local color = CopyColor(values.searchBackground)
        color[4] = values.searchOpacity
        return NSkin:SetWindowAppearanceOverride(
            WINDOW_ID, "searchBox.background", color
        )
    end,
    reset = function()
        return NSkin:ResetWindowAppearanceOverride(WINDOW_ID, "searchBox.background")
    end,
})

NSkin:RegisterColumnDispositionOptionGroup("spellbook.iconDisposition",
    dispositionOptions)

local function BuildSpellBookOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Spellbook")

    NSkin:CreateOptionsSection(page, "Module settings", 38)
    local settingsView = NSkin:CreateOptionGroupView(
        page, "spellbook.settings", "FULL", page
    )
    settingsView:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -70)
    local appearanceY = 90 + settingsView:GetHeight()
    local _, appearanceContentY = NSkin:CreateOptionsSection(
        page, "Appearance override", appearanceY
    )
    local appearanceView = NSkin:CreateOptionGroupView(
        page, "spellbook.appearance", "FULL", page
    )
    appearanceView:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -appearanceContentY)

    function page:ApplyAppearance()
        settingsView:ApplyAppearance()
        appearanceView:ApplyAppearance()
    end

    function page:Refresh()
        local context = NSkin:IsModuleEnabled("SpellBook") and page or nil
        settingsView:SetContext(context)
        appearanceView:SetContext(context)
        self:ApplyAppearance()
    end

    page:SetContentHeight(appearanceContentY + appearanceView:GetHeight() + 20)
    return page
end

-- Spellbook customization is intentionally docked-editor only. The main
-- options window still exposes module enablement through its module row.

NSkin:RegisterOptionGroup("talents.pageBackground", {
    controls = {
        { type = "DROPDOWN", key = "mode", label = "Talents page background", values = {
            { value = "DEFAULT", label = "Blizzard / Default" },
            { value = "NONE", label = "None" },
            { value = "CUSTOM", label = "Custom" },
        } },
        { type = "TEXT_INPUT", key = "path", label = "Custom texture path (Enter to apply)" },
        { type = "RESET", label = "Reset background" },
    },
    get = function()
        local values = NSkin:GetTalentsPageBackground()
        return { mode = values.mode or "DEFAULT", path = values.path or "" }
    end,
    set = function(_, values)
        local current = NSkin:GetTalentsPageBackground()
        return NSkin:SetTalentsPageBackground({
            mode = values.mode or current.mode or "DEFAULT",
            path = values.path or current.path or "",
        })
    end,
    reset = function() return NSkin:SetTalentsPageBackground(nil) end,
})

NSkin:RegisterOptionGroup("talents.choiceArrows", {
    controls = {
        { type = "SLIDER", key = "size", label = "Choice Arrow Size",
            min = 0.15, max = 0.60, step = 0.01, decimals = 2 },
        { type = "SLIDER", key = "spacing", label = "Choice Arrow Spacing",
            min = -12, max = 16, step = 1, decimals = 0 },
        { type = "RESET", label = "Reset choice arrows" },
    },
    get = function() return NSkin:GetTalentsChoiceArrowOptions() end,
    set = function(_, values) return NSkin:SetTalentsChoiceArrowOptions(values) end,
    reset = function() return NSkin:SetTalentsChoiceArrowOptions(nil) end,
})

NSkin:RegisterOptionGroup("talents.edgeArrows", {
    controls = {
        { type = "SLIDER", key = "scale", label = "Arrow Head Size",
            min = 0.2, max = 1, step = 0.05, decimals = 2 },
        { type = "RESET", label = "Reset edge arrows" },
    },
    get = function() return { scale = NSkin:GetTalentsEdgeArrowScale() } end,
    set = function(_, values)
        return NSkin:SetTalentsEdgeArrowScale(values.scale)
    end,
    reset = function() return NSkin:SetTalentsEdgeArrowScale(nil) end,
})

NSkin:RegisterOptionsPage({ key = "playerSpellsTalents", label = "Talents", group = "windows", order = 15,
    builder = function(parent)
        local page = NSkin:CreateOptionsPage(parent)
        local function Context(id, kind, extra)
            return function()
                return NSkin:GetSkinningElement(id) or extra or {
                    id = id, kind = kind, appearanceWindowID = "PlayerSpells.Talents",
                }
            end
        end
        local treeEntries, iconEntries = {}, {}
        for _, tree in ipairs({ "Class", "Hero", "Spec" }) do
            local treeName = tree
            treeEntries[#treeEntries + 1] = { label = treeName,
                groups = { "shared.movable" },
                context = function() return NSkin:GetSkinningElement("SpellBook.Talents." .. treeName .. "Tree") end }
        end
        for _, family in ipairs({ "Active", "Passive", "Choice" }) do
            local id = "SpellBook.Talents.Icons." .. family
            iconEntries[#iconEntries + 1] = { label = family,
                groups = family == "Choice"
                    and { "shared.iconAppearance", "talents.choiceArrows" }
                    or { "shared.iconAppearance" },
                context = Context(id, "ICON", { id = id, kind = "ICON", appearanceWindowID = "PlayerSpells.Talents",
                    defaultShape = family == "Active" and "square" or family == "Passive" and "circle" or "octagon" }) }
        end

        local selectedSection = 1
        local sections, sectionButtons = {}, {}
        local function ResizePage(height)
            page:SetContentHeight(height + 56)
        end
        local function CreateWindowSection()
            local section = CreateFrame("Frame", nil, page)
            section:SetWidth(420)
            section.views = {}
            local context = Context("SpellBook.Talents.Window", "WINDOW")
            for _, id in ipairs({ "shared.windowSurfaceAppearance",
                "shared.windowHeaderAppearance", "talents.pageBackground" }) do
                local view = NSkin:CreateOptionGroupView(section, id, "FULL", context())
                if view then section.views[#section.views + 1] = view end
            end
            function section:Refresh()
                local height = 0
                local current = context()
                for _, view in ipairs(self.views) do
                    view:SetContext(current)
                    view:ClearAllPoints()
                    view:SetPoint("TOPLEFT", 0, -height)
                    view:Show()
                    height = height + view:GetHeight() + 12
                end
                self:SetHeight(math.max(1, height))
                if selectedSection == 1 then ResizePage(self:GetHeight()) end
            end
            return section
        end

        sections[1] = CreateWindowSection()
        sections[2] = NSkin:CreateOptionGroupTabs(page, treeEntries, function(height)
            if selectedSection == 2 then ResizePage(height) end
        end)
        sections[3] = NSkin:CreateOptionGroupTabs(page, iconEntries, function(height)
            if selectedSection == 3 then ResizePage(height) end
        end)
        sections[4] = NSkin:CreateOptionGroupTabs(page, {
            { label = "Node ranks", groups = { "shared.textAppearance" },
                context = Context("SpellBook.Talents.NodeRankText", "TEXT") },
        }, function(height)
            if selectedSection == 4 then ResizePage(height) end
        end)
        sections[5] = NSkin:CreateOptionGroupTabs(page, {
            { label = "Arrow heads", groups = { "talents.edgeArrows" },
                context = Context("SpellBook.Talents.Window", "WINDOW") },
        }, function(height)
            if selectedSection == 5 then ResizePage(height) end
        end)
        local labels = { "Window", "Trees", "Icons", "Ranks", "Edges" }
        local function SelectSection(index)
            selectedSection = index
            for i, section in ipairs(sections) do section:SetShown(i == index) end
            local section = sections[index]
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", 0, -48)
            section:Refresh()
            for i, button in ipairs(sectionButtons) do
                NSkin:SkinFlatButton(button, labels[i])
                button:SetAlpha(i == index and 1 or 0.6)
            end
            ResizePage(section:GetHeight())
        end
        for i, label in ipairs(labels) do
            local button = CreateFrame("Button", nil, page)
            button:SetSize(84, 28)
            button:SetPoint("TOPLEFT", (i - 1) * 84, -8)
            button:SetScript("OnClick", function() SelectSection(i) end)
            sectionButtons[i] = button
        end
        function page:Refresh()
            SelectSection(selectedSection)
        end
        page.ApplyAppearance = page.Refresh
        page:Refresh()
        return page
    end,
})
