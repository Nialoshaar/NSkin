local _, NSkin = ...

-- Immutable bundled design. Player changes belong in the active profile's
-- theme table and are resolved over these values at runtime.
NSkin.defaultTheme = {
    window = {
        background = { 0, 0, 0, 0.80 },
        border = { 0.45, 0.45, 0.45, 1 },
        borderSize = 1,

        header = {
            background = { 0.04, 0.04, 0.04, 0.95 },
            divider = { 0.45, 0.45, 0.45, 1 },
            height = 22,
        },
    },

    tab = {
        background = { 0.04, 0.04, 0.04, 0.90 },
        selectedBackground = { 0.16, 0.16, 0.16, 0.95 },
        border = { 0.45, 0.45, 0.45, 1 },
        text = { 1, 1, 1, 1 },
        hoverAlpha = 0.10,
    },
}
