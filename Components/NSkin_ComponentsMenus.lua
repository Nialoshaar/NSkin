local _, NSkin = ...

local COMPONENT_STATE = "components"
local SHARED_DROPDOWN_MENU_BOTTOM_INSET = 0
local sharedDropdownMenu = {
    owners = setmetatable({}, { __mode = "k" }),
    managerHooked = false,
    generateHooked = false,
    activeOwner = nil,
    activeMenu = nil,
    registeredTags = {},
    pendingTags = {},
}
local sharedDropdownMenuFontObjects = {}
local sharedDropdownMenuFontObjectCount = 0

local function GetDropdownMenuFontObject(fontString, textStyle)
    if not fontString or not fontString.GetFont or not _G.CreateFont then
        return nil
    end
    local sourceFont, sourceSize, sourceOutline = fontString:GetFont()
    local globalFont, resolvedSize, globalOutline = NSkin:GetResolvedTypography(
        textStyle or NSkin:GetStyle("text"))
    local font = globalFont or sourceFont
    local size = tonumber(resolvedSize) or tonumber(sourceSize)
    local outline = globalOutline ~= nil and globalOutline or sourceOutline
    if not font or not size then return nil end

    local key = table.concat({ font, tostring(size), tostring(outline or "") },
        "\031")
    local fontObject = sharedDropdownMenuFontObjects[key]
    if not fontObject then
        sharedDropdownMenuFontObjectCount = sharedDropdownMenuFontObjectCount + 1
        fontObject = _G.CreateFont(
            "NSkinSharedDropdownMenuFont" .. sharedDropdownMenuFontObjectCount)
        sharedDropdownMenuFontObjects[key] = fontObject
    end
    fontObject:SetFont(font, size, outline)
    return fontObject
end

local function SkinDropdownMenuDescription(frame, description)
    if not frame then return end
    local style = NSkin:GetStyle("text")
    local fontString = frame.fontString
    local textColor = NSkin:GetStyle("button").text
    local function SkinFontString(target)
        if not target then return end
        local fontObject = GetDropdownMenuFontObject(target, style)
        if fontObject and target.SetFontObject then
            target:SetFontObject(fontObject)
        end
        if target.SetTextColor then
            target:SetTextColor(unpack(textColor))
        end
    end
    SkinFontString(fontString)
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region ~= fontString and region.IsObjectType
                and region:IsObjectType("FontString")
            then
                SkinFontString(region)
            end
        end
    end

    local borderColor = NSkin:GetSharedBorderColor()
    if frame.highlight and frame.highlight.SetColorTexture then
        if frame.highlight.SetBlendMode then
            frame.highlight:SetBlendMode("BLEND")
        end
        frame.highlight:SetColorTexture(
            borderColor[1], borderColor[2], borderColor[3], 0.14)
    end

    -- Blizzard also builds selection rows with CreateButton + SetIsSelected,
    -- so the generated selector region is the reliable common signal here.
    local selector = description and description.IsSelected
        and frame.leftTexture1
    if selector then
        local selected = description.IsSelected and description:IsSelected()
        selector:SetTexture(NSkin.mediaPath
            .. (selected and "checkbox-checked.png"
                or "checkbox-unchecked.png"))
        selector:SetTexCoord(0, 1, 0, 1)
        selector:ClearAllPoints()
        selector:SetPoint("LEFT")
        selector:SetSize(16, 16)
        NSkin:ConfigureOwnedPixelTexture(selector)
        selector:SetVertexColor(unpack(selected
            and NSkin:GetAccentColor() or borderColor))
        if fontString then
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", selector, "RIGHT", 7, 0)
        end
    end
    if frame.leftTexture2 then frame.leftTexture2:Hide() end
end

local function AddDropdownMenuInitializers(_, rootDescription)
    local function Visit(description)
        if not description or not description.EnumerateElementDescriptions then
            return
        end
        for _, child in description:EnumerateElementDescriptions() do
            if child.AddInitializer then
                local elementDescription = child
                child:AddInitializer(function(frame)
                    SkinDropdownMenuDescription(frame, elementDescription)
                end)
            end
            Visit(child)
        end
    end
    Visit(rootDescription)
end

local function FlushPendingDropdownMenuTags()
    if not _G.Menu or type(_G.Menu.ModifyMenu) ~= "function" then
        return false
    end
    for tag in pairs(sharedDropdownMenu.pendingTags) do
        if not sharedDropdownMenu.registeredTags[tag] then
            _G.Menu.ModifyMenu(tag, AddDropdownMenuInitializers)
            sharedDropdownMenu.registeredTags[tag] = true
        end
        sharedDropdownMenu.pendingTags[tag] = nil
    end
    return true
end

function NSkin:RegisterDropdownMenuSkin(menus)
    if type(menus) == "string" then menus = { menus } end
    if type(menus) ~= "table" then
        FlushPendingDropdownMenuTags()
        return false
    end
    for _, tag in ipairs(menus) do
        if type(tag) == "string" and tag ~= ""
            and not sharedDropdownMenu.registeredTags[tag]
        then
            sharedDropdownMenu.pendingTags[tag] = true
        end
    end
    FlushPendingDropdownMenuTags()
    return true
end

local function HideSharedDropdownMenuBorder(menu)
    local data = menu and NSkin:GetSkinData(menu, COMPONENT_STATE, false)
    if data and data.sharedMenuBorderFrame then
        data.sharedMenuBorderFrame:Hide()
    end
end

local function TintSharedDropdownMenuTexture(texture, color)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    if texture.SetVertexColor then texture:SetVertexColor(unpack(color)) end
end

local function SkinSharedDropdownMenuEntry(frame, style)
    if not frame then return end
    local borderColor = style.border or NSkin:GetSharedBorderColor()
    local textStyle = style.textStyle or NSkin:GetStyle("text")
    local textColor = style.textColor or textStyle.color or textStyle.text
        or NSkin:GetStyle("button").text
    if frame.fontString and frame.fontString.SetTextColor then
        frame.fontString:SetTextColor(unpack(textColor))
    end
    if frame.highlight then
        if frame.highlight.SetBlendMode then frame.highlight:SetBlendMode("BLEND") end
        if frame.highlight.SetColorTexture then
            frame.highlight:SetColorTexture(
                borderColor[1], borderColor[2], borderColor[3], 0.14)
        end
    end
    TintSharedDropdownMenuTexture(frame.arrow, borderColor)
end

function NSkin:SkinDropdownMenu(menu, style)
    if not menu or not menu.IsShown or not menu:IsShown() then return false end
    style = style or {}
    local backgroundColor = style.background or self:GetStyle("window").background
    local borderColor = style.border or self:GetSharedBorderColor()
    local data = self:GetSkinData(menu, COMPONENT_STATE)

    if menu == sharedDropdownMenu.activeMenu
        and sharedDropdownMenu.activeOwner
        and not (menu.IsProtected and menu:IsProtected())
        and not (_G.InCombatLockdown and _G.InCombatLockdown())
    then
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", sharedDropdownMenu.activeOwner,
            "BOTTOMLEFT", 0, 0)
    end

    for _, region in ipairs({ menu:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            region:SetColorTexture(unpack(backgroundColor))
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
            region:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1,
                SHARED_DROPDOWN_MENU_BOTTOM_INSET + 1)
            region:SetAlpha(1)
            region:Show()
        end
    end
    if not data.sharedMenuBorderFrame then
        local borderFrame = CreateFrame("Frame", nil, UIParent)
        borderFrame:EnableMouse(false)
        data.sharedMenuBorderFrame = borderFrame
        self:CreatePixelBorder(borderFrame, "NSkinSharedDropdownMenuBorder",
            1, borderColor, false, borderFrame)
    end
    local borderFrame = data.sharedMenuBorderFrame
    borderFrame:ClearAllPoints()
    borderFrame:SetPoint("TOPLEFT", menu, "TOPLEFT")
    borderFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 0,
        SHARED_DROPDOWN_MENU_BOTTOM_INSET)
    borderFrame:SetFrameStrata(menu:GetFrameStrata())
    borderFrame:SetFrameLevel(menu:GetFrameLevel() + 1)
    local border = self:GetPixelBorder(borderFrame,
        "NSkinSharedDropdownMenuBorder")
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, 1)
    self:SetPixelBorderShown(border, true)
    borderFrame:Show()
    if not data.sharedMenuHideHooked and menu.HookScript then
        menu:HookScript("OnHide", HideSharedDropdownMenuBorder)
        data.sharedMenuHideHooked = true
    end
    if menu.GetChildren then
        for _, child in ipairs({ menu:GetChildren() }) do
            SkinSharedDropdownMenuEntry(child, style)
        end
    end
    return true
end

function NSkin:SkinDropdownArrowButton(button, color)
    if not button then return false end
    local data = self:GetSkinData(button, COMPONENT_STATE)
    self:HideTextureRegions(button, data.sharedDropdownArrow)
    for _, child in ipairs({ button:GetChildren() }) do
        self:HideTextureRegions(child)
    end
    if not data.sharedDropdownArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("CENTER", button, "CENTER", 0, -1)
        arrow:SetTexture(self.mediaPath .. "angle-small-down.png")
        self:ConfigureOwnedPixelTexture(arrow)
        data.sharedDropdownArrow = arrow
    end
    data.sharedDropdownArrow:SetVertexColor(unpack(color or self:GetSharedBorderColor()))
    data.sharedDropdownArrow:SetAlpha(button.IsEnabled and button:IsEnabled() and 1 or 0.4)
    data.sharedDropdownArrow:Show()
    return true
end

local function GetRegisteredDropdownMenuStyle(dropdown)
    local provider = dropdown and sharedDropdownMenu.owners[dropdown]
    return type(provider) == "function" and provider() or provider
end

local function SkinRegisteredDropdownMenu(dropdown, menu)
    if not dropdown or not sharedDropdownMenu.owners[dropdown]
        or not menu or not menu.IsShown or not menu:IsShown()
    then return false end
    sharedDropdownMenu.activeOwner = dropdown
    sharedDropdownMenu.activeMenu = menu
    return NSkin:SkinDropdownMenu(
        menu, GetRegisteredDropdownMenuStyle(dropdown))
end

local function HookSharedDropdownMenuManager()
    if not _G.hooksecurefunc then return false end
    if not sharedDropdownMenu.managerHooked and _G.Menu
        and type(_G.Menu.GetManager) == "function"
    then
        local manager = _G.Menu.GetManager()
        if manager and type(manager.OpenMenu) == "function" then
            _G.hooksecurefunc(manager, "OpenMenu", function(self, ownerRegion)
                if not sharedDropdownMenu.owners[ownerRegion] then return end
                local menu = self:GetOpenMenu()
                if not menu then return end
                sharedDropdownMenu.activeOwner = ownerRegion
                sharedDropdownMenu.activeMenu = menu
                C_Timer.After(0, function()
                    SkinRegisteredDropdownMenu(ownerRegion, menu)
                end)
            end)
            sharedDropdownMenu.managerHooked = true
        end
    end
    if not sharedDropdownMenu.generateHooked and _G.MenuStyle1Mixin
        and type(_G.MenuStyle1Mixin.Generate) == "function"
    then
        _G.hooksecurefunc(_G.MenuStyle1Mixin, "Generate", function(menu)
            local owner = sharedDropdownMenu.activeOwner
            local root = sharedDropdownMenu.activeMenu
            if not owner or not root or menu == root or not root:IsShown() then
                return
            end
            C_Timer.After(0, function()
                if root:IsShown() and menu:IsShown() then
                    NSkin:SkinDropdownMenu(
                        menu, GetRegisteredDropdownMenuStyle(owner))
                end
            end)
        end)
        sharedDropdownMenu.generateHooked = true
    end
    return sharedDropdownMenu.managerHooked
end

function NSkin:HookDropdownMenuSkin(dropdown, styleProvider)
    if not dropdown then return false end
    local data = self:GetSkinData(dropdown, COMPONENT_STATE)
    data.sharedMenuStyleProvider = styleProvider
    sharedDropdownMenu.owners[dropdown] = styleProvider
    HookSharedDropdownMenuManager()
    if not _G.hooksecurefunc then return false end
    if data.sharedMenuSkinHooked then return true end
    if type(dropdown.OnMenuOpened) == "function" then
        _G.hooksecurefunc(dropdown, "OnMenuOpened", function(_, menu)
            menu = menu or dropdown.menu
            C_Timer.After(0, function()
                SkinRegisteredDropdownMenu(dropdown, menu)
            end)
        end)
    end
    if type(dropdown.OnMenuClosed) == "function" then
        _G.hooksecurefunc(dropdown, "OnMenuClosed", function(_, menu)
            menu = menu or dropdown.menu
            HideSharedDropdownMenuBorder(menu)
            if sharedDropdownMenu.activeOwner == dropdown then
                sharedDropdownMenu.activeOwner = nil
                sharedDropdownMenu.activeMenu = nil
            end
        end)
    end
    data.sharedMenuSkinHooked = true
    return true
end
