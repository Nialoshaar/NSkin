local _, NSkin = ...

local MIN_SPACING = -30
local MAX_SPACING = 30

NSkin:RegisterOptionGroup("tabs.layout", {
    controls = {
        {
            type = "DROPDOWN",
            key = "alignment",
            label = "Alignment",
            values = {
                { value = "LEFT", label = "Left" },
                { value = "CENTER", label = "Center" },
                { value = "RIGHT", label = "Right" },
            },
        },
        {
            type = "SLIDER",
            key = "alongOffset",
            label = "X offset",
            min = -100,
            max = 100,
            step = 1,
            suffix = " px",
            order = 2,
        },
        {
            type = "SLIDER",
            key = "edgeOffset",
            label = "Y offset",
            min = -100,
            max = 100,
            step = 1,
            suffix = " px",
            order = 3,
        },
        { type = "RESET", label = "Reset Default", compactLabel = "Reset" },
    },
    get = function()
        return NSkin:GetBottomTabPlacement()
    end,
    set = function(_, placement)
        if NSkin:SetBottomTabPlacement(placement) then
            NSkin:NotifyOptionGroupChanged("tabs.layout")
        end
    end,
    reset = function()
        if NSkin:ResetBottomTabLayout() then
            NSkin:NotifyOptionGroupChanged("tabs.layout")
        end
    end,
})

local function BuildTabsOptions(optionsFrame)
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT",
        optionsFrame.NSkinContentLeft or 180, -102)
    title:SetText("Tabs")

    local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    label:SetText("Spacing")
    local valueText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", label, "RIGHT", 10, 0)

    local spacingSlider = NSkin:CreateOptionsSlider(page, {
        min = MIN_SPACING,
        max = MAX_SPACING,
        step = 1,
        onValueChanged = function(_, value)
            value = math.floor(value + 0.5)
            valueText:SetText(value .. " px")
            if not page.refreshing then NSkin:SetTabSpacing(value) end
        end,
    })
    spacingSlider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -22)

    local layoutView = NSkin:CreateOptionGroupView(page, "tabs.layout", "FULL", page)
    layoutView:SetPoint("TOPLEFT", spacingSlider, "BOTTOMLEFT", -8, -36)

    function page:ApplyTheme()
        if layoutView.ApplyTheme then layoutView:ApplyTheme() end
    end

    function page:Refresh()
        self.refreshing = true
        local spacing = NSkin:GetTabSpacing()
        spacingSlider:SetValue(spacing)
        valueText:SetText(spacing .. " px")
        self.refreshing = false
        layoutView:Refresh()
        self:ApplyTheme()
    end

    return page
end

NSkin:RegisterOptionsPage({
    key = "tabs",
    label = "Tabs",
    group = "shared",
    order = 10,
    builder = BuildTabsOptions,
})
