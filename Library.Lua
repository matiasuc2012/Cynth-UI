-- cynth | Library.lua
-- LinoriaLib-compatible API with cynth visuals
-- Drop-in replacement: load this where you'd load LinoriaLib

local Players        = game:GetService('Players')
local UIS            = game:GetService('UserInputService')
local TS             = game:GetService('TweenService')
local RS             = game:GetService('RunService')
local TextService    = game:GetService('TextService')
local HttpService    = game:GetService('HttpService')
local GuiService     = game:GetService('GuiService')

local LP = Players.LocalPlayer

-- ============================================================
--  Core library table
-- ============================================================
local Library = {
    Flags          = {},
    Open           = true,
    ToggleKey      = Enum.KeyCode.RightShift,
    ToggleKeybind  = nil,
    Binds          = {},
    Unloaded       = false,
    NotifyEnabled  = true,
    NotifyTime     = 3,
    NotifySide     = 'Up right',
    _unload        = {},
    _pickers       = {},
    _listening     = false,
    _popHit        = 0,
    _mem           = {},
}

local Toggles = {}
local Options  = {}
Library.Toggles = Toggles
Library.Options  = Options

pcall(function()
    local e = getgenv and getgenv() or _G
    e.Toggles  = Toggles
    e.Options   = Options
    e.Library   = Library
    shared.Library = Library
end)

-- ============================================================
--  Theme
-- ============================================================
Library.Theme = {
    Accent      = Color3.fromRGB(176, 140, 240),
    Bar         = Color3.fromRGB(150, 112, 205),
    Panel       = Color3.fromRGB(18,  16,  20),
    Panel2      = Color3.fromRGB(26,  24,  30),
    Border      = Color3.fromRGB(46,  42,  52),
    Text        = Color3.fromRGB(235, 235, 240),
    Dim         = Color3.fromRGB(150, 148, 158),
    Off         = Color3.fromRGB(40,  38,  46),
    PanelHi     = Color3.fromRGB(31,  28,  37),
}
local T = Library.Theme

local Themed = {}
local function Th(fn) fn(); table.insert(Themed, fn) end
function Library:SetAccent(c)
    T.Accent = c
    T.Bar    = c:Lerp(Color3.new(0,0,0), 0.2)
    for _, f in ipairs(Themed) do pcall(f) end
end

-- ============================================================
--  Font
-- ============================================================
local FontPresets = {
    Code    = { Enum.Font.Code,         Enum.Font.Code,         13 },
    Mono    = { Enum.Font.RobotoMono,   Enum.Font.RobotoMono,   13 },
    Gotham  = { Enum.Font.GothamMedium, Enum.Font.GothamBold,   13 },
    Jura    = { Enum.Font.Jura,         Enum.Font.Jura,         14 },
    Josefin = { Enum.Font.JosefinSans,  Enum.Font.JosefinSans,  14 },
    Verdana = { Enum.Font.Arial,        Enum.Font.ArialBold,    13 },
    Pixel   = { Enum.Font.Arcade,       Enum.Font.Arcade,       12 },
}
Library.FontPreset = 'Code'
Library.Font, Library.FontB, Library.FontSize = table.unpack(FontPresets['Code'])

function Library:SetFont(name)
    local pr = FontPresets[name]; if not pr then return end
    Library.FontPreset = name
    Library.Font, Library.FontB, Library.FontSize = pr[1], pr[2], pr[3]
    for _, d in ipairs(Gui:GetDescendants()) do
        if d:IsA('TextLabel') or d:IsA('TextButton') or d:IsA('TextBox') then
            if d:GetAttribute('b') then d.Font = Library.FontB
            else d.Font = Library.Font end
            d.TextSize = Library.FontSize
        end
    end
end

-- ============================================================
--  ScreenGui
-- ============================================================
local Gui = Instance.new('ScreenGui')
Gui.Name           = 'cynth_ui'
Gui.ResetOnSpawn   = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() Gui.ScreenInsets = Enum.ScreenInsets.None end)
Gui.Parent = (gethui and gethui()) or game:GetService('CoreGui')
Library.ScreenGui = Gui

-- origin probe
local Probe = Instance.new('Frame')
Probe.Size, Probe.BackgroundTransparency, Probe.BorderSizePixel = UDim2.new(), 1, 0
Probe.Parent = Gui
local function Origin() return Probe.AbsolutePosition end

local function ScreenSize()
    local s = Gui.AbsoluteSize
    if s.X < 200 then local c = workspace.CurrentCamera; if c then s = c.ViewportSize end end
    return s
end

-- ============================================================
--  Helpers
-- ============================================================
local function New(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function Stroke(p, c, th)
    return New('UIStroke', { Color = c or T.Border, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local function Round(p, r)
    New('UICorner', { CornerRadius = UDim.new(0, r or 4) }, p)
end

local function Shade(p, top, bot, rot)
    local k = 0.45
    top, bot = 1-(1-top)*k, 1-(1-bot)*k
    New('UIGradient', {
        Color    = ColorSequence.new(Color3.new(top,top,top), Color3.new(bot,bot,bot)),
        Rotation = rot or 90,
    }, p)
end

local function GradC(p, c1, c2, rot, t1, t2)
    p.BackgroundColor3 = Color3.new(1,1,1)
    return New('UIGradient', {
        Color        = ColorSequence.new(c1, c2),
        Rotation     = rot or 0,
        Transparency = NumberSequence.new(t1 or 0, t2 or 0),
    }, p)
end

local function MkText(parent, txt, opts)
    opts = opts or {}
    local l = New('TextLabel', {
        BackgroundTransparency = 1,
        Text               = txt,
        Font               = opts.Bold and Library.FontB or Library.Font,
        TextSize           = opts.Size or Library.FontSize,
        TextColor3         = opts.Color or T.Text,
        TextXAlignment     = opts.Align or Enum.TextXAlignment.Left,
        Size               = opts.S or UDim2.new(1,0,1,0),
        Position           = opts.P or UDim2.new(),
        RichText           = true,
        TextWrapped        = opts.Wrap or false,
    }, parent)
    if opts.Bold then l:SetAttribute('b', true) end
    return l
end

local function Hover(b, from, to)
    local ti = TweenInfo.new(0.12)
    b.MouseEnter:Connect(function()  TS:Create(b, ti, { BackgroundColor3 = to   }):Play() end)
    b.MouseLeave:Connect(function()  TS:Create(b, ti, { BackgroundColor3 = from }):Play() end)
end

local function IsClick(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end

local function KeyIs(i, key)
    if not key then return false end
    if #key == 3 and key:sub(1,2) == 'MB' then
        return i.UserInputType.Name == 'MouseButton'..key:sub(3)
    end
    return i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name == key
end

-- ============================================================
--  Animated gradient labels
-- ============================================================
local GradLabels = {}
local function AnimGrad(lbl)
    if lbl:IsA('TextLabel') or lbl:IsA('TextButton') then lbl.TextColor3 = Color3.new(1,1,1) end
    local g = New('UIGradient', {}, lbl)
    table.insert(GradLabels, g)
    return g
end

local SpinGrads = {}
local function SpinGrad(f)
    local g = New('UIGradient', {}, f)
    table.insert(SpinGrads, g)
    return g
end

local gradConn = RS.RenderStepped:Connect(function()
    local t = os.clock()
    local a = T.Accent
    local lo = a:Lerp(Color3.new(0,0,0), 0.25)
    local hi = a:Lerp(Color3.new(1,1,1), 0.7)
    local pts = {}
    for i = 0,6 do
        local x = i/6
        local k = (math.sin((x*2 - t*1.2)*math.pi)+1)/2
        pts[#pts+1] = ColorSequenceKeypoint.new(x, lo:Lerp(hi, k))
    end
    local seq = ColorSequence.new(pts)
    local spinSeq = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   lo),
        ColorSequenceKeypoint.new(0.3, lo),
        ColorSequenceKeypoint.new(0.5, hi),
        ColorSequenceKeypoint.new(0.7, lo),
        ColorSequenceKeypoint.new(1,   lo),
    })
    local rot = (t*200) % 360
    for i = #SpinGrads, 1, -1 do
        local g = SpinGrads[i]
        if g.Parent then g.Color, g.Rotation = spinSeq, rot
        else table.remove(SpinGrads, i) end
    end
    for i = #GradLabels, 1, -1 do
        local g = GradLabels[i]
        if g.Parent then g.Color = seq
        else table.remove(GradLabels, i) end
    end
end)
Library:OnUnload = function(f) table.insert(Library._unload, f) end -- reassigned below

-- ============================================================
--  Drag
-- ============================================================
local function Drag(handle, target)
    local d, s, sp
    handle.InputBegan:Connect(function(i)
        if IsClick(i) then d, s, sp = true, i.Position, target.Position end
    end)
    UIS.InputEnded:Connect(function(i)
        if IsClick(i) then d = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dl = i.Position - s
            target.Position = UDim2.new(sp.X.Scale, sp.X.Offset+dl.X, sp.Y.Scale, sp.Y.Offset+dl.Y)
        end
    end)
end

local function PopDrag(handle, target)
    local d, s, sp
    local c0 = handle.InputBegan:Connect(function(i)
        if IsClick(i) then d, s, sp = true, i.Position, target.Position end
    end)
    local c1 = UIS.InputEnded:Connect(function(i)
        if IsClick(i) then d = false end
    end)
    local c2 = UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dl = i.Position - s
            local sz, ts = ScreenSize(), target.AbsoluteSize
            target.Position = UDim2.fromOffset(
                math.clamp(sp.X.Offset+dl.X, 0, math.max(sz.X-ts.X, 0)),
                math.clamp(sp.Y.Offset+dl.Y, 0, math.max(sz.Y-ts.Y, 0))
            )
            target:SetAttribute('moved', true)
        end
    end)
    target.Destroying:Connect(function() c0:Disconnect(); c1:Disconnect(); c2:Disconnect() end)
end

-- ============================================================
--  Popups
-- ============================================================
local popups = {}
Library._popHit = 0
local function MarkPop() Library._popHit = tick() end
local SyncBlocker = function() end

local function ClosePopup(top)
    local function kill(p)
        if p:GetAttribute('keep') then p.Parent = nil else p:Destroy() end
    end
    if top then
        local p = table.remove(popups)
        if p then kill(p) end
        SyncBlocker(); return
    end
    for _, p in ipairs(popups) do kill(p) end
    popups = {}
    SyncBlocker()
end

local function OpenPopup(anchor, size, above)
    ClosePopup()
    local scr, org = ScreenSize(), Origin()
    local ax = anchor.AbsolutePosition.X - org.X
    local ay = anchor.AbsolutePosition.Y - org.Y
    local ah = anchor.AbsoluteSize.Y
    local ph = size.Y.Offset
    local x = math.clamp(ax, 4, math.max(scr.X - size.X.Offset - 4, 4))
    local y
    if above then
        y = ay - ph - 2
        if y < 4 then y = ay + ah + 2 end
    else
        y = ay + ah + 2
        if y + ph > scr.Y - 4 then y = math.max(ay - ph - 2, 4) end
    end
    local f = New('Frame', {
        Size             = size,
        BackgroundColor3 = T.Panel2,
        BorderSizePixel  = 0,
        ZIndex           = 50,
        Active           = true,
        Position         = UDim2.fromOffset(x, y),
    }, Gui)
    Stroke(f); Shade(f, 1, 0.7); Round(f, 4)
    f.InputBegan:Connect(function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then MarkPop() end
    end)
    table.insert(popups, f)
    SyncBlocker()
    return f
end

local Blocker = New('TextButton', {
    Name               = 'Blocker',
    Size               = UDim2.new(1,0,1,0),
    BackgroundTransparency = 1,
    Text               = '',
    AutoButtonColor    = false,
    Active             = true,
    Visible            = false,
    ZIndex             = 45,
}, Gui)
Blocker.InputBegan:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
        task.delay(0.02, function()
            if tick() - Library._popHit < 0.15 then return end
            Library._lastClosed = { p = popups[1], t = tick() }
            ClosePopup()
        end)
    end
end)
SyncBlocker = function() Blocker.Visible = #popups > 0 end

-- ============================================================
--  Watermark
-- ============================================================
local WM = New('Frame', {
    Size                 = UDim2.new(0,0,0,26),
    AutomaticSize        = Enum.AutomaticSize.X,
    Position             = UDim2.new(1,-250,0,10),
    BackgroundColor3     = T.PanelHi,
    BackgroundTransparency = 0.05,
    BorderSizePixel      = 0,
    Active               = true,
    Visible              = false,
}, Gui)
Stroke(WM); Drag(WM, WM); Shade(WM, 1, 0.6); Round(WM, 4)
New('UIPadding', { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, WM)
local WMC = New('Frame', { Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, WM)
New('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, WMC)
local WMTitle = MkText(WMC, 'cynth', { Bold = true, S = UDim2.new(0,0,1,0) })
WMTitle.AutomaticSize = Enum.AutomaticSize.X
AnimGrad(WMTitle)
local WMExtra = MkText(WMC, '', { S = UDim2.new(0,0,1,0) })
WMExtra.AutomaticSize = Enum.AutomaticSize.X
WMExtra.LayoutOrder = 1

Library.Watermark = WM

function Library:SetWatermarkVisibility(v) WM.Visible = v end
function Library:SetWatermark(txt)
    WMExtra.Text = ' | ' .. txt
    WM.Visible   = true
end

-- ============================================================
--  Keybind HUD
-- ============================================================
local KBL = New('Frame', {
    Size                 = UDim2.new(0,190,0,0),
    AutomaticSize        = Enum.AutomaticSize.Y,
    Position             = UDim2.new(1,-230,0.5,30),
    BackgroundColor3     = T.PanelHi,
    BackgroundTransparency = 0.05,
    BorderSizePixel      = 0,
    Active               = true,
    Visible              = false,
}, Gui)
Stroke(KBL); Shade(KBL, 1, 0.6); Round(KBL, 4)
New('UIPadding', { PaddingBottom = UDim.new(0,6), PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), PaddingTop = UDim.new(0,4) }, KBL)
New('UIListLayout', { Padding = UDim.new(0,2), SortOrder = Enum.SortOrder.LayoutOrder }, KBL)
local KBLTitle = MkText(KBL, 'Keybinds', { Bold = true, S = UDim2.new(0,0,0,18) })
KBLTitle.AutomaticSize, KBLTitle.LayoutOrder = Enum.AutomaticSize.X, -2
AnimGrad(KBLTitle)
local KBLDiv = New('Frame', { Size = UDim2.new(1,0,0,1), BorderSizePixel = 0, LayoutOrder = -1 }, KBL)
local kblDg = GradC(KBLDiv, T.Bar, T.Border, 0)
Th(function() kblDg.Color = ColorSequence.new(T.Bar, T.Border) end)
Drag(KBL, KBL)

Library.KeybindFrame     = KBL
Library.KeybindContainer = KBL -- compat alias

function Library:RefreshKeybinds()
    for _, c in ipairs(KBL:GetChildren()) do
        if c:GetAttribute('kbrow') then c:Destroy() end
    end
    local n = 0
    for _, k in ipairs(Library._pickers) do
        if k.Value and not k.NoUI and k:GetState() then
            n += 1
            local r = New('Frame', { Size = UDim2.new(1,0,0,19), BackgroundTransparency = 1, LayoutOrder = n }, KBL)
            r:SetAttribute('kbrow', true)
            MkText(r, k.Text .. ' (' .. k.Mode .. ')', { S = UDim2.new(.65,0,1,0) })
            MkText(r, '[' .. k.Value .. ']', { S = UDim2.new(.35,0,1,0), P = UDim2.new(.65,0,0,0), Align = Enum.TextXAlignment.Right, Color = T.Dim })
        end
    end
end

-- ============================================================
--  Notifications
-- ============================================================
local NH = New('Frame', { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 200 }, Gui)
local NL = New('UIListLayout', { Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder }, NH)
local NP = New('UIPadding', {}, NH)
local Sides = {
    ['Up left']    = { h = Enum.HorizontalAlignment.Left,  v = Enum.VerticalAlignment.Top,    x = -1, pt = 66, pb = 0,  pl = 10, pr = 0  },
    ['Up right']   = { h = Enum.HorizontalAlignment.Right, v = Enum.VerticalAlignment.Top,    x = 1,  pt = 44, pb = 0,  pl = 0,  pr = 10 },
    ['Down left']  = { h = Enum.HorizontalAlignment.Left,  v = Enum.VerticalAlignment.Bottom, x = -1, pt = 0,  pb = 10, pl = 10, pr = 0  },
    ['Down right'] = { h = Enum.HorizontalAlignment.Right, v = Enum.VerticalAlignment.Bottom, x = 1,  pt = 0,  pb = 10, pl = 0,  pr = 10 },
}
function Library:SetNotifySide(s)
    local d = Sides[s]; if not d then return end
    Library.NotifySide = s
    NL.HorizontalAlignment, NL.VerticalAlignment = d.h, d.v
    NP.PaddingTop, NP.PaddingBottom, NP.PaddingLeft, NP.PaddingRight =
        UDim.new(0,d.pt), UDim.new(0,d.pb), UDim.new(0,d.pl), UDim.new(0,d.pr)
end
Library:SetNotifySide('Up right')

local nCount = 0
function Library:Notify(txt, dur)
    if not Library.NotifyEnabled or Library.Unloaded then return end
    dur = dur or Library.NotifyTime
    nCount += 1
    local dir  = Sides[Library.NotifySide].x
    local plain = tostring(txt):gsub('<[^>]+>', '')
    local w = TextService:GetTextSize(plain, Library.FontSize, Library.Font, Vector2.new(400,100)).X + 26
    local h = 28
    local slot = New('Frame', { Size = UDim2.new(0,w,0,0), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = nCount }, NH)
    local hidden = UDim2.new(0, dir*(w+4), 0, 0)
    local n = New('Frame', { Size = UDim2.new(1,0,0,h), Position = hidden, BackgroundColor3 = T.PanelHi, BorderSizePixel = 0 }, slot)
    Stroke(n); Shade(n, 1, 0.6); Round(n, 4)
    MkText(n, txt, { P = UDim2.new(0,10,0,0), S = UDim2.new(1,-20,1,-2) })
    local line = New('Frame', { Size = UDim2.new(1,0,0,2), Position = UDim2.new(0,0,1,-2), BackgroundColor3 = T.Accent, BorderSizePixel = 0 }, n)
    TS:Create(slot, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0,w,0,h) }):Play()
    TS:Create(n,    TweenInfo.new(0.4,  Enum.EasingStyle.Quint,Enum.EasingDirection.Out), { Position = UDim2.new() }):Play()
    TS:Create(line, TweenInfo.new(dur,  Enum.EasingStyle.Linear), { Size = UDim2.new(0,0,0,2) }):Play()
    task.delay(dur, function()
        if not n.Parent then return end
        local t1 = TS:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = hidden })
        t1:Play(); t1.Completed:Wait()
        if not slot.Parent then return end
        local t2 = TS:Create(slot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.new(0,w,0,0) })
        t2:Play(); t2.Completed:Wait()
        slot:Destroy()
    end)
end
Library.notify = Library.Notify

-- ============================================================
--  Config system
-- ============================================================
local CFG_DIR = 'cynth/configs'
local FS = type(writefile)=='function' and type(readfile)=='function'
        and type(isfolder)=='function'  and type(makefolder)=='function'
        and type(listfiles)=='function'
pcall(function()
    if FS then
        if not isfolder('cynth')    then makefolder('cynth')    end
        if not isfolder(CFG_DIR)    then makefolder(CFG_DIR)    end
    end
end)

local CfgIgnore = {}
function Library:SetIgnoreIndexes(t) for _, v in ipairs(t) do CfgIgnore[v] = true end end
function Library:IgnoreThemeSettings()
    for _, v in ipairs({'ui_accent_col','ui_font','ui_dpi','ui_notif','ui_notifside','ui_wm','ui_wm_items','ui_kbl','ui_tv'}) do
        CfgIgnore[v] = true
    end
end

function Library:CfgList()
    local t = {}
    if FS then pcall(function()
        for _, f in ipairs(listfiles(CFG_DIR)) do
            local n = f:match('([^/\\]+)%.json$'); if n then t[#t+1] = n end
        end
    end)
    else for n in pairs(Library._mem) do t[#t+1] = n end end
    table.sort(t); return t
end

function Library:CfgEncode()
    local tg, op = {}, {}
    for id, o in pairs(Toggles) do if not CfgIgnore[id] then tg[id] = o.Value end end
    for id, o in pairs(Options) do
        if not CfgIgnore[id] then
            local tp = o.Type
            if tp == 'Slider' or tp == 'Input' or tp == 'Dropdown' then
                op[id] = { v = o.Value }
            elseif tp == 'ColorPicker' then
                op[id] = { h = o.Hue, s = o.Sat, b = o.Vib, t = o.Transparency }
            elseif tp == 'KeyPicker' then
                op[id] = { k = o.Value or '', m = o.Mode }
            end
        end
    end
    return HttpService:JSONEncode({ Toggles = tg, Options = op })
end

function Library:CfgApply(json)
    local ok, d = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(d) ~= 'table' then return false end
    for id, v in pairs(d.Toggles or {}) do
        local o = Toggles[id]; if o then pcall(function() o:SetValue(v) end) end
    end
    for id, e in pairs(d.Options or {}) do
        local o = Options[id]
        if o and type(e) == 'table' then pcall(function()
            if     o.Type == 'Slider'      then if e.v ~= nil then o:SetValue(e.v) end
            elseif o.Type == 'Input' or o.Type == 'Dropdown' then o:SetValue(e.v)
            elseif o.Type == 'ColorPicker' then o:SetValue({e.h,e.s,e.b}, e.t)
            elseif o.Type == 'KeyPicker'   then o:SetValue({e.k~='' and e.k or nil, e.m}) end
        end) end
    end
    Library:RefreshKeybinds()
    return true
end

function Library:CfgWrite(name)
    local s = Library:CfgEncode()
    if FS then writefile(CFG_DIR..'/'..name..'.json', s) else Library._mem[name] = s end
end
function Library:CfgRead(name)
    if FS then local ok, s = pcall(readfile, CFG_DIR..'/'..name..'.json'); return ok and s or nil end
    return Library._mem[name]
end
function Library:CfgDel(name)
    if FS then pcall(function() delfile(CFG_DIR..'/'..name..'.json') end) else Library._mem[name] = nil end
end
function Library:CfgExists(name)
    for _, n in ipairs(Library:CfgList()) do if n == name then return true end end return false
end

-- ============================================================
--  Toggle/Changeable helpers
-- ============================================================
local function Changeable(o)
    o._changed = {}
    function o:OnChanged(f) table.insert(o._changed, f); f(o.Value); return o end
end
local function Fire(o, cb)
    if cb then task.spawn(cb, o.Value) end
    for _, f in ipairs(o._changed) do task.spawn(f, o.Value) end
end

-- ============================================================
--  Element helper: right-side widget placement
-- ============================================================
local function Place(row, w)
    local r = row:GetAttribute('rx') or -4
    row:SetAttribute('rx', r - w - 6)
    return r - w
end

-- ============================================================
--  ColorPicker widget
-- ============================================================
local function KP(t,r,g,b) return ColorSequenceKeypoint.new(t, Color3.fromRGB(r,g,b)) end

local function AddColorPicker(row, idx, info)
    info = info or {}
    local alpha = info.Transparency ~= nil
    local c0 = info.Default or Color3.new(1,1,1)
    local P = { Type='ColorPicker', Title=info.Title or idx, Value=c0, Transparency=info.Transparency or 0 }
    Changeable(P)
    P.Hue, P.Sat, P.Vib = c0:ToHSV()

    local left = Place(row, 20)
    local b = New('TextButton', {
        Size = UDim2.new(0,20,0,10), Position = UDim2.new(1,left,0.5,-5),
        BackgroundColor3 = c0, Text = '', BorderSizePixel = 0, AutoButtonColor = false,
    }, row)
    Round(b, 3)
    local fill = b
    if alpha then
        b.BackgroundColor3 = Color3.fromRGB(150,150,150)
        b.ClipsDescendants = true
        fill = New('Frame', { Size=UDim2.new(1,0,1,0), BackgroundColor3=c0, BackgroundTransparency=P.Transparency, BorderSizePixel=0 }, b)
    end
    Shade(fill, 1, 0.7)

    local function refresh(silent)
        P.Value = Color3.fromHSV(P.Hue, P.Sat, P.Vib)
        fill.BackgroundColor3 = P.Value
        if alpha then fill.BackgroundTransparency = P.Transparency end
        if P._ui then P._ui() end
        if not silent then Fire(P, info.Callback) end
    end
    function P:SetValue(hsv, tr)
        P.Hue,P.Sat,P.Vib = hsv[1],hsv[2],hsv[3]
        if tr then P.Transparency = tr end
        refresh()
    end
    function P:SetValueRGB(c, tr)
        P.Hue,P.Sat,P.Vib = c:ToHSV()
        if tr then P.Transparency = tr end
        refresh()
    end
    refresh(true)

    b.MouseButton1Click:Connect(function()
        local PW, ph = 186, (alpha and 150 or 134) + 18
        local p = OpenPopup(b, UDim2.new(0,PW,0,ph))
        local scr, org = ScreenSize(), Origin()
        local bx = b.AbsolutePosition.X - org.X
        local by = b.AbsolutePosition.Y - org.Y
        local px = bx + b.AbsoluteSize.X + 8
        if px + PW > scr.X - 4 then px = bx - PW - 8 end
        p.Position = UDim2.fromOffset(
            math.clamp(px, 4, math.max(scr.X-PW-4,4)),
            math.clamp(by-8, 4, math.max(scr.Y-ph-4,4))
        )
        local hdr = New('Frame', { Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, BorderSizePixel=0, Active=true, ZIndex=51 }, p)
        MkText(hdr, tostring(P.Title), { Bold=true, P=UDim2.new(0,8,0,0), S=UDim2.new(1,-8,1,0), Color=T.Accent, Size=12 })
        New('Frame', { Size=UDim2.new(1,-16,0,1), Position=UDim2.new(0,8,1,-1), BackgroundColor3=T.Border, BorderSizePixel=0, ZIndex=51 }, hdr)
        PopDrag(hdr, p)
        local sv = New('TextButton', { Size=UDim2.new(0,170,0,100), Position=UDim2.new(0,8,0,26), BorderSizePixel=0, ZIndex=51, Text='', AutoButtonColor=false }, p)
        local wh = New('Frame', { Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=52 }, sv)
        New('UIGradient', { Transparency=NumberSequence.new(0,1) }, wh)
        local bk = New('Frame', { Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(0,0,0), BorderSizePixel=0, ZIndex=53 }, sv)
        New('UIGradient', { Rotation=90, Transparency=NumberSequence.new(1,0) }, bk)
        local svc = New('Frame', { Size=UDim2.new(0,6,0,6), AnchorPoint=Vector2.new(.5,.5), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=55 }, sv)
        Stroke(svc, Color3.new(0,0,0))
        local hb = New('TextButton', { Size=UDim2.new(0,170,0,10), Position=UDim2.new(0,8,0,132), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=51, Text='', AutoButtonColor=false }, p)
        New('UIGradient', { Color=ColorSequence.new({KP(0,255,0,0),KP(1/6,255,255,0),KP(2/6,0,255,0),KP(3/6,0,255,255),KP(4/6,0,0,255),KP(5/6,255,0,255),KP(1,255,0,0)}) }, hb)
        local hc = New('Frame', { Size=UDim2.new(0,2,1,4), AnchorPoint=Vector2.new(.5,.5), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=55 }, hb)
        Stroke(hc, Color3.new(0,0,0))
        local ab, ag, ac
        if alpha then
            ab = New('TextButton', { Size=UDim2.new(0,170,0,10), Position=UDim2.new(0,8,0,148), BorderSizePixel=0, ZIndex=51, Text='', AutoButtonColor=false }, p)
            ab.BackgroundColor3 = Color3.fromRGB(150,150,150); ab.ClipsDescendants = true
            ag = New('Frame', { Size=UDim2.new(1,0,1,0), BackgroundColor3=P.Value, BorderSizePixel=0, ZIndex=52 }, ab)
            New('UIGradient', { Transparency=NumberSequence.new(0,1) }, ag)
            ac = New('Frame', { Size=UDim2.new(0,2,1,4), AnchorPoint=Vector2.new(.5,.5), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=55 }, ab)
            Stroke(ac, Color3.new(0,0,0))
        end
        local function ui()
            sv.BackgroundColor3 = Color3.fromHSV(P.Hue,1,1)
            svc.Position = UDim2.new(P.Sat,0,1-P.Vib,0)
            hc.Position  = UDim2.new(P.Hue,0,0.5,0)
            if alpha then ag.BackgroundColor3=P.Value; ac.Position=UDim2.new(P.Transparency,0,0.5,0) end
        end
        P._ui = ui
        local drag
        local function upd(m)
            local function fx(fr) return math.clamp((m.X-fr.AbsolutePosition.X)/math.max(fr.AbsoluteSize.X,1),0,1) end
            if drag=='sv' then
                P.Sat = fx(sv)
                P.Vib = 1-math.clamp((m.Y-sv.AbsolutePosition.Y)/math.max(sv.AbsoluteSize.Y,1),0,1)
            elseif drag=='h' then P.Hue = math.min(fx(hb),0.999)
            elseif drag=='a' then P.Transparency = fx(ab) end
            refresh()
        end
        local function hook(fr, n2) fr.InputBegan:Connect(function(i) if IsClick(i) then drag=n2; MarkPop(); upd(UIS:GetMouseLocation()) end end) end
        hook(sv,'sv'); hook(hb,'h'); if alpha then hook(ab,'a') end
        local c1 = UIS.InputChanged:Connect(function(i)
            if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(UIS:GetMouseLocation()) end
        end)
        local c2 = UIS.InputEnded:Connect(function(i) if IsClick(i) then drag=nil end end)
        p.Destroying:Connect(function() c1:Disconnect(); c2:Disconnect(); P._ui=nil end)
        ui()
    end)
    Options[idx] = P
    return P
end

-- ============================================================
--  KeyPicker widget
-- ============================================================
local function AddKeyPicker(row, idx, info, tog)
    info = info or {}
    local K = {
        Type    = 'KeyPicker',
        Value   = info.Default,
        Mode    = info.Mode or 'Toggle',
        Text    = info.Text or (tog and tog.Text) or idx,
        NoUI    = info.NoUI,
        _state  = false,
        _clicked = {},
    }
    Changeable(K)
    local sync = info.SyncToggleState and tog or nil
    function K:OnClick(f) table.insert(K._clicked, f) end
    function K:GetState()
        if K.Mode=='Always' then return true end
        if sync then return sync.Value end
        return K._state
    end
    function K:_press()
        if K.Mode=='Toggle' then
            local nv = not K:GetState(); K._state = nv
            if sync then sync:SetValue(nv) end
        elseif K.Mode=='Hold' then
            K._state = true; if sync then sync:SetValue(true) end
        else return end
        for _, f in ipairs(K._clicked) do task.spawn(f) end
        Library:RefreshKeybinds()
    end
    function K:_release()
        if K.Mode=='Hold' and K._state then
            K._state=false; if sync then sync:SetValue(false) end
            Library:RefreshKeybinds()
        end
    end
    local w = TextService:GetTextSize('['.. (K.Value or 'None') ..']', 12, Library.Font, Vector2.new(300,50)).X + 6
    local left = Place(row, w)
    local b = New('TextButton', {
        Size = UDim2.new(0,w,0,16), Position = UDim2.new(1,left,0.5,-8),
        BackgroundTransparency = 1, Font = Library.Font, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, AutoButtonColor = false, Text = '',
    }, row)
    local function show() b.Text = '['.. (K.Value or 'None') ..']'; b.TextColor3 = T.Dim end
    show()
    b.MouseButton1Click:Connect(function()
        if Library._listening then return end
        Library._listening = true; b.Text, b.TextColor3 = '[...]', T.Accent
        task.wait()
        local c; c = UIS.InputBegan:Connect(function(i)
            local n
            if i.UserInputType==Enum.UserInputType.Keyboard then n=i.KeyCode.Name
            elseif i.UserInputType.Name:find('^MouseButton%d') then n='MB'..i.UserInputType.Name:match('%d')
            else return end
            if n=='Escape' then n=nil end
            K.Value=n; show(); c:Disconnect(); Library._listening=false
            Library:RefreshKeybinds(); Fire(K, info.ChangedCallback)
        end)
    end)
    b.MouseButton2Click:Connect(function()
        local p = OpenPopup(b, UDim2.new(0,72,0,60))
        New('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder }, p)
        for n2, m in ipairs({'Always','Toggle','Hold'}) do
            local ob = New('TextButton', {
                Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Text=' '..m,
                Font=Library.Font, TextSize=12, ZIndex=51, LayoutOrder=n2,
                TextColor3=K.Mode==m and T.Accent or T.Text, TextXAlignment=Enum.TextXAlignment.Left,
            }, p)
            ob.MouseButton1Click:Connect(function() K.Mode=m; ClosePopup(true); Library:RefreshKeybinds() end)
        end
    end)
    function K:SetValue(t2) K.Value=t2[1]; K.Mode=t2[2] or K.Mode; show(); Library:RefreshKeybinds() end
    table.insert(Library._pickers, K)
    Options[idx] = K
    return K
end

-- ============================================================
--  Addons mixin (chained :AddColorPicker / :AddKeyPicker)
-- ============================================================
local function Rowable(obj, r)
    function obj:AddColorPicker(i, inf) AddColorPicker(r, i, inf); return obj end
    function obj:AddKeyPicker(i, inf)   AddKeyPicker(r, i, inf, obj.Type=='Toggle' and obj or nil); return obj end
end

-- ============================================================
--  GroupBuilder — creates all the Add* methods on a container
-- ============================================================
local ON_COL = Color3.fromRGB(50, 38, 70)
local BTN    = Color3.fromRGB(25, 25, 28)
local BTN_HI = Color3.fromRGB(38, 34, 48)
local LINE   = Color3.fromRGB(50, 50, 56)

local function GroupBuilder(container, noReg, rowList)
    local G = { Container = container }
    rowList  = rowList or {}

    local function NewRow(h, text)
        local r = New('Frame', { Size=UDim2.new(1,0,0,h), BackgroundTransparency=1 }, container)
        if not noReg and text then table.insert(rowList, { f=r, t=text }) end
        return r
    end

    -- AddToggle
    function G:AddToggle(idx, info)
        info = info or {}
        local TG = { Type='Toggle', Value=info.Default or false, Text=info.Text or idx, Idx=idx }
        Changeable(TG)
        local r = NewRow(23, TG.Text)
        local cb = New('Frame', { Size=UDim2.new(0,13,0,13), Position=UDim2.new(0,2,0.5,-7), BorderSizePixel=0 }, r)
        local st = Stroke(cb); Shade(cb, 1, 0.68); Round(cb, 3)
        local lbl = MkText(r, TG.Text, { P=UDim2.new(0,24,0,0), S=UDim2.new(1,-90,1,0) })
        local orbit = SpinGrad(st)
        local built = false
        local function vis()
            local v = TG.Value
            orbit.Enabled = v; st.Thickness = v and 2 or 1; st.Color = v and Color3.new(1,1,1) or LINE
            local c1 = v and ON_COL or Color3.fromRGB(28,28,32)
            local c2 = v and T.Text or T.Dim
            if built then
                TS:Create(cb,  TweenInfo.new(0.15), { BackgroundColor3=c1 }):Play()
                TS:Create(lbl, TweenInfo.new(0.15), { TextColor3=c2 }):Play()
            else cb.BackgroundColor3=c1; lbl.TextColor3=c2 end
        end
        Th(vis); built=true
        local function set(v)
            TG.Value = v and true or false; vis()
            Fire(TG, info.Callback); Library:RefreshKeybinds()
        end
        function TG:SetValue(v) if (v and true or false)~=TG.Value then set(v) end end
        local hit = New('TextButton', { Size=UDim2.new(1,-70,1,0), BackgroundTransparency=1, Text='', AutoButtonColor=false }, r)
        hit.MouseButton1Click:Connect(function() set(not TG.Value) end)
        if type(info.Tooltip)=='string' then
            -- tooltip via notify on hover (lightweight)
            hit.MouseEnter:Connect(function() Library:Notify(info.Tooltip, 2) end)
        end
        Rowable(TG, r)
        Toggles[idx] = TG
        return TG
    end

    -- AddSlider
    function G:AddSlider(idx, info)
        local SL = {
            Type=info.Type or 'Slider',
            Min=info.Min or 0, Max=info.Max or 100,
            Rounding=info.Rounding or 0, Text=info.Text or idx,
        }
        SL.Value = info.Default or SL.Min
        Changeable(SL)
        local compact = info.Compact ~= false
        local r = NewRow(compact and 20 or 34, SL.Text)
        local tr, valL
        if compact then
            tr = New('TextButton', { Size=UDim2.new(1,-4,0,16), Position=UDim2.new(0,2,0,2), BackgroundColor3=Color3.fromRGB(28,28,32), Text='', BorderSizePixel=0, AutoButtonColor=false }, r)
        else
            MkText(r, SL.Text, { S=UDim2.new(.6,0,0,16), P=UDim2.new(0,2,0,0) })
            valL = MkText(r, '', { S=UDim2.new(.4,-2,0,16), P=UDim2.new(.6,0,0,0), Align=Enum.TextXAlignment.Right, Color=T.Dim })
            tr = New('TextButton', { Size=UDim2.new(1,-4,0,8), Position=UDim2.new(0,2,0,21), BackgroundColor3=Color3.fromRGB(28,28,32), Text='', BorderSizePixel=0, AutoButtonColor=false }, r)
        end
        Stroke(tr, LINE); Shade(tr, 0.7, 1); Round(tr, 3)
        local fillF = New('Frame', { BackgroundColor3=T.Accent, BorderSizePixel=0, Size=UDim2.new() }, tr)
        Shade(fillF, 0.6, 1, 0); Round(fillF, 3)
        Th(function() fillF.BackgroundColor3 = T.Accent end)
        if compact then valL = MkText(tr, '', { Align=Enum.TextXAlignment.Center, Size=12 }); valL.ZIndex=2 end
        local drawn = false
        local function draw()
            local sz = UDim2.new((SL.Value-SL.Min)/math.max(SL.Max-SL.Min,1e-9),0,1,0)
            if drawn then TS:Create(fillF, TweenInfo.new(0.08), { Size=sz }):Play() else fillF.Size=sz end
            drawn = true
            local suf = info.Suffix or ''
            local txt = tostring(SL.Value)..suf
            if not info.HideMax then txt = txt..'/'..tostring(SL.Max)..suf end
            valL.Text = compact and (SL.Text..': '..txt) or txt
        end
        local function set(x, silent)
            x = math.clamp(x, SL.Min, SL.Max)
            local m = 10^SL.Rounding; x = math.floor(x*m+.5)/m
            local ch = x~=SL.Value; SL.Value=x; draw()
            if ch and not silent then Fire(SL, info.Callback) end
        end
        draw()
        function SL:SetValue(n) set(n) end
        function SL:SetMax(n) SL.Max=n; set(SL.Value,true); draw() end
        function SL:SetMin(n) SL.Min=n; set(SL.Value,true); draw() end
        local d2=false
        tr.InputBegan:Connect(function(i) if IsClick(i) then d2=true; set(SL.Min+(SL.Max-SL.Min)*math.clamp((i.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)) end end)
        UIS.InputEnded:Connect(function(i) if IsClick(i) then d2=false end end)
        UIS.InputChanged:Connect(function(i)
            if d2 and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                set(SL.Min+(SL.Max-SL.Min)*math.clamp((i.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1))
            end
        end)
        Options[idx] = SL
        return SL
    end

    -- AddDropdown
    function G:AddDropdown(idx, info)
        if info.SpecialType=='Player' then
            info.Values = {}
            for _, p in ipairs(Players:GetPlayers()) do table.insert(info.Values, p.Name) end
            table.sort(info.Values)
            info.AllowNull = true
        end
        local D = { Type='Dropdown', Values=info.Values or {}, Multi=info.Multi, Text=info.Text or idx }
        Changeable(D)
        local function resolve(x) if type(x)=='number' then return D.Values[x] end return x end
        local function setv(v)
            if D.Multi then
                D.Value = {}
                if type(v)=='table' then
                    for k, x in pairs(v) do
                        if type(k)=='number' then local n2=resolve(x); if n2 then D.Value[n2]=true end
                        elseif x then D.Value[k]=true end
                    end
                end
            else D.Value = resolve(v) end
        end
        setv(info.Default)
        local h = info.Compact and 22 or 42
        local r = NewRow(h, D.Text)
        if not info.Compact then MkText(r, D.Text, { S=UDim2.new(1,0,0,18), P=UDim2.new(0,2,0,0) }) end
        local by = info.Compact and 1 or -22
        local b = New('TextButton', {
            Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,1,by),
            BackgroundColor3=BTN, BorderSizePixel=0,
            Font=Library.Font, TextSize=12, TextColor3=T.Dim,
            TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
            AutoButtonColor=false, Text='',
        }, r)
        Stroke(b, Color3.fromRGB(40,40,45)); Shade(b,1,0.72); Round(b,4); Hover(b,BTN,BTN_HI)
        New('UIPadding', { PaddingLeft=UDim.new(0,7), PaddingRight=UDim.new(0,18) }, b)
        MkText(b, D.Multi and '+' or 'v', { Align=Enum.TextXAlignment.Right, S=UDim2.new(1,14,1,0), Color=T.Dim, Size=12 })
        local function disp()
            if D.Multi then
                local t2={}; for _, v in ipairs(D.Values) do if D.Value[v] then t2[#t2+1]=v end end
                b.Text = #t2>0 and table.concat(t2,', ') or '--'
            else b.Text = D.Value and tostring(D.Value) or '--' end
        end
        disp()
        local function changed() disp(); Fire(D, info.Callback) end
        function D:SetValue(v) setv(v); changed() end
        function D:SetValues(list) D.Values=list; setv(nil); changed() end
        b.MouseButton1Click:Connect(function()
            local items = math.max(#D.Values, 1)
            local p = OpenPopup(b, UDim2.new(0, b.AbsoluteSize.X, 0, items*20), true)
            New('UIListLayout', { SortOrder=Enum.SortOrder.LayoutOrder }, p)
            for n2, v in ipairs(D.Values) do
                local on = D.Multi and D.Value[v] or (not D.Multi and D.Value==v)
                local ob = New('TextButton', {
                    Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Text='  '..v,
                    Font=Library.Font, TextSize=12, ZIndex=51, LayoutOrder=n2,
                    TextColor3=on and T.Accent or T.Text, TextXAlignment=Enum.TextXAlignment.Left,
                }, p)
                ob.InputBegan:Connect(function(inp)
                    if not IsClick(inp) then return end
                    if D.Multi then
                        D.Value[v] = not D.Value[v] or nil
                        ob.TextColor3 = D.Value[v] and T.Accent or T.Text
                        changed()
                    else
                        if info.AllowNull and D.Value==v then D.Value=nil else D.Value=v end
                        changed(); ClosePopup(true)
                    end
                end)
            end
        end)
        Options[idx] = D
        return D
    end

    -- AddInput
    function G:AddInput(idx, info)
        info = info or {}
        local IN = { Type='Input', Value=info.Default or '', Text=info.Text or idx }
        Changeable(IN)
        local r = NewRow(42, IN.Text)
        MkText(r, IN.Text, { S=UDim2.new(1,0,0,18), P=UDim2.new(0,2,0,0) })
        local tb = New('TextBox', {
            Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,1,-22),
            BackgroundColor3=BTN, BorderSizePixel=0,
            Text=IN.Value, PlaceholderText=info.Placeholder or '',
            PlaceholderColor3=T.Dim, TextColor3=T.Text,
            Font=Library.Font, TextSize=12, ClearTextOnFocus=false,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, r)
        Stroke(tb, Color3.fromRGB(40,40,45)); Shade(tb,1,0.72); Round(tb,4); Hover(tb,BTN,BTN_HI)
        New('UIPadding', { PaddingLeft=UDim.new(0,7) }, tb)
        local function commit()
            if info.Numeric and tb.Text~='' and tonumber(tb.Text)==nil then tb.Text=IN.Value; return end
            IN.Value=tb.Text; Fire(IN, info.Callback)
        end
        if info.Finished then tb.FocusLost:Connect(function(enter) if enter then commit() end end)
        else tb:GetPropertyChangedSignal('Text'):Connect(commit) end
        function IN:SetValue(v) IN.Value=tostring(v or ''); tb.Text=IN.Value end
        Options[idx] = IN
        return IN
    end

    -- AddButton
    function G:AddButton(a, f)
        local info = type(a)=='table' and a or { Text=a, Func=f }
        local r = NewRow(24, info.Text)
        local BT = { Type='Button', Buttons={} }
        local function mk(inf)
            local b2 = New('TextButton', {
                Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,2),
                BackgroundColor3=BTN, BorderSizePixel=0,
                Text=inf.Text, Font=Library.Font, TextSize=12, TextColor3=T.Text, AutoButtonColor=false,
            }, r)
            Stroke(b2, Color3.fromRGB(40,40,45)); Shade(b2,1,0.72); Round(b2,4); Hover(b2,BTN,BTN_HI)
            b2.MouseEnter:Connect(function() b2.TextColor3=T.Accent end)
            b2.MouseLeave:Connect(function() b2.TextColor3=T.Text  end)
            local armed=false
            b2.MouseButton1Click:Connect(function()
                if inf.DoubleClick and not armed then
                    armed=true; b2.Text='Click again'
                    task.delay(1.5, function() armed=false; b2.Text=inf.Text end)
                    return
                end
                armed=false; b2.Text=inf.Text
                if inf.Func then inf.Func() end
            end)
            table.insert(BT.Buttons, b2)
            return b2
        end
        mk(info)
        function BT:AddButton(a2, f2)
            local b2 = mk(type(a2)=='table' and a2 or {Text=a2,Func=f2})
            BT.Buttons[1].Size = UDim2.new(.5,-2,0,20)
            b2.Size, b2.Position = UDim2.new(.5,-2,0,20), UDim2.new(.5,2,0,2)
            return BT
        end
        return BT
    end

    -- AddLabel
    function G:AddLabel(text, wrap)
        local LB = { Type='Label' }
        local r = NewRow(wrap and 0 or 18, text)
        if wrap then r.AutomaticSize = Enum.AutomaticSize.Y end
        local l = MkText(r, text, { Color=T.Dim, P=UDim2.new(0,2,0,0), S=UDim2.new(1,-4, wrap and 0 or 1, 0), Wrap=wrap })
        if wrap then l.AutomaticSize=Enum.AutomaticSize.Y end
        New('UIListLayout', { Padding=UDim.new(0,4), FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder }, r)
        function LB:SetText(t2) l.Text=t2 end
        Rowable(LB, r)
        return LB
    end

    -- AddDivider
    function G:AddDivider()
        local r = NewRow(10)
        New('Frame', { Size=UDim2.new(1,-4,0,1), Position=UDim2.new(0,2,0.5,0), BackgroundColor3=T.Border, BorderSizePixel=0 }, r)
    end

    -- AddBlank
    function G:AddBlank(h) NewRow(h or 8) end

    -- AddDependencyBox
    function G:AddDependencyBox()
        local Depbox = { Dependencies={}, Type='DepBox' }
        local holder = New('Frame', {
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1, Visible=false,
        }, container)
        local inner = New('Frame', { Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1 }, holder)
        New('UIListLayout', { Padding=UDim.new(0,1) }, inner)
        local subG = GroupBuilder(inner, noReg, rowList)
        for k, v in pairs(subG) do Depbox[k] = v end
        Depbox.Container = inner
        function Depbox:SetupDependencies(deps)
            Depbox.Dependencies = deps
            Depbox:Update()
        end
        function Depbox:Update()
            for _, dep in ipairs(Depbox.Dependencies) do
                local elem, val = dep[1], dep[2]
                if elem.Type=='Toggle' and elem.Value~=val then
                    holder.Visible=false; return
                end
            end
            holder.Visible=true
        end
        function Depbox:AddDependencyBox()
            return G:AddDependencyBox()
        end
        return Depbox
    end

    return G
end

-- ============================================================
--  Box builder (groupbox / tabbox pane)
-- ============================================================
local function MakeBox(parent, name, h, rowList)
    local num  = type(h)=='number'
    local fill = h=='fill'
    local box = New('Frame', {
        Size = num and UDim2.new(1,0,0,h) or (fill and UDim2.new(1,0,1,0) or UDim2.new(1,0,0,0)),
        AutomaticSize = (not num and not fill) and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        BackgroundColor3 = Color3.fromRGB(28,28,32),
        BorderSizePixel  = 0,
    }, parent)
    Stroke(box, Color3.fromRGB(34,34,38)); Shade(box,1,0.62); Round(box,4)
    -- accent bar
    local bl = GradC(New('Frame', { Size=UDim2.new(1,0,0,2), BorderSizePixel=0 }, box), T.Accent, T.Bar, 0)
    Th(function() bl.Color=ColorSequence.new(T.Accent, T.Accent:Lerp(Color3.new(0,0,0),0.45)) end)
    -- title on top edge
    local tl = New('Frame', { Size=UDim2.new(0,0,0,16), Position=UDim2.new(0,8,0,-8), AutomaticSize=Enum.AutomaticSize.X, BackgroundTransparency=1, BorderSizePixel=0, ZIndex=3 }, box)
    New('Frame', { Size=UDim2.new(1,8,0,4), Position=UDim2.new(0,-4,0,7), BackgroundColor3=Color3.fromRGB(28,28,32), BorderSizePixel=0, ZIndex=3 }, tl)
    New('UIPadding', { PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,4) }, tl)
    local tlt = MkText(tl, name, { Bold=true, S=UDim2.new(0,0,1,0) })
    tlt.AutomaticSize, tlt.ZIndex = Enum.AutomaticSize.X, 4
    AnimGrad(tlt)
    local c
    if num or fill then
        c = New('ScrollingFrame', {
            Size=UDim2.new(1,-12,1,-18), Position=UDim2.new(0,6,0,12),
            BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=0,
            CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        }, box)
        New('UIListLayout', { Padding=UDim.new(0,1) }, c)
    else
        c = New('Frame', { Size=UDim2.new(1,-12,0,0), Position=UDim2.new(0,6,0,12), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1 }, box)
        New('UIListLayout', { Padding=UDim.new(0,1) }, c)
        New('UIPadding', { PaddingBottom=UDim.new(0,8) }, c)
    end
    return box, GroupBuilder(c, false, rowList)
end

-- ============================================================
--  Toggle fade helper
-- ============================================================
local function FadeTween(main, fadeTime, toShow)
    if toShow then
        main.GroupTransparency = 1; main.Visible = true
        TS:Create(main, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
    else
        local t = TS:Create(main, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
        t.Completed:Connect(function(s) if s==Enum.PlaybackState.Completed then main.Visible=false end end)
        t:Play()
    end
end

-- ============================================================
--  CreateWindow
-- ============================================================
function Library:CreateWindow(info)
    if type(info)~='table' then info={Title=tostring(info)} end
    local title    = info.Title or 'cynth'
    local fadeTime = info.MenuFadeTime or 0.2
    local size     = info.Size or UDim2.fromOffset(720, 575)
    local rowList  = {}

    local W = { Tabs={}, First=true, _rowList=rowList }

    -- Outer window (CanvasGroup so we can fade everything)
    local Win = New('Frame', {
        Name=title, Size=size, AnchorPoint=Vector2.new(.5,.5),
        Position = info.Center and UDim2.fromScale(.5,.5) or (info.Position or UDim2.fromScale(.5,.5)),
        BackgroundTransparency=1, BorderSizePixel=0,
    }, Gui)
    local Main = New('CanvasGroup', {
        GroupTransparency=0, Size=size, AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5), BackgroundColor3=Color3.fromRGB(21,21,25),
        BorderSizePixel=0, Active=true,
    }, Win)
    Stroke(Main, Color3.fromRGB(38,38,42)); Shade(Main,1,0.5); Round(Main,6)

    -- shadow
    local sh = New('ImageLabel', {
        BackgroundTransparency=1, Image='rbxassetid://6014261993',
        ImageColor3=Color3.new(0,0,0), ScaleType=Enum.ScaleType.Slice,
        SliceCenter=Rect.new(49,49,450,450), Size=UDim2.new(1,40,1,40),
        Position=UDim2.new(0,-20,0,-20), ZIndex=0,
    }, Win)
    RS.RenderStepped:Connect(function()
        sh.Visible = Main.Visible
        sh.ImageTransparency = 0.45 + 0.55*Main.GroupTransparency
    end)

    -- title bar
    local TB = New('Frame', { Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, Active=true }, Main)
    Drag(TB, Win)
    local TitleL = MkText(TB, title, { Bold=true, P=UDim2.new(0,12,0,0), S=UDim2.new(0,0,1,0) })
    TitleL.AutomaticSize = Enum.AutomaticSize.X
    AnimGrad(TitleL)

    -- inner panel
    local Inner = New('Frame', {
        Size=UDim2.new(1,-16,1,-34), Position=UDim2.new(0,8,0,28),
        BackgroundColor3=Color3.fromRGB(24,24,28), BorderSizePixel=0,
    }, Main)
    Stroke(Inner, Color3.fromRGB(34,34,38)); Shade(Inner,1,0.55); Round(Inner,5)

    local topLine = GradC(New('Frame', { Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,27), BorderSizePixel=0 }, Main), T.Accent, T.Accent, 0, 0.2, 1)
    Th(function() topLine.Color=ColorSequence.new(T.Accent, T.Accent) end)

    -- tab row
    local TabRow = New('Frame', { Size=UDim2.new(1,-12,0,24), Position=UDim2.new(0,6,0,4), BackgroundTransparency=1 }, Inner)
    local TabLayout = New('UIListLayout', { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,2), VerticalAlignment=Enum.VerticalAlignment.Center }, TabRow)

    -- sliding underline
    local Ind = New('Frame', { Size=UDim2.new(0,0,0,2), Position=UDim2.new(0,6,0,26), BackgroundColor3=T.Accent, BorderSizePixel=0 }, Inner)
    Th(function() Ind.BackgroundColor3=T.Accent end)

    -- body
    local Body = New('Frame', { Size=UDim2.new(1,-20,1,-42), Position=UDim2.new(0,10,0,34), BackgroundTransparency=1 }, Inner)

    -- search bar
    local S = New('Frame', { Size=UDim2.new(0,170,0,22), Position=UDim2.new(1,-180,0,5), BackgroundTransparency=1 }, Inner)
    local function fitSearch()
        local x = 6 + TabLayout.AbsoluteContentSize.X + 10
        S.Position = UDim2.new(0,x,0,5)
        S.Size     = UDim2.new(1,-x-8,0,22)
    end
    TabLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(fitSearch); fitSearch()
    local ring = New('Frame', { Size=UDim2.new(0,8,0,8), Position=UDim2.new(0,4,0,5), BackgroundTransparency=1 }, S)
    Stroke(ring, T.Dim)
    New('Frame', { Size=UDim2.new(0,5,0,1), Position=UDim2.new(0,10,0,15), Rotation=45, BackgroundColor3=T.Dim, BorderSizePixel=0 }, S)
    local sb = New('TextBox', {
        Size=UDim2.new(1,-24,1,0), Position=UDim2.new(0,22,0,0), BackgroundTransparency=1,
        Text='', PlaceholderText='search', PlaceholderColor3=T.Dim,
        TextColor3=T.Text, Font=Library.Font, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false,
    }, S)
    local sg = GradC(New('Frame', { Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BorderSizePixel=0 }, S), T.Bar, T.Border, 0)
    Th(function() sg.Color=ColorSequence.new(T.Bar, T.Border) end)
    sb:GetPropertyChangedSignal('Text'):Connect(function()
        local q = sb.Text:lower()
        for _, row in ipairs(rowList) do
            row.f.Visible = q=='' or row.t:lower():find(q,1,true)~=nil
        end
    end)

    Library._main = Main
    if info.AutoShow==false then Main.Visible=false; Library.Open=false
    else Main.Visible=true end

    function W:SetWindowTitle(t2) TitleL.Text=t2 end

    -- AddTab
    function W:AddTab(name)
        local Tab = {}
        local btn = New('TextButton', {
            Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
            BackgroundTransparency=1, Text='  '..name..'  ',
            Font=Library.Font, TextSize=13, TextColor3=T.Text, AutoButtonColor=false,
        }, TabRow)
        local page = New('Frame', { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Visible=false }, Body)

        local function col(x)
            local c2 = New('Frame', { Size=UDim2.new(.5,-4,1,0), Position=UDim2.new(x, x==0 and 0 or 4,0,0), BackgroundTransparency=1 }, page)
            New('UIListLayout', { Padding=UDim.new(0,14) }, c2); return c2
        end
        local L, R = col(0), col(.5)

        local tabGrad = AnimGrad(btn)
        local function paint()
            local on = W.Sel==name
            btn.TextColor3 = on and Color3.new(1,1,1) or T.Text
            tabGrad.Enabled = on
        end
        Th(paint)
        local function move()
            if W.Sel~=name then return end
            local x2 = 6 + btn.AbsolutePosition.X - TabRow.AbsolutePosition.X
            local w2  = btn.AbsoluteSize.X
            if w2<=0 or (x2==W.IndX and w2==W.IndW) then return end
            W.IndX, W.IndW = x2, w2
            TS:Create(Ind, TweenInfo.new(0.2,Enum.EasingStyle.Quint), { Position=UDim2.new(0,x2,0,26), Size=UDim2.new(0,w2,0,2) }):Play()
        end
        btn:GetPropertyChangedSignal('AbsoluteSize'):Connect(move)
        btn:GetPropertyChangedSignal('AbsolutePosition'):Connect(move)

        local function select()
            for _, t2 in pairs(W.Tabs) do t2.page.Visible=false; t2.btn.Font=Library.Font end
            page.Visible=true; btn.Font=Library.FontB; W.Sel=name
            for _, t2 in pairs(W.Tabs) do t2.paint() end
            ClosePopup(); move()
        end
        btn.MouseButton1Click:Connect(select)
        W.Tabs[name] = { page=page, btn=btn, paint=paint }
        if W.First then W.First=false; select() end

        -- helpers for Tabbox
        local function tabbox(column, h2)
            local TBX = {}
            local _, c2 = MakeBox(column, '', h2, rowList)
            -- tab bar inside the box
            local bar = New('Frame', { Size=UDim2.new(1,0,0,22), BackgroundTransparency=1 }, c2.Container)
            New('UIListLayout', { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,2) }, bar)
            local tframes, tbtns, first2, cur = {}, {}, nil, nil
            local function pick(n2)
                cur=n2
                for k, f in pairs(tframes) do
                    f.Visible=k==n2
                    tbtns[k].TextColor3=k==n2 and T.Accent or T.Text
                    tbtns[k].Font=k==n2 and Library.FontB or Library.Font
                end
            end
            Th(function() if cur then pick(cur) end end)
            function TBX:AddTab(n2)
                local tb2 = New('TextButton', {
                    Size=UDim2.new(0,0,1,0), AutomaticSize=Enum.AutomaticSize.X,
                    BackgroundColor3=Color3.fromRGB(30,30,34), BorderSizePixel=0,
                    Text='  '..n2..'  ', Font=Library.Font, TextSize=13,
                    TextColor3=T.Text, BackgroundTransparency=1, AutoButtonColor=false,
                }, bar)
                Shade(tb2,1,0.7); Round(tb2,4)
                local f2 = New('Frame', { Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Visible=false }, c2.Container)
                New('UIListLayout', { Padding=UDim.new(0,1) }, f2)
                tbtns[n2], tframes[n2] = tb2, f2
                tb2.MouseButton1Click:Connect(function() pick(n2) end)
                if not first2 then first2=n2; pick(n2) end
                return GroupBuilder(f2, false, rowList)
            end
            return TBX
        end

        function Tab:AddLeftGroupbox(name2, h2)
            local _, g = MakeBox(L, name2, h2, rowList); return g
        end
        function Tab:AddRightGroupbox(name2, h2)
            local _, g = MakeBox(R, name2, h2, rowList); return g
        end
        function Tab:AddLeftTabbox(h2)  return tabbox(L, h2) end
        function Tab:AddRightTabbox(h2) return tabbox(R, h2) end

        return Tab
    end

    -- toggle open/close
    Library._baseTrans, Library.FadeTime = 0, fadeTime
    function Library:ToggleMenu()
        Library.Open = not Library.Open
        ClosePopup()
        if not Main then return end
        FadeTween(Main, Library.FadeTime, Library.Open)
    end
    Library.Toggle = Library.ToggleMenu

    UIS.InputBegan:Connect(function(i, gp)
        if Library.Unloaded or gp or Library._listening then return end
        local tk = Library.ToggleKeybind
        local mk = tk and tk.Value
        if (mk and KeyIs(i, mk)) or (not mk and i.KeyCode==Library.ToggleKey) then Library:ToggleMenu() end
        for _, k in ipairs(Library._pickers) do if k.Value and KeyIs(i, k.Value) then k:_press() end end
    end)
    UIS.InputEnded:Connect(function(i)
        if Library.Unloaded then return end
        for _, k in ipairs(Library._pickers) do if k.Value and KeyIs(i, k.Value) then k:_release() end end
    end)

    return W
end

-- ============================================================
--  OnUnload / Unload
-- ============================================================
function Library:OnUnload(f) table.insert(Library._unload, f) end
function Library:Unload()
    Library.Unloaded = true
    gradConn:Disconnect()
    for _, f in ipairs(Library._unload) do pcall(f) end
    Gui:Destroy()
end

return Library
