local _, NSkin = ...

NSkin.defaults = {
    statusBarTexture = "Interface\\Buttons\\WHITE8X8",
}

NSkin.media = {
    fallbackStatusBar = "Interface\\Buttons\\WHITE8X8",
}

NSkin.colors = {
    progressBarBackground = { 0.06, 0.06, 0.06, 0.90 },
    border = { 0, 0, 0, 1 },
}

function NSkin:GetStatusBarTexture()
    local texture = self:GetProfile().statusBarTexture
    if type(texture) ~= "string" or texture == "" then
        return self.defaults.statusBarTexture
    end
    return texture
end


function NSkin:SetStatusBarTexture(texture)
    if type(texture) ~= "string" then return false end

    texture = texture:match("^%s*(.-)%s*$")
    if texture == "" then return false end

    self:GetProfile().statusBarTexture = texture

    local progressBars = self.modules.BlizzardProgressBars
    if progressBars and progressBars.RefreshTexture then
        progressBars:RefreshTexture()
    end

    return true
end

function NSkin:ResetStatusBarTexture()
    self:GetProfile().statusBarTexture = nil

    local progressBars = self.modules.BlizzardProgressBars
    if progressBars and progressBars.RefreshTexture then
        progressBars:RefreshTexture()
    end
end
