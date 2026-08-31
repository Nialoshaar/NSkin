# Options

The main options window owns shared appearance, profiles, module enablement,
module-wide settings, and defaults. Skinning Mode owns selected-element
placement, modes, and element appearance overrides; its movement grid is not a
second settings interface.

Page builders receive the shared scroll content parent. Build pages with
`NSkin:CreateOptionsPage`, add simple categories with
`NSkin:CreateOptionsSection`, and finish by calling `page:SetContentHeight` with
the real content height. Do not anchor page controls to the outer options frame.

Appearance resolves in this order:

```text
base appearance -> global component value -> window override -> element override
```

Use `GetAppearanceStyle`, `SetWindowAppearanceOverride`, and
`SetElementAppearanceOverride`. Reset APIs delete sparse overrides so the parent
layer becomes visible again.
