-- cynth | addons/SaveManager.lua
-- Drop-in replacement for LinoriaLib's SaveManager

local SaveManager = {
    Library    = nil,
    _folder    = 'cynth/configs',
    _ignore    = {},
    _autoName  = nil,
}

function SaveManager:SetLibrary(lib)
    self.Library = lib
end

function SaveManager:SetFolder(folder)
    self._folder = folder
    self.Library._cfgDir = folder
    pcall(function()
        local parts = folder:split('/')
        local cur = ''
        for _, p in ipairs(parts) do
            cur = cur == '' and p or (cur..'/'..p)
            if not isfolder(cur) then makefolder(cur) end
        end
    end)
end

function SaveManager:IgnoreThemeSettings()
    if self.Library then self.Library:IgnoreThemeSettings() end
end

function SaveManager:SetIgnoreIndexes(t)
    for _, v in ipairs(t) do self._ignore[v] = true end
    if self.Library then self.Library:SetIgnoreIndexes(t) end
end

function SaveManager:Save(name)
    name = name or (self.Library.Options.cfg_list and self.Library.Options.cfg_list.Value)
    if not name or name == '' then
        self.Library:Notify('No config selected', 2); return
    end
    self.Library:CfgWrite(name)
    self.Library:Notify('Saved: ' .. name, 2)
end

function SaveManager:Load(name)
    name = name or (self.Library.Options.cfg_list and self.Library.Options.cfg_list.Value)
    if not name then self.Library:Notify('No config selected', 2); return end
    local s = self.Library:CfgRead(name)
    if s and self.Library:CfgApply(s) then
        self.Library:Notify('Loaded: ' .. name, 2)
    else
        self.Library:Notify("Couldn't load '" .. name .. "'", 2)
    end
end

function SaveManager:LoadAutoloadConfig()
    pcall(function()
        if isfile and isfile('cynth/autoload.txt') then
            local name = readfile('cynth/autoload.txt')
            local s = self.Library:CfgRead(name)
            if s then
                self.Library:CfgApply(s)
                self.Library:Notify('Auto-loaded: ' .. name, 2)
                if self.Library.Options.cfg_list then
                    self.Library.Options.cfg_list:SetValue(name)
                end
                if self.Library.Toggles.autoload then
                    self.Library.Toggles.autoload:SetValue(true)
                end
            end
        end
    end)
end

function SaveManager:BuildConfigSection(tab)
    local lib = self.Library
    local cf  = tab:AddLeftGroupbox('Configs', 245)

    cf:AddInput('cfg_name', { Text = 'Config name', Placeholder = 'new config name' })

    cf:AddDropdown('cfg_list', {
        Text   = 'Config list',
        Values = {},
    })

    local function cleanName(s)
        return (tostring(s or ''):gsub('[^%w%-_ ]',''):gsub('^%s+',''):gsub('%s+$',''))
    end

    local function refresh(sel)
        lib.Options.cfg_list:SetValues(lib:CfgList())
        if sel then lib.Options.cfg_list:SetValue(sel) end
    end

    cf:AddButton({ Text = 'Create', Func = function()
        local n = cleanName(lib.Options.cfg_name.Value)
        if n == '' then lib:Notify('Type a config name first', 2); return end
        if lib:CfgExists(n) then lib:Notify("'"..n.."' already exists", 2); return end
        lib:CfgWrite(n); refresh(n); lib:Notify('Created: '..n, 2)
    end}):AddButton({ Text = 'Load', Func = function()
        local n = lib.Options.cfg_list.Value
        if not n then lib:Notify('Select a config first', 2); return end
        local s = lib:CfgRead(n)
        if s and lib:CfgApply(s) then lib:Notify('Loaded: '..n, 2)
        else lib:Notify("Couldn't load '"..n.."'", 2) end
    end})

    cf:AddButton({ Text = 'Overwrite', DoubleClick = true, Func = function()
        local n = lib.Options.cfg_list.Value
        if not n then lib:Notify('Select a config first', 2); return end
        lib:CfgWrite(n); lib:Notify('Overwritten: '..n, 2)
    end}):AddButton({ Text = 'Delete', DoubleClick = true, Func = function()
        local n = lib.Options.cfg_list.Value
        if not n then lib:Notify('Select a config first', 2); return end
        lib:CfgDel(n); refresh(); lib:Notify('Deleted: '..n, 2)
    end})

    cf:AddButton('Refresh list', function() refresh(lib.Options.cfg_list.Value) end)

    cf:AddToggle('autoload', { Text = 'Auto load', Default = false, Callback = function(v)
        pcall(function()
            if v then
                local n = lib.Options.cfg_list and lib.Options.cfg_list.Value
                if n then writefile('cynth/autoload.txt', n) end
            elseif isfile and isfile('cynth/autoload.txt') then delfile('cynth/autoload.txt') end
        end)
    end})

    cf:AddToggle('saveexit', { Text = 'Save on exit', Default = false })

    lib:OnUnload(function()
        local n = lib.Options.cfg_list and lib.Options.cfg_list.Value
        if lib.Toggles.saveexit and lib.Toggles.saveexit.Value and n then
            lib:CfgWrite(n)
        end
    end)

    refresh()
end

return SaveManager
