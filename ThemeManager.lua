-- cynth | addons/ThemeManager.lua
-- Drop-in replacement for LinoriaLib's ThemeManager

local ThemeManager = {
    Library = nil,
    _folder = 'cynth',
    BuiltInThemes = {
        ['Cynth (default)'] = {
            Accent  = Color3.fromRGB(176, 140, 240),
        },
        ['Blood'] = {
            Accent  = Color3.fromRGB(220, 50, 50),
        },
        ['Ocean'] = {
            Accent  = Color3.fromRGB(50, 160, 255),
        },
        ['Forest'] = {
            Accent  = Color3.fromRGB(80, 200, 120),
        },
        ['Gold'] = {
            Accent  = Color3.fromRGB(255, 195, 50),
        },
        ['Rose'] = {
            Accent  = Color3.fromRGB(255, 100, 180),
        },
        ['Mono'] = {
            Accent  = Color3.fromRGB(200, 200, 200),
        },
    },
}

function ThemeManager:SetLibrary(lib)
    self.Library = lib
end

function ThemeManager:SetFolder(folder)
    self._folder = folder
    pcall(function()
        if not isfolder(folder) then makefolder(folder) end
    end)
end

function ThemeManager:ApplyTheme(name)
    local lib   = self.Library
    local theme = self.BuiltInThemes[name]
    if not theme then return end
    if theme.Accent then lib:SetAccent(theme.Accent) end
    -- update the color picker if it exists
    if lib.Options.theme_accent_col then
        lib.Options.theme_accent_col:SetValueRGB(theme.Accent)
    end
end

function ThemeManager:SaveTheme(name)
    pcall(function()
        local lib  = self.Library
        local data = {
            Accent = lib.Theme.Accent:ToHex(),
            Font   = lib.FontPreset,
        }
        local json = game:GetService('HttpService'):JSONEncode(data)
        writefile(self._folder .. '/theme_' .. name .. '.json', json)
    end)
end

function ThemeManager:LoadTheme(name)
    pcall(function()
        local lib  = self.Library
        local path = self._folder .. '/theme_' .. name .. '.json'
        if not isfile(path) then return end
        local ok, data = pcall(function()
            return game:GetService('HttpService'):JSONDecode(readfile(path))
        end)
        if not ok or type(data) ~= 'table' then return end
        if data.Accent then lib:SetAccent(Color3.fromHex(data.Accent)) end
        if data.Font   then lib:SetFont(data.Font) end
    end)
end

local function buildSection(self, groupbox)
    local lib = self.Library

    -- accent color picker
    groupbox:AddLabel('Accent color'):AddColorPicker('theme_accent_col', {
        Default  = lib.Theme.Accent,
        Title    = 'Accent color',
        Callback = function(c) lib:SetAccent(c) end,
    })

    -- built-in theme presets
    local names = {}
    for n in pairs(self.BuiltInThemes) do names[#names+1] = n end
    table.sort(names)

    groupbox:AddDropdown('theme_preset', {
        Text    = 'Theme presets',
        Values  = names,
        Default = 1,
        Callback = function(v) if v then self:ApplyTheme(v) end end,
    })

    -- font selector
    groupbox:AddDropdown('theme_font', {
        Text    = 'Font',
        Values  = {'Code', 'Mono', 'Gotham', 'Jura', 'Josefin', 'Verdana', 'Pixel'},
        Default = lib.FontPreset,
        Callback = function(v) if v then lib:SetFont(v) end end,
    })

    -- opacity
    groupbox:AddSlider('theme_opacity', {
        Text    = 'Menu opacity',
        Min     = 30,
        Max     = 100,
        Default = 100,
        Suffix  = '%',
        Callback = function(v)
            lib._baseTrans = 1 - (v or 100)/100
            local m = lib._main
            if m and lib.Open then m.GroupTransparency = lib._baseTrans end
        end,
    })

    -- notifications
    groupbox:AddToggle('theme_notif', { Text = 'Notifications', Default = true, Callback = function(v) lib.NotifyEnabled = v end })
    groupbox:AddDropdown('theme_notifside', {
        Text     = 'Notification side',
        Values   = {'Up left','Up right','Down left','Down right'},
        Default  = 'Up right',
        Callback = function(v) if v then lib:SetNotifySide(v) end end,
    })
    groupbox:AddSlider('theme_notiftime', {
        Text     = 'Notification time',
        Min      = 1,
        Max      = 10,
        Default  = 3,
        Suffix   = 's',
        Callback = function(v) lib.NotifyTime = v end,
    })

    -- watermark items
    groupbox:AddToggle('theme_wm', { Text = 'Watermark', Default = false, Callback = function(v) lib:SetWatermarkVisibility(v) end })
    groupbox:AddToggle('theme_kbl', { Text = 'Keybind list', Default = false, Callback = function(v) lib.KeybindFrame.Visible = v end })
end

function ThemeManager:ApplyToGroupbox(groupbox)
    buildSection(self, groupbox)
end

function ThemeManager:ApplyToTab(tab)
    local gb = tab:AddLeftGroupbox('Themes')
    buildSection(self, gb)
end

return ThemeManager
