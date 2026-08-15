local _, NSkin = ...

NSkin.defaults = {
    statusBarTexture = "Interface\\AddOns\\NaowhUI_Media\\Shared\\Textures\\NaowhGradient.tga",
}

NSkin.media = {
    fallbackStatusBar = "Interface\\Buttons\\WHITE8X8",
}

NSkin.colors = {
    progressBarBackground = { 0.06, 0.06, 0.06, 0.90 },
    border = { 0, 0, 0, 1 },
}

local function GetDatabase()
    _G.NSkinDB = _G.NSkinDB or {}
    return _G.NSkinDB
end

function NSkin:GetStatusBarTexture()
    local texture = GetDatabase().statusBarTexture
    if type(texture) ~= "string" or texture == "" then
        return self.defaults.statusBarTexture
    end
    return texture
end


function NSkin:SetStatusBarTexture(texture)
    if type(texture) ~= "string" then return false end

    texture = texture:match("^%s*(.-)%s*$")
    if texture == "" then return false end

    GetDatabase().statusBarTexture = texture

    local progressBars = self.modules.BlizzardProgressBars
    if progressBars and progressBars.RefreshTexture then
        progressBars:RefreshTexture()
    end

    return true
end

function NSkin:ResetStatusBarTexture()
    GetDatabase().statusBarTexture = nil

    local progressBars = self.modules.BlizzardProgressBars
    if progressBars and progressBars.RefreshTexture then
        progressBars:RefreshTexture()
    end
end
