local _, NSkin = ...

NSkin.defaultModuleOptions = {
    SpellBook = {
        textSize = 16,
        minTextSize = 8,
        maxTextSize = 32,
        iconsPerRow = 3,
    },
}

-- Immutable bundled design. Player changes belong in the active profile's
-- theme table and are resolved over these values at runtime.
NSkin.defaultTheme = {
    typography = {
        font = "Fonts\\FRIZQT__.TTF",
        size = 12,
        outline = "",
    },

    accent = {
        enabled = false,
        color = { 0, 0.55, 0.82, 1 },
    },

    window = {
        background = { 0, 0, 0, 0.80 },
        backgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        borderSize = 1,

        header = {
            background = { 0.04, 0.04, 0.04, 0.95 },
            backgroundMode = "CUSTOM",
            divider = { 0.45, 0.45, 0.45, 1 },
            height = 22,
            matchBackground = false,
            text = { 1, 1, 1, 1 },
            textMode = "CUSTOM",
            textSize = 12,
            font = "Fonts\\FRIZQT__.TTF",
            outline = "",
            useGlobalTypography = true,
            fontMode = "GLOBAL",
            sizeMode = "GLOBAL",
            outlineMode = "GLOBAL",
        },
    },

    tab = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        backgroundMode = "CUSTOM",
        selectedBackground = { 0.16, 0.16, 0.16, 0.95 },
        selectedBackgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        text = { 1, 1, 1, 1 },
        textMode = "CUSTOM",
        hoverAlpha = 0.10,
        borderSize = 1,
        textSize = 12,
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "GLOBAL",
        outlineMode = "GLOBAL",
        spacing = 4,
        bottom = {
            edge = "BOTTOM",
            side = "OUTSIDE",
            anchor = "LEFT",
            offsetX = 0,
            offsetY = 0,
        },
    },

    button = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        border = { 0.45, 0.45, 0.45, 1 },
        text = { 1, 1, 1, 1 },
        hoverAlpha = 0.10,
    },

    icon = {
        border = { 0, 0, 0, 1 },
        crop = 0.06,
        qualityColor = true,
    },

    searchBox = {
        background = { 0, 0, 0, 0.75 },
        backgroundMode = "CUSTOM",
        border = { 0.45, 0.45, 0.45, 1 },
        borderMode = "CUSTOM",
        text = { 1, 1, 1, 1 },
        textMode = "CUSTOM",
        placeholderText = { 0.55, 0.55, 0.55, 1 },
        placeholderTextMode = "CUSTOM",
        borderSize = 1,
        textSize = 12,
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "GLOBAL",
        outlineMode = "GLOBAL",
        placeholderSize = 12,
        placeholderFont = "Fonts\\FRIZQT__.TTF",
        placeholderOutline = "",
        placeholderUseGlobalTypography = true,
        placeholderFontMode = "GLOBAL",
        placeholderSizeMode = "GLOBAL",
        placeholderOutlineMode = "GLOBAL",
        placeholderOffsetX = 0,
        placeholderOffsetY = 0,
    },

    sectionHeader = {
        text = { 1, 1, 1, 1 },
        textMode = "CUSTOM",
        textSize = 16,
        font = "Fonts\\FRIZQT__.TTF",
        outline = "",
        useGlobalTypography = true,
        fontMode = "GLOBAL",
        sizeMode = "GLOBAL",
        outlineMode = "GLOBAL",
        underlineVisible = true,
        underlineSize = 1,
        underline = { 0.45, 0.45, 0.45, 1 },
        underlineMode = "CUSTOM",
    },

    progressBar = {
        texture = "Interface\\Buttons\\WHITE8X8",
        height = 16,
        background = { 0.06, 0.06, 0.06, 0.90 },
        border = { 0, 0, 0, 1 },
        useCustomColor = false,
        color = { 1, 1, 1, 1 },
        useCustomTextColor = false,
        text = { 1, 1, 1, 1 },
    },

    encounterCard = {
        background = { 0, 0, 0, 1 },
        border = { 0, 0, 0, 1 },
        hover = { 1, 1, 1, 0.14 },
    },

    skinningMode = {
        highlight = { 0, 0.65, 1, 0.16 },
        hover = { 0, 0.65, 1, 0.28 },
        dropZone = { 0, 0.65, 1, 0.22 },
        activeDropZone = { 0, 0.65, 1, 0.55 },
        gridAlpha = 0.4,
        ghost = { 0, 0.65, 1, 0.35 },
    },

    options = {
        accent = { 0, 0.55, 0.82, 1 },
        selectedNavigation = { 0, 0.55, 0.82, 0.85 },
        enabledNavigationText = { 1, 1, 1, 1 },
        disabledNavigationText = { 0.45, 0.45, 0.45, 1 },
        listBackground = { 0.07, 0.10, 0.11, 0.94 },
        selectedListBackground = { 0.12, 0.20, 0.23, 0.94 },
        listHighlight = { 0.38, 0.42, 0.43, 0.75 },
    },
}
