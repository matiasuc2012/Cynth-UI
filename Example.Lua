-- cynth ui | imgui-style lib (LinoriaLib-style API) + keybind list HUD
-- restyle: sharp edges (no rounding), softer gradients, window shadow, hover/tween states, sliding tab underline, ESP-style font
local Players, UIS, TS, RS = game:GetService("Players"), game:GetService("UserInputService"), game:GetService("TweenService"), game:GetService("RunService")
local TextService, HttpService = game:GetService("TextService"), game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local LP = Players.LocalPlayer
local Lib = {Flags = {}, Open = true, ToggleKey = Enum.KeyCode.Insert, Binds = {}}
local Library = Lib -- Library:Notify(...) works everywhere
Lib.T = {
    Accent = Color3.fromRGB(176,140,240), Bar = Color3.fromRGB(150,112,205),
    Panel = Color3.fromRGB(18,16,20), Panel2 = Color3.fromRGB(26,24,30), Border = Color3.fromRGB(46,42,52),
    Text = Color3.fromRGB(235,235,240), Dim = Color3.fromRGB(150,148,158), Off = Color3.fromRGB(40,38,46),
}
-- FONT: change Lib.FontPreset to "Code" | "Pixel" | "Mono" | "Verdana" | "Jura" | "Josefin" | "Gotham"
local FontPresets = {
    Code    = {Enum.Font.Code, Enum.Font.Code, 13},
    Pixel   = {Enum.Font.Arcade, Enum.Font.Arcade, 12},
    Mono    = {Enum.Font.RobotoMono, Enum.Font.RobotoMono, 13},
    Verdana = {Enum.Font.Arial, Enum.Font.ArialBold, 13},
    Jura    = {Enum.Font.Jura, Enum.Font.Jura, 14},
    Josefin = {Enum.Font.JosefinSans, Enum.Font.JosefinSans, 14},
    Gotham  = {Enum.Font.GothamMedium, Enum.Font.GothamBold, 13},
}
Lib.FontPreset = "Code"
Lib.Font, Lib.FontB, Lib.Size = table.unpack(FontPresets[Lib.FontPreset])
-- vertical gap between rows inside a groupbox. The demo groupbox heights are tuned for 1; if you raise it, raise the box heights / window size too
Lib.RowGap = 1
local T = Lib.T
T.PanelHi = Color3.fromRGB(31,28,37)
local ON, OFFC, LINE = T.Accent:Lerp(Color3.new(0,0,0), 0.08), Color3.fromRGB(28,28,31), Color3.fromRGB(50,50,56)
local BTN, BTN_HI = Color3.fromRGB(25,25,28), Color3.fromRGB(38,34,48) -- button / dropdown / input fill + hover fill

-- ===== accent theming: anything that uses the accent registers a repaint function here =====
local Themed = {}
local function Th(fn) fn(); table.insert(Themed, fn) end
function Lib:SetAccent(c)
    T.Accent = c
    T.Bar = c:Lerp(Color3.new(0,0,0), 0.2)
    ON = c:Lerp(Color3.new(0,0,0), 0.08)
    for _, f in ipairs(Themed) do pcall(f) end
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.ZIndexBehavior = "cynth_ui", false, true, Enum.ZIndexBehavior.Sibling
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end) -- newer engine: make sure no inset shifts our coordinate space
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local function New(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    if parent ~= nil then i.Parent = parent end
    return i
end

-- Origin probe: a zero-size frame at Position (0,0). Its AbsolutePosition is EXACTLY where UDim2 offsets of top-level frames start,
-- no matter what inset / executor quirk shifts the gui. Popup positions = AbsolutePosition(anchor) - Origin()
local Probe = New("Frame", {Name = "Probe", Size = UDim2.new(), Position = UDim2.new(), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false}, gui)
local function Origin() return Probe.AbsolutePosition end

local function Stroke(p, c) return New("UIStroke", {Color = c or T.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p) end
-- sharp edges: corners are OFF. Change Lib.Rounding to 1 to bring the rounded corners back
Lib.Rounding = 0
local function Round(p, r)
    if Lib.Rounding > 0 then return New("UICorner", {CornerRadius = UDim.new(0, (r or 4) * Lib.Rounding)}, p) end
end
-- smooth hover fill for buttons / dropdown boxes / inputs
local function Hover(b, from, to)
    local ti = TweenInfo.new(0.12)
    b.MouseEnter:Connect(function() TS:Create(b, ti, {BackgroundColor3 = to}):Play() end)
    b.MouseLeave:Connect(function() TS:Create(b, ti, {BackgroundColor3 = from}):Play() end)
end
-- gradient helpers: Shade = brightness fade on the element's own color (keeps dynamic colors), GradC = absolute color fade (+ optional alpha fade)
-- Shade is softened: k = 1 keeps the old harsh look, lower = flatter
local function Shade(p, top, bot, rot)
    local k = 0.45
    top, bot = 1 - (1 - top) * k, 1 - (1 - bot) * k
    return New("UIGradient", {Color = ColorSequence.new(Color3.new(top,top,top), Color3.new(bot,bot,bot)), Rotation = rot or 90}, p)
end
local function GradC(p, c1, c2, rot, t1, t2)
    p.BackgroundColor3 = Color3.new(1,1,1)
    return New("UIGradient", {Color = ColorSequence.new(c1, c2), Rotation = rot or 0, Transparency = NumberSequence.new(t1 or 0, t2 or 0)}, p)
end
local function Text(p, txt, o)
    o = o or {}
    local l = New("TextLabel", {
        BackgroundTransparency = 1, Text = txt, Font = o.Bold and Lib.FontB or Lib.Font, TextSize = o.Size or Lib.Size,
        TextColor3 = o.Color or T.Text, TextXAlignment = o.Align or Enum.TextXAlignment.Left,
        Size = o.S or UDim2.new(1,0,1,0), Position = o.P or UDim2.new(), RichText = true,
    }, p)
    if o.Bold then l:SetAttribute("b", true) end
    return l
end
-- live font switch: Lib:SetFont("Code" | "Pixel" | "Mono" | "Verdana" | "Jura" | "Josefin" | "Gotham")
-- re-fonts everything currently on screen (gear panels you haven't opened yet pick it up when they're built)
function Lib:SetFont(name)
    local pr = FontPresets[name]
    if not pr then return end
    local oF, oB = Lib.Font, Lib.FontB
    Lib.FontPreset = name
    Lib.Font, Lib.FontB, Lib.Size = pr[1], pr[2], pr[3]
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            if d:GetAttribute("b") or (oB ~= oF and d.Font == oB) then d.Font = Lib.FontB
            elseif d.Font == oF or d.Font == oB then d.Font = Lib.Font end
        end
    end
end
local function Drag(handle, target)
    local d, s, sp
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d, s, sp = true, i.Position, target.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dl = i.Position - s
            target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dl.X, sp.Y.Scale, sp.Y.Offset + dl.Y)
        end
    end)
end

-- real screen size. gui.AbsoluteSize can be 0 / tiny in some executors
local function ScreenSize()
    local s = gui.AbsoluteSize
    if s.X < 200 or s.Y < 200 then
        local c = workspace.CurrentCamera
        if c then s = c.ViewportSize end
    end
    return s
end

-- drag helper for popups (gear panels / color pickers): clamps to the screen, marks the popup as moved, disconnects when destroyed
local function PopDrag(handle, target)
    local d, s, sp
    local c0 = handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d, s, sp = true, i.Position, target.Position
        end
    end)
    local c1 = UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end
    end)
    local c2 = UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dl = i.Position - s
            local sz, ts = ScreenSize(), target.AbsoluteSize
            target.Position = UDim2.fromOffset(math.clamp(sp.X.Offset + dl.X, 0, math.max(sz.X - ts.X, 0)),
                math.clamp(sp.Y.Offset + dl.Y, 0, math.max(sz.Y - ts.Y, 0)))
            target:SetAttribute("moved", true)
        end
    end)
    target.Destroying:Connect(function() c0:Disconnect(); c1:Disconnect(); c2:Disconnect() end)
end

-- ===== animated accent gradient for titles (follows the accent color, one shared animation for every title) =====
local GradLabels = {}
local function AnimGrad(lbl)
    if lbl:IsA("TextLabel") or lbl:IsA("TextButton") or lbl:IsA("TextBox") then lbl.TextColor3 = Color3.new(1,1,1) end -- the gradient colors the text
    local g = New("UIGradient", {}, lbl)
    table.insert(GradLabels, g)
    return g
end
-- spinning variant: accent comet whose rotation keeps turning (put on a UIStroke it travels around the outline)
local SpinGrads = {}
local function SpinGrad(f)
    local g = New("UIGradient", {}, f)
    table.insert(SpinGrads, g)
    return g
end
local gradConn = RS.RenderStepped:Connect(function()
    local t = os.clock()
    local a = T.Accent
    local lo, hi = a:Lerp(Color3.new(0,0,0), 0.25), a:Lerp(Color3.new(1,1,1), 0.7)
    local pts = {}
    for i = 0, 6 do
        local x = i / 6
        local k = (math.sin((x * 2 - t * 1.2) * math.pi) + 1) / 2
        pts[#pts+1] = ColorSequenceKeypoint.new(x, lo:Lerp(hi, k))
    end
    local seq = ColorSequence.new(pts)
    local spinSeq, rot = ColorSequence.new({ColorSequenceKeypoint.new(0, lo), ColorSequenceKeypoint.new(0.3, lo), ColorSequenceKeypoint.new(0.5, hi), ColorSequenceKeypoint.new(0.7, lo), ColorSequenceKeypoint.new(1, lo)}), (t * 200) % 360
    for i = #SpinGrads, 1, -1 do
        local g = SpinGrads[i]
        if g.Parent then g.Color, g.Rotation = spinSeq, rot else table.remove(SpinGrads, i) end
    end
    for i = #GradLabels, 1, -1 do
        local g = GradLabels[i]
        if g.Parent then g.Color = seq else table.remove(GradLabels, i) end
    end
end)

-- ===== HUD panel (near-black box, accent bold header at the TOP, thin divider, rows below) =====
local function HudPanel(title, pos, w)
    local f = New("Frame", {Size = UDim2.new(0,w,0,0), AutomaticSize = Enum.AutomaticSize.Y, Position = pos,
        BackgroundColor3 = T.PanelHi, BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true}, gui)
    Stroke(f); Shade(f, 1, 0.6); Round(f, 4)
    New("UIPadding", {PaddingBottom = UDim.new(0,6), PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), PaddingTop = UDim.new(0,4)}, f)
    New("UIListLayout", {Padding = UDim.new(0,2), SortOrder = Enum.SortOrder.LayoutOrder}, f)
    local h = Text(f, title, {Bold = true, S = UDim2.new(1,0,0,18)})
    h.LayoutOrder = -2
    h.AutomaticSize, h.Size = Enum.AutomaticSize.X, UDim2.new(0,0,0,18)
    AnimGrad(h)
    local dv = New("Frame", {Size = UDim2.new(1,0,0,1), BorderSizePixel = 0, LayoutOrder = -1}, f)
    local dg = GradC(dv, T.Bar, T.Border, 0)
    Th(function() dg.Color = ColorSequence.new(T.Bar, T.Border) end)
    Drag(f, f)
    return f
end
local function Row(parent, name, val, valColor)
    local r = New("Frame", {Size = UDim2.new(1,0,0,19), BackgroundTransparency = 1}, parent)
    Text(r, name, {S = UDim2.new(.65,0,1,0)})
    Text(r, val, {S = UDim2.new(.35,0,1,0), P = UDim2.new(.65,0,0,0), Align = Enum.TextXAlignment.Right, Color = valColor or T.Dim})
    return r
end
local function Clear(p) for _, c in ipairs(p:GetChildren()) do if c.Name == "Row" then c:Destroy() end end end

-- watermark
local WM = New("Frame", {Size = UDim2.new(0,0,0,26), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(1,-250,0,10),
    BackgroundColor3 = T.PanelHi, BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true}, gui)
Stroke(WM); Drag(WM, WM); Shade(WM, 1, 0.6); Round(WM, 4)
New("UIPadding", {PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8)}, WM)
local WMC = New("Frame", {Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1}, WM)
New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, WMC)
local WMTitle = Text(WMC, "cynth", {Bold = true, S = UDim2.new(0,0,1,0)}); WMTitle.AutomaticSize = Enum.AutomaticSize.X
AnimGrad(WMTitle)
local WMT = Text(WMC, "", {S = UDim2.new(0,0,1,0)}); WMT.AutomaticSize = Enum.AutomaticSize.X; WMT.LayoutOrder = 1
for i, x in ipairs({0.02, 0.2}) do
    local st = Text(WM, "★", {Size = 8, S = UDim2.new(0,8,0,8), P = UDim2.new(x,0,0,-4)})
    Th(function() st.TextColor3 = T.Bar end)
end
local frames, last = 0, tick()
local function c255(x) return math.floor(x * 255 + 0.5) end
local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
local gameName = game.Name
task.spawn(function()
    local ok, i = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
    if ok and type(i) == "table" and i.Name then gameName = i.Name; if Lib.RefreshWatermark then Lib:RefreshWatermark() end end
end)
Lib.WMItems = {["Ping"] = true, ["FPS"] = true}
local wmFps, wmPing, hbMs = 0, 0, 0
local hbConn = RS.Heartbeat:Connect(function(dt) hbMs = dt * 1000 end)
function Lib:RefreshWatermark()
    local a, it = T.Accent, Lib.WMItems
    local parts = {}
    if it["Player name"] then parts[#parts+1] = esc(LP.DisplayName) end
    if it["Game name"] then parts[#parts+1] = esc(gameName) end
    if it["Time"] then parts[#parts+1] = os.date("%H:%M:%S") end
    if it["Ping"] then parts[#parts+1] = wmPing .. " ms" end
    if it["FPS"] then parts[#parts+1] = wmFps .. " fps" end
    if it["Last heartbeat (ms)"] then parts[#parts+1] = string.format("Last Heartbeat %.1f ms", hbMs) end
    WMT.Text = #parts > 0 and (" | " .. table.concat(parts, " | ")) or ""
end
local wmConn = RS.RenderStepped:Connect(function()
    frames += 1
    if tick() - last >= 0.2 then
        wmFps, wmPing = math.floor(frames / (tick() - last)), math.floor(LP:GetNetworkPing() * 1000)
        Lib:RefreshWatermark()
        frames, last = 0, tick()
    end
end)

-- keybind list: title on top, then "<toggle name> (mode)" on the left and [KEY] on the right
local KBL = HudPanel("Keybinds", UDim2.new(1,-230,0.5,30), 190)
function Lib:RefreshKeybinds()
    Clear(KBL)
    local n = 0
    for _, k in ipairs(Lib._pickers or {}) do
        if k.Value and not k.NoUI and k:GetState() then
            n += 1
            local r = Row(KBL, k.Text .. " (" .. k.Mode .. ")", "[" .. k.Value .. "]")
            r.Name, r.LayoutOrder = "Row", n
        end
    end
end

-- ===== Notifications (Library:Notify): smooth slide + height tween, duration line, 4 corners =====
Lib.NotifyEnabled, Lib.NotifySide, Lib.NotifyTime = true, "Up right", 3
local NH = New("Frame", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 200}, gui)
local NL = New("UIListLayout", {Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder}, NH)
local NP = New("UIPadding", {}, NH)
local Sides = {
    ["Up left"]    = {h = Enum.HorizontalAlignment.Left,  v = Enum.VerticalAlignment.Top,    x = -1, pt = 66, pb = 0,  pl = 10, pr = 0},
    ["Up right"]   = {h = Enum.HorizontalAlignment.Right, v = Enum.VerticalAlignment.Top,    x = 1,  pt = 44, pb = 0,  pl = 0,  pr = 10},
    ["Down left"]  = {h = Enum.HorizontalAlignment.Left,  v = Enum.VerticalAlignment.Bottom, x = -1, pt = 0,  pb = 10, pl = 10, pr = 0},
    ["Down right"] = {h = Enum.HorizontalAlignment.Right, v = Enum.VerticalAlignment.Bottom, x = 1,  pt = 0,  pb = 10, pl = 0,  pr = 10},
}
function Lib:SetNotifySide(s)
    local d = Sides[s]; if not d then return end
    Lib.NotifySide = s
    NL.HorizontalAlignment, NL.VerticalAlignment = d.h, d.v
    NP.PaddingTop, NP.PaddingBottom, NP.PaddingLeft, NP.PaddingRight = UDim.new(0,d.pt), UDim.new(0,d.pb), UDim.new(0,d.pl), UDim.new(0,d.pr)
end
Lib:SetNotifySide(Lib.NotifySide)
local nCount = 0
function Lib:Notify(txt, dur)
    if not Lib.NotifyEnabled or Lib.Unloaded then return end
    dur = dur or Lib.NotifyTime
    nCount += 1
    local dir = Sides[Lib.NotifySide].x
    local plain = tostring(txt):gsub("<[^>]+>", "")
    local w, h = TextService:GetTextSize(plain, Lib.Size, Lib.Font, Vector2.new(400, 100)).X + 26, 28
    local slot = New("Frame", {Size = UDim2.new(0,w,0,0), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = nCount}, NH)
    local hidden = UDim2.new(0, dir * (w + 4), 0, 0)
    local n = New("Frame", {Size = UDim2.new(1,0,0,h), Position = hidden, BackgroundColor3 = T.PanelHi, BorderSizePixel = 0}, slot)
    Stroke(n); Shade(n, 1, 0.6); Round(n, 4)
    Text(n, txt, {P = UDim2.new(0,10,0,0), S = UDim2.new(1,-20,1,-2)})
    local line = New("Frame", {Size = UDim2.new(1,0,0,2), Position = UDim2.new(0,0,1,-2), BackgroundColor3 = T.Accent, BorderSizePixel = 0}, n)
    TS:Create(slot, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,w,0,h)}):Play()
    TS:Create(n, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new()}):Play()
    TS:Create(line, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0,0,0,2)}):Play()
    task.delay(dur, function()
        if not n.Parent then return end
        local t1 = TS:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = hidden}); t1:Play(); t1.Completed:Wait()
        if not slot.Parent then return end
        local t2 = TS:Create(slot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(0,w,0,0)}); t2:Play(); t2.Completed:Wait()
        slot:Destroy()
    end)
end
Lib.notify = Lib.Notify -- lowercase alias
pcall(function()
    local e = (getgenv and getgenv()) or _G
    e.Library = Lib
    shared.Library = Lib
end)

-- ===== Popups (stack: dropdown / color picker / key mode menu, plus kept gear panels) =====
local popups = {}
Lib._popHit = 0
-- stamped whenever a click lands on a popup, so the outside-click blocker can tell "clicked inside" from "clicked outside"
local function MarkPop() Lib._popHit = tick() end
local function PopPress(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then MarkPop() end
end
local SyncBlocker = function() end -- assigned below once the blocker exists
local function ClosePopup(top)
    local function kill(p) if p:GetAttribute("keep") then p.Parent = nil else p:Destroy() end end
    if top then local p = table.remove(popups); if p then kill(p) end; SyncBlocker(); return end
    for _, p in ipairs(popups) do kill(p) end
    popups = {}
    SyncBlocker()
end
-- anchor-relative placement. All maths is done in the gui's own coordinate space (AbsolutePosition - Origin())
local function OpenPopup(anchor, size, above)
    local child = anchor:FindFirstAncestor("GearPanel") ~= nil
    if child then while #popups > 1 do ClosePopup(true) end else ClosePopup() end
    local scr, org = ScreenSize(), Origin()
    local ax, ay, ah = anchor.AbsolutePosition.X - org.X, anchor.AbsolutePosition.Y - org.Y, anchor.AbsoluteSize.Y
    local ph = size.Y.Offset
    local x = math.clamp(ax, 4, math.max(scr.X - size.X.Offset - 4, 4))
    local y
    if above then
        y = ay - ph - 2                                        -- directly above the anchor, touching it
        if y < 4 then y = ay + ah + 2 end                      -- no room above -> go below
    else
        y = ay + ah + 2                                        -- right under the anchor
        if y + ph > scr.Y - 4 then y = math.max(ay - ph - 2, 4) end
    end
    local f = New("Frame", {Size = size, BackgroundColor3 = T.Panel2, BorderSizePixel = 0, ZIndex = child and 60 or 50, Active = true,
        Position = UDim2.fromOffset(x, y)}, gui)
    Stroke(f); Shade(f, 1, 0.7); Round(f, 4)
    f.InputBegan:Connect(PopPress)
    table.insert(popups, f)
    SyncBlocker()
    return f
end
local function OpenKept(frame, anchor)
    ClosePopup()
    local sz, org = ScreenSize(), Origin()
    if not frame:GetAttribute("moved") then
        local ax, ay = anchor.AbsolutePosition.X - org.X, anchor.AbsolutePosition.Y - org.Y
        frame.Position = UDim2.fromOffset(math.clamp(ax - 190, 4, math.max(sz.X - 214, 4)),
            math.clamp(ay + anchor.AbsoluteSize.Y + 2, 4, math.max(sz.Y - 140, 4)))
    end
    if not frame:GetAttribute("marked") then frame:SetAttribute("marked", true); frame.InputBegan:Connect(PopPress) end
    frame.Parent = gui
    table.insert(popups, frame)
    SyncBlocker()
end

-- full-screen click blocker that sits BEHIND the popups (zindex 45 < 50) and above the main window.
local Blocker = New("TextButton", {Name = "Blocker", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    Active = true, Visible = false, ZIndex = 45}, gui)
Blocker.InputBegan:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
        -- InputBegan can reach the blocker even when the click was on a popup; wait a tick and check whether a popup claimed it
        task.delay(0.02, function()
            if tick() - Lib._popHit < 0.15 then return end
            Lib._lastClosed = {p = popups[1], t = tick()}
            ClosePopup()
        end)
    end
end)
SyncBlocker = function() Blocker.Visible = #popups > 0 end

-- ===== LinoriaLib-style core: Toggles / Options tables, :OnChanged, :AddKeyPicker, :AddColorPicker =====
local Toggles, Options = {}, {}
Lib.Toggles, Lib.Options, Lib._pickers, Lib._unload, Lib.Unloaded = Toggles, Options, {}, {}, false
pcall(function() local e = (getgenv and getgenv()) or _G; e.Toggles, e.Options, e.Library = Toggles, Options, Lib end)
Lib.Watermark, Lib.KeybindFrame = WM, KBL
function Lib:SetWatermarkVisibility(b) WM.Visible = b end
function Lib:OnUnload(f) table.insert(Lib._unload, f) end
function Lib:Unload() Lib.Unloaded = true; wmConn:Disconnect(); hbConn:Disconnect(); gradConn:Disconnect(); for _, f in ipairs(Lib._unload) do pcall(f) end; gui:Destroy() end

local function Changeable(o) o._changed = {}; function o:OnChanged(f) table.insert(o._changed, f); return o end end
local function Fire(o, cb) if cb then task.spawn(cb, o.Value) end; for _, f in ipairs(o._changed) do task.spawn(f, o.Value) end end
local function KeyIs(i, key)
    if not key then return false end
    if #key == 3 and key:sub(1,2) == "MB" then return i.UserInputType.Name == "MouseButton" .. key:sub(3) end
    return i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name == key
end
-- right-side widget slots on a row (color swatches, gear, key) fill from the right edge
local function Place(row, w) local r = row:GetAttribute("rx") or -4; row:SetAttribute("rx", r - w - 6); return r - w end
-- real checkerboard (5px cells) behind transparent colors. Call after the parent has its final ZIndex
local function Checker(p)
    local cell = 5
    p.BackgroundColor3 = Color3.fromRGB(150,150,150)
    p.ClipsDescendants = true
    for x = 0, 34 do
        for y = 0, 1 do
            if (x + y) % 2 == 1 then
                New("Frame", {Size = UDim2.fromOffset(cell, cell), Position = UDim2.fromOffset(x * cell, y * cell),
                    BackgroundColor3 = Color3.fromRGB(95,95,95), BorderSizePixel = 0, ZIndex = p.ZIndex}, p)
            end
        end
    end
end
local function KP(t, r, g, b) return ColorSequenceKeypoint.new(t, Color3.fromRGB(r, g, b)) end
local function IsClick(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end

local function AddColor(row, idx, info)
    info = info or {}
    local alpha = info.Transparency ~= nil
    local c0 = info.Default or Color3.new(1,1,1)
    local P = {Type = "ColorPicker", Title = info.Title or idx, Value = c0, Transparency = info.Transparency or 0}
    Changeable(P)
    P.Hue, P.Sat, P.Vib = c0:ToHSV()
    local left = Place(row, 20)
    local b = New("TextButton", {Size = UDim2.new(0,20,0,10), Position = UDim2.new(1,left,0.5,-5), BackgroundColor3 = c0, Text = "", BorderSizePixel = 0, AutoButtonColor = false}, row)
    Round(b, 3)
    local fill = b
    if alpha then
        Checker(b)
        fill = New("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = c0, BackgroundTransparency = P.Transparency, BorderSizePixel = 0}, b)
    end
    Shade(fill, 1, 0.7)

    local function refresh(silent)
        P.Value = Color3.fromHSV(P.Hue, P.Sat, P.Vib)
        fill.BackgroundColor3 = P.Value
        if alpha then fill.BackgroundTransparency = P.Transparency end
        if P._ui then P._ui() end -- keep an open popup in sync
        if not silent then Fire(P, info.Callback) end
    end
    function P:SetValue(hsv, tr) P.Hue, P.Sat, P.Vib = hsv[1], hsv[2], hsv[3]; if tr then P.Transparency = tr end; refresh() end
    function P:SetValueRGB(c, tr) P.Hue, P.Sat, P.Vib = c:ToHSV(); if tr then P.Transparency = tr end; refresh() end
    refresh(true)

    -- screen-space pointer position (same space as AbsolutePosition with IgnoreGuiInset = true)
    -- Lib._pshift is calibrated on every swatch click (see below) so the pointer lands in the same space as AbsolutePosition
    local function Pt(i)
        local raw
        if i and i.UserInputType == Enum.UserInputType.Touch then
            raw = Vector2.new(i.Position.X, i.Position.Y) + GuiService:GetGuiInset()
        else
            raw = UIS:GetMouseLocation()
        end
        return raw + (Lib._pshift or Vector2.zero)
    end

    b.MouseButton1Click:Connect(function()
        -- the pointer is on the swatch right now: pick the pointer->gui offset (0, -inset, +inset) that puts it inside the swatch
        do
            local m, inset = UIS:GetMouseLocation(), GuiService:GetGuiInset()
            local a, sz = b.AbsolutePosition, b.AbsoluteSize
            for _, sft in ipairs({Vector2.zero, -inset, inset}) do
                local v = m + sft
                if v.X >= a.X - 2 and v.X <= a.X + sz.X + 2 and v.Y >= a.Y - 2 and v.Y <= a.Y + sz.Y + 2 then Lib._pshift = sft; break end
            end
        end
        local PW, ph = 186, (alpha and 150 or 134) + 18
        local p = OpenPopup(b, UDim2.new(0, PW, 0, ph))
        local scr, org = ScreenSize(), Origin()
        local bx, by = b.AbsolutePosition.X - org.X, b.AbsolutePosition.Y - org.Y
        local px = bx + b.AbsoluteSize.X + 8
        if px + PW > scr.X - 4 then px = bx - PW - 8 end
        p.Position = UDim2.fromOffset(math.clamp(px, 4, math.max(scr.X - PW - 4, 4)), math.clamp(by - 8, 4, math.max(scr.Y - ph - 4, 4)))

        local hdr = New("Frame", {Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 51}, p)
        Text(hdr, tostring(P.Title), {Bold = true, P = UDim2.new(0,8,0,0), S = UDim2.new(1,-8,1,0), Color = T.Accent, Size = 12})
        New("Frame", {Size = UDim2.new(1,-16,0,1), Position = UDim2.new(0,8,1,-1), BackgroundColor3 = T.Border, BorderSizePixel = 0, ZIndex = 51}, hdr)
        PopDrag(hdr, p)

        -- saturation / value square
        local sv = New("TextButton", {Size = UDim2.new(0,170,0,100), Position = UDim2.new(0,8,0,26), BorderSizePixel = 0, ZIndex = 51, Text = "", AutoButtonColor = false}, p)
        local wh = New("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 52}, sv)
        New("UIGradient", {Transparency = NumberSequence.new(0, 1)}, wh)
        local bk = New("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, ZIndex = 53}, sv)
        New("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, bk)
        local svc = New("Frame", {Size = UDim2.new(0,6,0,6), AnchorPoint = Vector2.new(.5,.5), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 55}, sv)
        Stroke(svc, Color3.new(0,0,0))

        -- hue bar
        local hb = New("TextButton", {Size = UDim2.new(0,170,0,10), Position = UDim2.new(0,8,0,132), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 51, Text = "", AutoButtonColor = false}, p)
        New("UIGradient", {Color = ColorSequence.new({KP(0,255,0,0), KP(1/6,255,255,0), KP(2/6,0,255,0), KP(3/6,0,255,255), KP(4/6,0,0,255), KP(5/6,255,0,255), KP(1,255,0,0)})}, hb)
        local hc = New("Frame", {Size = UDim2.new(0,2,1,4), AnchorPoint = Vector2.new(.5,.5), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 55}, hb)
        Stroke(hc, Color3.new(0,0,0))

        -- alpha bar
        local ab, ag, ac
        if alpha then
            ab = New("TextButton", {Size = UDim2.new(0,170,0,10), Position = UDim2.new(0,8,0,148), BorderSizePixel = 0, ZIndex = 51, Text = "", AutoButtonColor = false}, p)
            Checker(ab)
            ag = New("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = P.Value, BorderSizePixel = 0, ZIndex = 52}, ab)
            New("UIGradient", {Transparency = NumberSequence.new(0, 1)}, ag)
            ac = New("Frame", {Size = UDim2.new(0,2,1,4), AnchorPoint = Vector2.new(.5,.5), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 55}, ab)
            Stroke(ac, Color3.new(0,0,0))
        end

        local function ui()
            sv.BackgroundColor3 = Color3.fromHSV(P.Hue, 1, 1)
            svc.Position = UDim2.new(P.Sat, 0, 1 - P.Vib, 0)
            hc.Position = UDim2.new(P.Hue, 0, 0.5, 0)
            if alpha then ag.BackgroundColor3 = P.Value; ac.Position = UDim2.new(P.Transparency, 0, 0.5, 0) end
        end
        P._ui = ui

        local drag
        local function upd(m)
            local function fx(fr) return math.clamp((m.X - fr.AbsolutePosition.X) / math.max(fr.AbsoluteSize.X, 1), 0, 1) end
            if drag == "sv" then
                P.Sat = fx(sv)
                P.Vib = 1 - math.clamp((m.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
            elseif drag == "h" then P.Hue = math.min(fx(hb), 0.999) -- 1.0 wraps back to red
            elseif drag == "a" then P.Transparency = fx(ab) end
            refresh() -- also calls ui() through P._ui
        end
        local function hook(fr, n) fr.InputBegan:Connect(function(i) if IsClick(i) then drag = n; MarkPop(); upd(Pt(i)) end end) end
        hook(sv, "sv"); hook(hb, "h"); if alpha then hook(ab, "a") end

        local c1 = UIS.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(Pt(i)) end
        end)
        local c2 = UIS.InputEnded:Connect(function(i) if IsClick(i) then drag = nil end end)
        p.Destroying:Connect(function() c1:Disconnect(); c2:Disconnect(); P._ui = nil end)
        ui()
    end)
    Options[idx] = P
    return P
end

local function AddKey(row, idx, info, tog)
    info = info or {}
    local K = {Type = "KeyPicker", Value = info.Default, Mode = info.Mode or "Toggle", Text = info.Text or (tog and tog.Text) or idx, NoUI = info.NoUI, _state = false, _clicked = {}}
    Changeable(K)
    local sync = info.SyncToggleState and tog or nil
    function K:OnClick(f) table.insert(K._clicked, f) end
    function K:GetState()
        if K.Mode == "Always" then return true end
        if sync then return sync.Value end
        return K._state
    end
    function K:_press()
        if K.Mode == "Toggle" then local n = not K:GetState(); K._state = n; if sync then sync:SetValue(n) end
        elseif K.Mode == "Hold" then K._state = true; if sync then sync:SetValue(true) end
        else return end
        for _, f in ipairs(K._clicked) do task.spawn(f) end
        Lib:RefreshKeybinds()
    end
    function K:_release()
        if K.Mode == "Hold" and K._state then K._state = false; if sync then sync:SetValue(false) end; Lib:RefreshKeybinds() end
    end
    local w = TextService:GetTextSize("[" .. (K.Value or "None") .. "]", 12, Lib.Font, Vector2.new(300, 50)).X + 6
    local left = Place(row, w)
    local b = New("TextButton", {Size = UDim2.new(0,w,0,16), Position = UDim2.new(1,left,0.5,-8), BackgroundTransparency = 1, Font = Lib.Font, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, AutoButtonColor = false, Text = ""}, row)
    local function show() b.Text = "[" .. (K.Value or "None") .. "]"; b.TextColor3 = T.Dim end
    show()
    b.MouseButton1Click:Connect(function()
        if Lib._listening then return end
        Lib._listening = true; b.Text, b.TextColor3 = "[...]", T.Accent
        task.wait()
        local c; c = UIS.InputBegan:Connect(function(i)
            local n
            if i.UserInputType == Enum.UserInputType.Keyboard then n = i.KeyCode.Name
            elseif i.UserInputType.Name:find("^MouseButton%d") then n = "MB" .. i.UserInputType.Name:match("%d")
            else return end
            if n == "Escape" then n = nil end
            K.Value = n; show(); c:Disconnect(); Lib._listening = false
            Lib:RefreshKeybinds(); Fire(K, info.ChangedCallback)
        end)
    end)
    b.MouseButton2Click:Connect(function() -- right click = mode menu (Always / Toggle / Hold)
        local p = OpenPopup(b, UDim2.new(0,72,0,60))
        New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, p)
        for n, m in ipairs({"Always", "Toggle", "Hold"}) do
            local ob = New("TextButton", {Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1, Text = " " .. m, Font = Lib.Font, TextSize = 12, ZIndex = 51, LayoutOrder = n,
                TextColor3 = K.Mode == m and T.Accent or T.Text, TextXAlignment = Enum.TextXAlignment.Left}, p)
            ob.MouseButton1Click:Connect(function() K.Mode = m; ClosePopup(true); Lib:RefreshKeybinds() end)
        end
    end)
    function K:SetValue(t) K.Value = t[1]; K.Mode = t[2] or K.Mode; show(); Lib:RefreshKeybinds() end
    table.insert(Lib._pickers, K)
    Options[idx] = K
    return K
end

Lib._baseTrans, Lib.FadeTime = 0, 0.2
Lib.TVEffect = true
function Lib:ToggleMenu()
    Lib.Open = not Lib.Open
    ClosePopup()
    local m = Lib._main
    if not m then return end
    if Lib._fade then Lib._fade:Cancel() end
    local tv = Lib._tv
    if not (Lib.TVEffect and tv) then
        Lib._tvBusy = false
        if Lib.Open then
            m.GroupTransparency = 1
            m.Visible = true
            Lib._fade = TS:Create(m, TweenInfo.new(Lib.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = Lib._baseTrans})
            Lib._fade:Play()
        else
            local t = TS:Create(m, TweenInfo.new(Lib.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
            Lib._fade = t
            t.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and not Lib.Open then m.Visible = false end
            end)
            t:Play()
        end
        return
    end
    -- CRT TV: the window itself grows from a line (width first, then height) and shrinks back down to a line, then a dot
    Lib._tvTok = (Lib._tvTok or 0) + 1
    local tok = Lib._tvTok
    local function tw(o, t, p, st, dr) local x = TS:Create(o, TweenInfo.new(t, st or Enum.EasingStyle.Quad, dr or Enum.EasingDirection.Out), p); x:Play(); return x end
    local win, line, full = tv.win, tv.line, tv.size
    Lib._tvBusy = true
    m.GroupTransparency = Lib._baseTrans
    m.Visible = true
    win.ClipsDescendants, line.Visible = true, true
    task.spawn(function()
        if Lib.Open then
            win.Size = UDim2.fromOffset(0, 2)
            line.BackgroundTransparency = 0
            tw(win, 0.16, {Size = UDim2.fromOffset(full.X.Offset, 2)}).Completed:Wait()
            if tok ~= Lib._tvTok then return end
            tw(line, 0.3, {BackgroundTransparency = 1})
            tw(win, 0.32, {Size = full}, Enum.EasingStyle.Quint).Completed:Wait()
            if tok ~= Lib._tvTok then return end
            win.ClipsDescendants, line.Visible = false, false
            Lib._tvBusy = false
        else
            line.BackgroundTransparency = 1
            tw(line, 0.25, {BackgroundTransparency = 0}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tw(win, 0.25, {Size = UDim2.fromOffset(full.X.Offset, 2)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In).Completed:Wait()
            if tok ~= Lib._tvTok then return end
            tw(win, 0.16, {Size = UDim2.fromOffset(0, 2)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
            if tok ~= Lib._tvTok then return end
            m.Visible, line.Visible = false, false
            win.Size, win.ClipsDescendants = full, false
            Lib._tvBusy = false
        end
    end)
end
Lib.Toggle = Lib.ToggleMenu
UIS.InputBegan:Connect(function(i, gp)
    if Lib.Unloaded then return end
    if gp or Lib._listening then return end
    -- menu key: any key / mouse button picked in Config > About > "Menu key" (falls back to Insert if unbound)
    local tk = Lib.ToggleKeybind
    local mk = tk and tk.Value
    if (mk and KeyIs(i, mk)) or (not mk and i.KeyCode == Lib.ToggleKey) then Lib:ToggleMenu() end
    for _, k in ipairs(Lib._pickers) do if k.Value and KeyIs(i, k.Value) then k:_press() end end
end)
UIS.InputEnded:Connect(function(i)
    if Lib.Unloaded then return end
    for _, k in ipairs(Lib._pickers) do if k.Value and KeyIs(i, k.Value) then k:_release() end end
end)

-- ===== Target HUD (avatar, name, weapon, ammo) =====
--       Lib.TargetHud.Range = 250        auto target = closest player to screen center within this many pixels
local TH = {Enabled = true, Override = nil, Current = nil, Range = 250, Hold = 1.5, GetInfo = nil}
Lib.TargetHud = TH

local THF = New("CanvasGroup", {Name = "TargetHud", Size = UDim2.new(0,230,0,92), Position = UDim2.new(0.5,-115,0.62,0), GroupTransparency = 1,
    BackgroundColor3 = T.PanelHi, BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true, Visible = false}, gui)
Stroke(THF); Shade(THF, 1, 0.6); Drag(THF, THF); Round(THF, 4)
local thScale = New("UIScale", {Scale = 1}, THF)
function TH:SetScale(n) thScale.Scale = math.clamp(n, 0.5, 3) end
local thBar = GradC(New("Frame", {Size = UDim2.new(1,0,0,2), BorderSizePixel = 0}, THF), T.Accent, T.Bar, 0)
Th(function() thBar.Color = ColorSequence.new(T.Accent, T.Accent:Lerp(Color3.new(0,0,0), 0.45)) end)

local thAvBox = New("Frame", {Size = UDim2.new(0,46,0,46), Position = UDim2.new(0,8,0,10), BackgroundColor3 = Color3.fromRGB(26,26,30), BorderSizePixel = 0}, THF)
local thAvS = Stroke(thAvBox, T.Bar); Shade(thAvBox, 1, 0.7); Round(thAvBox, 4)
Th(function() thAvS.Color = T.Bar end)
local thAv = New("ImageLabel", {Size = UDim2.new(1,-2,1,-2), Position = UDim2.new(0,1,0,1), BackgroundTransparency = 1, BorderSizePixel = 0, Image = ""}, thAvBox)
Round(thAv, 3)

local thName = Text(THF, "", {Bold = true, P = UDim2.new(0,62,0,8), S = UDim2.new(1,-124,0,16)})
thName.TextTruncate = Enum.TextTruncate.AtEnd
AnimGrad(thName)
local thDist = Text(THF, "", {Color = T.Dim, Size = 12, Align = Enum.TextXAlignment.Right, P = UDim2.new(1,-62,0,8), S = UDim2.new(0,54,0,16)})
local thRows = {}
for n = 1, 4 do
    local y = 27 + (n - 1) * 15
    local num = Text(THF, tostring(n), {Color = T.Dim, Size = 12, P = UDim2.new(0,62,0,y), S = UDim2.new(0,12,0,14)})
    local nm = Text(THF, "", {Size = 12, P = UDim2.new(0,76,0,y), S = UDim2.new(1,-140,0,14)}); nm.TextTruncate = Enum.TextTruncate.AtEnd
    local am = Text(THF, "", {Size = 12, Align = Enum.TextXAlignment.Right, P = UDim2.new(1,-62,0,y), S = UDim2.new(0,54,0,14)})
    thRows[n] = {num = num, nm = nm, am = am}
end

local function readAmmo(tool)
    if not tool then return nil end
    local function g(n)
        local v = tool:GetAttribute(n)
        if v ~= nil then return v end
        local o = tool:FindFirstChild(n, true)
        if o and o:IsA("ValueBase") then return o.Value end
    end
    return g("Ammo") or g("CurrentAmmo") or g("Clip") or g("Mag"), g("MaxAmmo") or g("MaxClip") or g("ClipSize") or g("MagSize")
end
-- 4 weapon slots. Default: the target's Tools (Character + Backpack), kept in the order they were first seen.
-- NOTE: other players' Backpack is usually NOT replicated, so in many games you only see the equipped tool -> use Lib.TargetHud.GetInfo
-- to return {Slots = {{Name = "AK-47", Ammo = 24, MaxAmmo = 30, Equipped = true}, {Name = "Glock", Ammo = 17}, ...}}
local thOrder = {}
local function slotsOf(p)
    if TH.GetInfo then
        local ok, r = pcall(TH.GetInfo, p)
        if ok and type(r) == "table" and type(r.Slots) == "table" then return r.Slots end
    end
    local ord = thOrder[p]
    if not ord then ord = {}; thOrder[p] = ord end
    local tools = {}
    local ch, bp = p.Character, p:FindFirstChildOfClass("Backpack")
    if ch then for _, t in ipairs(ch:GetChildren()) do if t:IsA("Tool") then tools[#tools+1] = {t, true} end end end
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then tools[#tools+1] = {t, false} end end end
    for _, e in ipairs(tools) do
        if not table.find(ord, e[1].Name) then ord[#ord+1] = e[1].Name end
    end
    table.sort(tools, function(a, b) return table.find(ord, a[1].Name) < table.find(ord, b[1].Name) end)
    local out = {}
    for n = 1, math.min(#tools, 4) do
        local a, m = readAmmo(tools[n][1])
        out[n] = {Name = tools[n][1].Name, Ammo = a, MaxAmmo = m, Equipped = tools[n][2]}
    end
    return out
end
local function alive(p)
    local ch = p and p.Character
    local h = ch and ch:FindFirstChildOfClass("Humanoid")
    return ch and h and h.Health > 0 and ch:FindFirstChild("HumanoidRootPart") and true or false
end
local function autoTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local c, best, bd = cam.ViewportSize / 2, nil, TH.Range
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p) then
            local v, on = cam:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
            if on then
                local d = (Vector2.new(v.X, v.Y) - c).Magnitude
                if d < bd then best, bd = p, d end
            end
        end
    end
    return best
end

function TH:Set(p) TH.Override = p end
function TH:Clear() TH.Override = nil end

local thShown, thShownPlr, thLostAt, thT = false, nil, 0, 0
local function thFade(show)
    if show == thShown then return end
    thShown = show
    if show then THF.Visible = true end
    local t = TS:Create(THF, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {GroupTransparency = show and 0 or 1})
    t.Completed:Connect(function() if not thShown then THF.Visible = false end end)
    t:Play()
end
local thConn = RS.RenderStepped:Connect(function()
    if tick() - thT < 0.1 then return end
    thT = tick()
    if Lib.Unloaded then return end
    if not TH.Enabled then thFade(false); return end
    local p = TH.Override
    if p and not p.Parent then TH.Override = nil; p = nil end
    p = p or autoTarget()
    if p then TH.Current, thLostAt = p, tick()
    elseif TH.Current and tick() - thLostAt < TH.Hold and TH.Current.Parent then p = TH.Current
    else TH.Current = nil end
    if not p then thFade(false); return end
    if p ~= thShownPlr then
        thShownPlr = p
        thAv.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"
        thName.Text = p.DisplayName
    end
    local mr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local tr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    thDist.Text = (mr and tr) and ("[" .. math.floor((mr.Position - tr.Position).Magnitude + 0.5) .. "m]") or "[?m]"
    local sl = slotsOf(p)
    for n = 1, 4 do
        local r, d = thRows[n], sl[n]
        if d then
            local col = d.Equipped and T.Accent or T.Text
            r.nm.Text, r.nm.TextColor3, r.num.TextColor3 = tostring(d.Name), col, d.Equipped and T.Accent or T.Dim
            r.am.Text = "[" .. (d.Ammo ~= nil and (d.MaxAmmo and (d.Ammo .. "/" .. d.MaxAmmo) or tostring(d.Ammo)) or "--") .. "]"
            r.am.TextColor3 = d.Equipped and T.Accent or T.Dim
        else
            r.nm.Text, r.nm.TextColor3, r.num.TextColor3 = "--", T.Dim, T.Dim
            r.am.Text, r.am.TextColor3 = "[ ]", T.Dim
        end
    end
    thFade(true)
end)
Lib:OnUnload(function() thConn:Disconnect() end)


-- ===== Configs (writefile if the executor has it, otherwise in-memory for this session) =====
local CFG_DIR = "cynth/configs"
local fs = type(writefile) == "function" and type(readfile) == "function" and type(isfolder) == "function"
    and type(makefolder) == "function" and type(listfiles) == "function"
Lib._mem = {}
pcall(function()
    if fs then
        if not isfolder("cynth") then makefolder("cynth") end
        if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
    end
end)
local function skipId(id) return id:find("^cfg_") ~= nil or id == "autoload" or id == "saveexit" end
function Lib:CfgList()
    local t = {}
    if fs then
        pcall(function() for _, f in ipairs(listfiles(CFG_DIR)) do local n = f:match("([^/\\]+)%.json$"); if n then t[#t+1] = n end end end)
    else for n in pairs(Lib._mem) do t[#t+1] = n end end
    table.sort(t); return t
end
function Lib:CfgEncode()
    local tg, op = {}, {}
    for id, o in pairs(Toggles) do if not skipId(id) then tg[id] = o.Value end end
    for id, o in pairs(Options) do
        if not skipId(id) then
            local t = o.Type
            if t == "Slider" or t == "Input" or t == "Dropdown" then op[id] = {v = o.Value}
            elseif t == "ColorPicker" then op[id] = {h = o.Hue, s = o.Sat, b = o.Vib, t = o.Transparency}
            elseif t == "KeyPicker" then op[id] = {k = o.Value or "", m = o.Mode} end
        end
    end
    return HttpService:JSONEncode({Toggles = tg, Options = op})
end
function Lib:CfgApply(json)
    local ok, d = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(d) ~= "table" then return false end
    for id, v in pairs(d.Toggles or {}) do local o = Toggles[id]; if o then pcall(function() o:SetValue(v) end) end end
    for id, e in pairs(d.Options or {}) do
        local o = Options[id]
        if o and type(e) == "table" then
            pcall(function()
                if o.Type == "Slider" then if e.v ~= nil then o:SetValue(e.v) end
                elseif o.Type == "Input" or o.Type == "Dropdown" then o:SetValue(e.v)
                elseif o.Type == "ColorPicker" then o:SetValue({e.h, e.s, e.b}, e.t)
                elseif o.Type == "KeyPicker" then o:SetValue({e.k ~= "" and e.k or nil, e.m}) end
            end)
        end
    end
    Lib:RefreshKeybinds()
    return true
end
function Lib:CfgWrite(name) local s = Lib:CfgEncode(); if fs then writefile(CFG_DIR .. "/" .. name .. ".json", s) else Lib._mem[name] = s end end
function Lib:CfgRead(name)
    if fs then local ok, s = pcall(readfile, CFG_DIR .. "/" .. name .. ".json"); return ok and s or nil end
    return Lib._mem[name]
end
function Lib:CfgDel(name) if fs then pcall(function() delfile(CFG_DIR .. "/" .. name .. ".json") end) else Lib._mem[name] = nil end end
function Lib:CfgExists(name) for _, n in ipairs(Lib:CfgList()) do if n == name then return true end end return false end

-- ===== Window =====
function Lib:CreateWindow(info, size)
    local title
    if type(info) == "table" then title, size = info.Title or "cynth", info.Size or size else title = info or "cynth" end
    size = size or UDim2.new(0,720,0,575)
    local W = {Tabs = {}, Rows = {}, First = true}
    -- Win: animated clip frame (this is what really grows / shrinks for the TV effect). Main keeps its full size inside it, centered, so nothing gets squished
    local Win = New("Frame", {Name = "Win", Size = size, AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new(.5,0,.5,0), BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
    local Main = New("CanvasGroup", {GroupTransparency = 0, Size = size, AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new(.5,0,.5,0), BackgroundColor3 = Color3.fromRGB(21,21,25),
        BorderSizePixel = 0, Active = true}, Win)
    Stroke(Main, Color3.fromRGB(38,38,42)); Shade(Main, 1, 0.5); Round(Main, 6)
    local shLine = New("Frame", {Size = UDim2.new(1,0,0,2), AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new(.5,0,.5,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 100, Visible = false}, Win)
    Lib._tv = {win = Win, line = shLine, size = size}

    -- soft drop shadow behind the window (lives outside Main, so it follows Main's visibility / fade by sync)
    local sh = New("ImageLabel", {BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0,0,0),
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49,49,450,450), Size = UDim2.new(1,40,1,40), Position = UDim2.new(0,-20,0,-20), ZIndex = 0}, Win)
    local shc = RS.RenderStepped:Connect(function()
        sh.Visible = Main.Visible
        sh.ImageTransparency = 0.45 + 0.55 * Main.GroupTransparency
    end)
    Lib:OnUnload(function() shc:Disconnect() end)

    local TB = New("Frame", {Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1, Active = true}, Main); Drag(TB, Win)
    local TitleL = Text(TB, title, {Bold = true, P = UDim2.new(0,12,0,0), S = UDim2.new(0,0,1,0)})
    TitleL.AutomaticSize = Enum.AutomaticSize.X
    AnimGrad(TitleL)
    local Inner = New("Frame", {Size = UDim2.new(1,-16,1,-34), Position = UDim2.new(0,8,0,28), BackgroundColor3 = Color3.fromRGB(24,24,28), BorderSizePixel = 0}, Main)
    Stroke(Inner, Color3.fromRGB(34,34,38)); Shade(Inner, 1, 0.55); Round(Inner, 5)
    local topLine = GradC(New("Frame", {Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,0,27), BorderSizePixel = 0}, Main), T.Accent, T.Accent, 0, 0.2, 1)
    Th(function() topLine.Color = ColorSequence.new(T.Accent, T.Accent) end)
    local TabRow = New("Frame", {Size = UDim2.new(1,-12,0,24), Position = UDim2.new(0,6,0,4), BackgroundTransparency = 1}, Inner)
    local TabLayout = New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,2), VerticalAlignment = Enum.VerticalAlignment.Center}, TabRow)
    -- sliding underline that follows the selected tab
    local Ind = New("Frame", {Size = UDim2.new(0,0,0,2), Position = UDim2.new(0,6,0,26), BackgroundColor3 = T.Accent, BorderSizePixel = 0}, Inner)
    Th(function() Ind.BackgroundColor3 = T.Accent end)
    local Body = New("Frame", {Size = UDim2.new(1,-20,1,-42), Position = UDim2.new(0,10,0,34), BackgroundTransparency = 1}, Inner)

    -- search
    local S = New("Frame", {Size = UDim2.new(0,170,0,22), Position = UDim2.new(1,-180,0,5), BackgroundTransparency = 1}, Inner)
    -- search bar fills whatever width is left after the tabs (adapts when tabs are added)
    local function fitSearch()
        local x = 6 + TabLayout.AbsoluteContentSize.X + 10
        S.Position = UDim2.new(0, x, 0, 5)
        S.Size = UDim2.new(1, -x - 8, 0, 22)
    end
    TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitSearch)
    fitSearch()
    local ring = New("Frame", {Size = UDim2.new(0,8,0,8), Position = UDim2.new(0,4,0,5), BackgroundTransparency = 1}, S)
    Stroke(ring, T.Dim)
    New("Frame", {Size = UDim2.new(0,5,0,1), Position = UDim2.new(0,10,0,15), Rotation = 45, BackgroundColor3 = T.Dim, BorderSizePixel = 0}, S)
    local sb = New("TextBox", {Size = UDim2.new(1,-24,1,0), Position = UDim2.new(0,22,0,0), BackgroundTransparency = 1, Text = "", PlaceholderText = "search",
        PlaceholderColor3 = T.Dim, TextColor3 = T.Text, Font = Lib.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false}, S)
    local sg = GradC(New("Frame", {Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BorderSizePixel = 0}, S), T.Bar, T.Border, 0)
    Th(function() sg.Color = ColorSequence.new(T.Bar, T.Border) end)
    sb:GetPropertyChangedSignal("Text"):Connect(function()
        local q = sb.Text:lower()
        for _, r in ipairs(W.Rows) do r.f.Visible = q == "" or r.t:lower():find(q, 1, true) ~= nil end
    end)

    Lib._main = Main
    if type(info) == "table" and info.AutoShow == false then Main.Visible = false; Lib.Open = false end

    function W:SetWindowTitle(t) TitleL.Text = t end
    local function Reg(f, t) table.insert(W.Rows, {f = f, t = t or ""}) end

    local function Box(col, name, h)
        local num, fill = type(h) == "number", h == "fill"
        local box = New("Frame", {Size = num and UDim2.new(1,0,0,h) or (fill and UDim2.new(1,0,1,0) or UDim2.new(1,0,0,0)),
            AutomaticSize = (not num and not fill) and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            BackgroundColor3 = Color3.fromRGB(28,28,32), BorderSizePixel = 0}, col)
        Stroke(box, Color3.fromRGB(34,34,38)); Shade(box, 1, 0.62); Round(box, 4)
        local bl = GradC(New("Frame", {Size = UDim2.new(1,0,0,2), BorderSizePixel = 0}, box), T.Accent, T.Bar, 0)
        Th(function() bl.Color = ColorSequence.new(T.Accent, T.Accent:Lerp(Color3.new(0,0,0), 0.45)) end)
        -- title sits on the top edge of the box (above the content), with a patch hiding the border behind it
        -- no visible patch box: only a thin strip (same color as the box top) cuts the border + accent bar behind the title
        local tl = New("Frame", {Size = UDim2.new(0,0,0,16), Position = UDim2.new(0,8,0,-8), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3}, box)
        New("Frame", {Size = UDim2.new(1,8,0,4), Position = UDim2.new(0,-4,0,7), BackgroundColor3 = Color3.fromRGB(28,28,32), BorderSizePixel = 0, ZIndex = 3}, tl)
        New("UIPadding", {PaddingLeft = UDim.new(0,4), PaddingRight = UDim.new(0,4)}, tl)
        local tlt = Text(tl, name, {Bold = true, S = UDim2.new(0,0,1,0)})
        tlt.AutomaticSize, tlt.ZIndex = Enum.AutomaticSize.X, 4
        AnimGrad(tlt)
        local c
        if num or fill then
            c = New("ScrollingFrame", {Size = UDim2.new(1,-12,1,-18), Position = UDim2.new(0,6,0,12), BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, box)
            New("UIListLayout", {Padding = UDim.new(0,Lib.RowGap)}, c)
        else
            c = New("Frame", {Size = UDim2.new(1,-12,0,0), Position = UDim2.new(0,6,0,12), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, box)
            New("UIListLayout", {Padding = UDim.new(0,Lib.RowGap)}, c); New("UIPadding", {PaddingBottom = UDim.new(0,8)}, c)
        end
        return box, c
    end

    local function Group(container, noReg)
        local G = {Container = container}
        local function NewRow(h, t)
            local r = New("Frame", {Size = UDim2.new(1,0,0,h), BackgroundTransparency = 1}, container)
            if not noReg then Reg(r, t) end
            return r
        end
        local gearN = 0
        local function Rowable(obj, r) -- Linoria-style chaining: toggle:AddColorPicker(...):AddKeyPicker(...)
            function obj:AddColorPicker(i, inf) AddColor(r, i, inf); return obj end
            function obj:AddKeyPicker(i, inf) AddKey(r, i, inf, obj.Type == "Toggle" and obj or nil); return obj end
            -- gear: opens a settings panel. spec = function(group) or a list of {"Toggle"|"Slider"|"Dropdown", text, ...}
            function obj:AddGear(spec)
                gearN += 1
                local pre = obj.Idx or ("g" .. tostring(r) .. gearN)
                local left = Place(r, 16)
                local g = New("TextButton", {Size = UDim2.new(0,16,0,16), Position = UDim2.new(1,left,0.5,-8), BackgroundTransparency = 1, Text = "⚙",
                    Font = Enum.Font.SourceSansBold, TextSize = 17, TextColor3 = T.Dim, AutoButtonColor = false}, r)
                g.MouseEnter:Connect(function() g.TextColor3 = T.Text end); g.MouseLeave:Connect(function() g.TextColor3 = T.Dim end)
                local panel
                local function build()
                    panel = New("Frame", {Name = "GearPanel", Active = true, Size = UDim2.new(0,210,0,0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundColor3 = T.Panel2, BorderSizePixel = 0, ZIndex = 50}, nil)
                    panel:SetAttribute("keep", true)
                    local ps = Stroke(panel, T.Bar); Shade(panel, 1, 0.7); Round(panel, 4)
                    Th(function() ps.Color = T.Bar end)
                    New("UIPadding", {PaddingLeft = UDim.new(0,6), PaddingRight = UDim.new(0,6), PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,6)}, panel)
                    New("UIListLayout", {Padding = UDim.new(0,2), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
                    local ttl = Text(panel, (obj.Text or "") .. " settings", {Bold = true, S = UDim2.new(1,0,0,18)})
                    Th(function() ttl.TextColor3 = T.Accent end)
                    ttl.Active = true
                    PopDrag(ttl, panel)
                    local cont = New("Frame", {Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1}, panel)
                    New("UIListLayout", {Padding = UDim.new(0,Lib.RowGap)}, cont)
                    local sgp = Group(cont, true)
                    if type(spec) == "function" then spec(sgp)
                    elseif type(spec) == "table" then
                        for _, s in ipairs(spec) do
                            local id = pre .. "_g_" .. (s[2]:gsub("%s", ""))
                            if s[1] == "Toggle" then sgp:AddToggle(id, {Text = s[2], Default = s[3]})
                            elseif s[1] == "Slider" then sgp:AddSlider(id, {Text = s[2], Min = s[3], Max = s[4], Default = s[5], Suffix = s[6], Rounding = s[7] or 0})
                            elseif s[1] == "Dropdown" then sgp:AddDropdown(id, {Text = s[2], Values = s[3], Default = s[4], Multi = s[5]}) end
                        end
                    end
                end
                g.MouseButton1Click:Connect(function()
                    if Lib._lastClosed and Lib._lastClosed.p == panel and tick() - Lib._lastClosed.t < 0.4 then return end
                    if not panel then build() end
                    if popups[1] == panel then ClosePopup() else OpenKept(panel, g) end
                end)
                return obj
            end
        end

        -- Linoria toggle: small bordered square on the left, label next to it
        function G:AddToggle(idx, info)
            info = info or {}
            local TG = {Type = "Toggle", Value = info.Default or false, Text = info.Text or idx, Idx = idx}
            Changeable(TG)
            local r = NewRow(23, TG.Text)
            local cb = New("Frame", {Size = UDim2.new(0,13,0,13), Position = UDim2.new(0,2,0.5,-7), BorderSizePixel = 0}, r)
            local st = Stroke(cb); Shade(cb, 1, 0.68); Round(cb, 3)
            local lbl = Text(r, TG.Text, {P = UDim2.new(0,24,0,0), S = UDim2.new(1,-90,1,0)})
            -- a bright accent comet that travels around the box outline, only while the toggle is on
            local orbit = SpinGrad(st)
            local built = false
            local function vis()
                local v = TG.Value
                orbit.Enabled, st.Thickness, st.Color = v, v and 2 or 1, v and Color3.new(1,1,1) or LINE
                local c1, c2 = v and ON or OFFC, v and T.Text or T.Dim
                if built then -- fade between states instead of snapping
                    local ti = TweenInfo.new(0.15)
                    TS:Create(cb, ti, {BackgroundColor3 = c1}):Play()
                    TS:Create(lbl, ti, {TextColor3 = c2}):Play()
                else
                    cb.BackgroundColor3, lbl.TextColor3 = c1, c2
                end
            end
            Th(vis)
            built = true
            local function set(v) TG.Value = v and true or false; vis(); Fire(TG, info.Callback); Lib:RefreshKeybinds() end
            function TG:SetValue(v) if (v and true or false) ~= TG.Value then set(v) end end
            local hit = New("TextButton", {Size = UDim2.new(1,-70,1,0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, r)
            hit.MouseButton1Click:Connect(function() set(not TG.Value) end)
            Rowable(TG, r)
            Toggles[idx] = TG
            return TG
        end

        -- Linoria slider: bar with "Text: value/max" centered inside it (Compact = false for label on top)
        function G:AddSlider(idx, info)
            local SL = {Type = "Slider", Min = info.Min or 0, Max = info.Max or 100, Rounding = info.Rounding or 0, Text = info.Text or idx}
            SL.Value = info.Default or SL.Min
            Changeable(SL)
            local compact = info.Compact ~= false
            local r = NewRow(compact and 20 or 34, SL.Text)
            local tr, val
            if compact then
                tr = New("TextButton", {Size = UDim2.new(1,-4,0,16), Position = UDim2.new(0,2,0,2), BackgroundColor3 = OFFC, Text = "", BorderSizePixel = 0, AutoButtonColor = false}, r)
            else
                Text(r, SL.Text, {S = UDim2.new(.6,0,0,16), P = UDim2.new(0,2,0,0)})
                val = Text(r, "", {S = UDim2.new(.4,-2,0,16), P = UDim2.new(.6,0,0,0), Align = Enum.TextXAlignment.Right, Color = T.Dim})
                tr = New("TextButton", {Size = UDim2.new(1,-4,0,8), Position = UDim2.new(0,2,0,21), BackgroundColor3 = OFFC, Text = "", BorderSizePixel = 0, AutoButtonColor = false}, r)
            end
            Stroke(tr, LINE); Shade(tr, 0.7, 1); Round(tr, 3)
            local fill = New("Frame", {BackgroundColor3 = ON, BorderSizePixel = 0, Size = UDim2.new()}, tr)
            Shade(fill, 0.6, 1, 0); Round(fill, 3)
            Th(function() fill.BackgroundColor3 = ON end)
            if compact then val = Text(tr, "", {Align = Enum.TextXAlignment.Center, Size = 12}); val.ZIndex = 2 end
            local drawn = false
            local function draw()
                local sz = UDim2.new((SL.Value - SL.Min) / math.max(SL.Max - SL.Min, 1e-9), 0, 1, 0)
                if drawn then TS:Create(fill, TweenInfo.new(0.08), {Size = sz}):Play() else fill.Size = sz end
                drawn = true
                local suf = info.Suffix or ""
                local t = tostring(SL.Value) .. suf
                if not info.HideMax then t = t .. "/" .. tostring(SL.Max) .. suf end
                val.Text = compact and (SL.Text .. ": " .. t) or t
            end
            local function set(x, silent)
                x = math.clamp(x, SL.Min, SL.Max); local m = 10 ^ SL.Rounding
                x = math.floor(x * m + .5) / m
                local ch = x ~= SL.Value
                SL.Value = x; draw()
                if ch and not silent then Fire(SL, info.Callback) end
            end
            draw()
            function SL:SetValue(n) set(n) end
            function SL:SetMax(n) SL.Max = n; set(SL.Value, true); draw() end
            function SL:SetMin(n) SL.Min = n; set(SL.Value, true); draw() end
            local d = false
            tr.InputBegan:Connect(function(i) if IsClick(i) then d = true; set(SL.Min + (SL.Max - SL.Min) * math.clamp((i.Position.X - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)) end end)
            UIS.InputEnded:Connect(function(i) if IsClick(i) then d = false end end)
            UIS.InputChanged:Connect(function(i)
                if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    set(SL.Min + (SL.Max - SL.Min) * math.clamp((i.Position.X - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1))
                end
            end)
            Options[idx] = SL
            return SL
        end

        -- Linoria dropdown: label on top, value box below. List opens directly above the box (flips below if no room)
        function G:AddDropdown(idx, info)
            local D = {Type = "Dropdown", Values = info.Values or {}, Multi = info.Multi, Text = info.Text or idx}
            Changeable(D)
            local function resolve(x) if type(x) == "number" then return D.Values[x] end return x end
            local function setv(v)
                if D.Multi then
                    D.Value = {}
                    if type(v) == "table" then
                        for k, x in pairs(v) do
                            if type(k) == "number" then local n = resolve(x); if n then D.Value[n] = true end
                            elseif x then D.Value[k] = true end
                        end
                    end
                else D.Value = resolve(v) end
            end
            setv(info.Default)
            local r = NewRow(42, D.Text)
            Text(r, D.Text, {S = UDim2.new(1,0,0,18), P = UDim2.new(0,2,0,0)})
            local b = New("TextButton", {Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,1,-22), BackgroundColor3 = BTN, BorderSizePixel = 0,
                Font = Lib.Font, TextSize = 12, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, Text = ""}, r)
            Stroke(b, Color3.fromRGB(40,40,45)); Shade(b, 1, 0.72); Round(b, 4); Hover(b, BTN, BTN_HI)
            New("UIPadding", {PaddingLeft = UDim.new(0,7), PaddingRight = UDim.new(0,18)}, b)
            Text(b, D.Multi and "+" or "v", {Align = Enum.TextXAlignment.Right, S = UDim2.new(1,14,1,0), Color = T.Dim, Size = 12})
            local function disp()
                if D.Multi then
                    local t = {}; for _, v in ipairs(D.Values) do if D.Value[v] then t[#t+1] = v end end
                    b.Text = #t > 0 and table.concat(t, ", ") or "--"
                else b.Text = D.Value and tostring(D.Value) or "--" end
            end
            disp()
            local function changed() disp(); Fire(D, info.Callback) end
            function D:SetValue(v) setv(v); changed() end
            function D:SetValues(list) D.Values = list; setv(nil); changed() end
            b.MouseButton1Click:Connect(function()
                local p = OpenPopup(b, UDim2.new(0, b.AbsoluteSize.X, 0, math.max(#D.Values, 1) * 20), true)
                local btns = {}
                New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, p)
                for n, v in ipairs(D.Values) do
                    local on = D.Multi and D.Value[v] or (not D.Multi and D.Value == v)
                    local ob = New("TextButton", {Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1, Text = "  " .. v, Font = Lib.Font, TextSize = 12, ZIndex = 51, LayoutOrder = n,
                        TextColor3 = on and T.Accent or T.Text, TextXAlignment = Enum.TextXAlignment.Left}, p)
                    btns[v] = ob
                    ob.InputBegan:Connect(function(inp)
                        if not IsClick(inp) then return end
                        if D.Multi then
                            D.Value[v] = not D.Value[v] or nil; ob.TextColor3 = D.Value[v] and T.Accent or T.Text
                            changed()
                        else
                            if info.AllowNull and D.Value == v then D.Value = nil else D.Value = v end
                            changed()
                            ClosePopup(true) -- single select: close the list after picking
                        end
                    end)
                end
            end)
            Options[idx] = D
            return D
        end

        function G:AddInput(idx, info)
            info = info or {}
            local IN = {Type = "Input", Value = info.Default or "", Text = info.Text or idx}
            Changeable(IN)
            local r = NewRow(42, IN.Text)
            Text(r, IN.Text, {S = UDim2.new(1,0,0,18), P = UDim2.new(0,2,0,0)})
            local tb = New("TextBox", {Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,1,-22), BackgroundColor3 = BTN, BorderSizePixel = 0,
                Text = IN.Value, PlaceholderText = info.Placeholder or "", PlaceholderColor3 = T.Dim, TextColor3 = T.Text, Font = Lib.Font, TextSize = 12,
                ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left}, r)
            Stroke(tb, Color3.fromRGB(40,40,45)); Shade(tb, 1, 0.72); Round(tb, 4); Hover(tb, BTN, BTN_HI)
            New("UIPadding", {PaddingLeft = UDim.new(0,7)}, tb)
            local function commit()
                if info.Numeric and tb.Text ~= "" and tonumber(tb.Text) == nil then tb.Text = IN.Value; return end
                IN.Value = tb.Text; Fire(IN, info.Callback)
            end
            if info.Finished then tb.FocusLost:Connect(function(enter) if enter then commit() end end)
            else tb:GetPropertyChangedSignal("Text"):Connect(commit) end
            function IN:SetValue(v) IN.Value = tostring(v or ""); tb.Text = IN.Value end
            Options[idx] = IN
            return IN
        end

        function G:AddButton(a, f)
            local info = type(a) == "table" and a or {Text = a, Func = f}
            local r = NewRow(24, info.Text)
            local BT = {Type = "Button", Buttons = {}}
            local function mk(inf)
                local b = New("TextButton", {Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,0,2), BackgroundColor3 = BTN, BorderSizePixel = 0,
                    Text = inf.Text, Font = Lib.Font, TextSize = 12, TextColor3 = T.Text, AutoButtonColor = false}, r)
                Stroke(b, Color3.fromRGB(40,40,45)); Shade(b, 1, 0.72); Round(b, 4); Hover(b, BTN, BTN_HI)
                b.MouseEnter:Connect(function() b.TextColor3 = T.Accent end); b.MouseLeave:Connect(function() b.TextColor3 = T.Text end)
                local armed = false
                b.MouseButton1Click:Connect(function()
                    if inf.DoubleClick and not armed then
                        armed = true; b.Text = "Click again"
                        task.delay(1.5, function() armed = false; b.Text = inf.Text end)
                        return
                    end
                    armed = false; b.Text = inf.Text
                    if inf.Func then inf.Func() end
                end)
                table.insert(BT.Buttons, b)
                return b
            end
            mk(info)
            function BT:AddButton(a2, f2) -- two buttons side by side
                local b2 = mk(type(a2) == "table" and a2 or {Text = a2, Func = f2})
                BT.Buttons[1].Size = UDim2.new(.5,-2,0,20)
                b2.Size, b2.Position = UDim2.new(.5,-2,0,20), UDim2.new(.5,2,0,2)
                return BT
            end
            return BT
        end

        function G:AddLabel(text, wrap)
            local LB = {Type = "Label"}
            local r = NewRow(18, text)
            local l = Text(r, text, {Color = T.Dim, P = UDim2.new(0,2,0,0), S = UDim2.new(1,-4,1,0)})
            if wrap then
                l.TextWrapped = true; l.AutomaticSize = Enum.AutomaticSize.Y; l.Size = UDim2.new(1,-4,0,18)
                r.AutomaticSize = Enum.AutomaticSize.Y
            end
            function LB:SetText(t) l.Text = t end
            Rowable(LB, r)
            return LB
        end
        function G:AddDivider()
            local r = NewRow(10)
            New("Frame", {Size = UDim2.new(1,-4,0,1), Position = UDim2.new(0,2,0.5,0), BackgroundColor3 = T.Border, BorderSizePixel = 0}, r)
        end
        function G:AddBlank(h) NewRow(h or 8) end
        return G
    end

    function W:AddTab(name)
        local Tab = {}
        local btn = New("TextButton", {Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = "  " .. name .. "  ",
            Font = Lib.Font, TextSize = 13, TextColor3 = T.Text, AutoButtonColor = false}, TabRow)
        local page = New("Frame", {Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Visible = false}, Body)
        local function col(x)
            local c = New("Frame", {Size = UDim2.new(.5,-4,1,0), Position = UDim2.new(x,x == 0 and 0 or 4,0,0), BackgroundTransparency = 1}, page)
            New("UIListLayout", {Padding = UDim.new(0,14)}, c); return c
        end
        local L, R = col(0), col(.5)
        local tabGrad = AnimGrad(btn) -- animated gradient, only enabled while this tab is selected
        local function paint()
            local on = W.Sel == name
            btn.TextColor3, tabGrad.Enabled = on and Color3.new(1,1,1) or T.Text, on
        end
        Th(paint)
        -- slide the underline under this tab (skips when nothing changed, so dragging the window doesn't spam tweens)
        local function move()
            if W.Sel ~= name then return end
            local x = 6 + btn.AbsolutePosition.X - TabRow.AbsolutePosition.X
            local w = btn.AbsoluteSize.X
            if w <= 0 or (x == W.IndX and w == W.IndW) then return end
            W.IndX, W.IndW = x, w
            TS:Create(Ind, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(0, x, 0, 26), Size = UDim2.new(0, w, 0, 2)}):Play()
        end
        btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(move)
        btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(move)
        local function select()
            for _, t in pairs(W.Tabs) do t.page.Visible = false; t.btn.Font = Lib.Font end
            page.Visible, btn.Font, W.Sel = true, Lib.FontB, name
            for _, t in pairs(W.Tabs) do t.paint() end
            ClosePopup()
            move()
        end
        btn.MouseButton1Click:Connect(select)
        W.Tabs[name] = {page = page, btn = btn, paint = paint}
        if W.First then W.First = false; select() end

        local function gb(column, n, h) local _, c = Box(column, n, h); return Group(c) end
        function Tab:AddLeftGroupbox(n, h) return gb(L, n, h) end
        function Tab:AddRightGroupbox(n, h) return gb(R, n, h) end
        local function tabbox(column, title, h)
            local _, c = Box(column, title or "", h)
            local TBX = {}
            local bar = New("Frame", {Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1}, c)
            New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,2)}, bar)
            local btns, frames, first, cur = {}, {}, nil, nil
            local function pick(n)
                cur = n
                for k, f in pairs(frames) do
                    f.Visible = k == n; btns[k].TextColor3 = k == n and T.Accent or T.Text
                    btns[k].Font = k == n and Lib.FontB or Lib.Font; btns[k].BackgroundTransparency = k == n and 0 or 1
                end
            end
            Th(function() if cur then pick(cur) end end)
            function TBX:AddTab(n)
                local b = New("TextButton", {Size = UDim2.new(0,0,1,0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(30,30,34), BorderSizePixel = 0,
                    Text = "  " .. n .. "  ", Font = Lib.Font, TextSize = 13, TextColor3 = T.Text, BackgroundTransparency = 1, AutoButtonColor = false}, bar)
                Shade(b, 1, 0.7); Round(b, 4)
                local f = New("Frame", {Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false}, c)
                New("UIListLayout", {Padding = UDim.new(0,Lib.RowGap)}, f)
                btns[n], frames[n] = b, f
                b.MouseButton1Click:Connect(function() pick(n) end)
                if not first then first = n; pick(n) end
                return Group(f)
            end
            return TBX
        end
        function Tab:AddLeftTabbox(title, h) return tabbox(L, title, h) end
        function Tab:AddRightTabbox(title, h) return tabbox(R, title, h) end

        -- preview panel: your game character (custom meshes) or your roblox avatar in a viewport + live ESP overlay.
        -- hold left mouse on it and move to rotate, mouse wheel to zoom
        function Tab:AddPreview(n, right, h)
            -- floating panel docked to the side of the main window, only visible while this tab is open
            local PW = 300
            local panel = New("CanvasGroup", {Name = "PreviewPanel", BackgroundTransparency = 1, BorderSizePixel = 0,
                Size = UDim2.fromOffset(PW, 400), Visible = false}, gui)
            local box = Box(panel, n or "Preview", "fill")
            box.Position, box.Size = UDim2.new(0,0,0,8), UDim2.new(1,0,1,-8)
            local pbg = New("Frame", {Size = UDim2.new(1,-16,1,-24), Position = UDim2.new(0,8,0,16), BackgroundColor3 = Color3.fromRGB(26,26,30), BorderSizePixel = 0}, box)
            Shade(pbg, 1, 0.35); Round(pbg, 4)
            local vp = New("ViewportFrame", {Size = UDim2.new(1,-16,1,-24), Position = UDim2.new(0,8,0,16), BackgroundTransparency = 1,
                BorderSizePixel = 0, Ambient = Color3.new(1,1,1), LightColor = Color3.new(1,1,1), LightDirection = Vector3.new(-1,-1,-1)}, box)
            Stroke(vp, Color3.fromRGB(34,34,38)); Round(vp, 4)
            local ov = New("Frame", {Size = vp.Size, Position = vp.Position, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3}, box)
            local hit = New("TextButton", {Size = vp.Size, Position = vp.Position, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 10}, box)
            local cam = New("Camera", {FieldOfView = 40}, vp); vp.CurrentCamera = cam
            local status = Text(vp, "loading character...", {Align = Enum.TextXAlignment.Center, Color = T.Dim})

            local P = {Color = Color3.fromRGB(125,200,40)}
            local model, corners, bones, orig = nil, {}, {}, {}
            local W1 = Color3.new(1,1,1)
            local function opt(id, d) local o = Options[id]; if o ~= nil and o.Value ~= nil then return o.Value end return d end
            local function tgl(id, d) local o = Toggles[id]; if o then return o.Value end return d or false end
            local function shown()
                local p = vp
                while p and p ~= gui do if p:IsA("GuiObject") and not p.Visible then return false end p = p.Parent end
                return p == gui
            end

            -- ===== ESP widgets (created once) =====
            local function frame(c) return New("Frame", {BackgroundColor3 = c or W1, BorderSizePixel = 0, Visible = false}, ov) end
            local function lab(txt, align)
                return New("TextLabel", {BackgroundTransparency = 1, Text = txt, Font = Lib.Font, TextSize = 12, TextColor3 = W1, TextStrokeTransparency = 0.4,
                    Visible = false, Size = UDim2.fromOffset(120,12), TextXAlignment = align or Enum.TextXAlignment.Center}, ov)
            end
            local boxB = New("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false}, ov)
            local boxBs = Stroke(boxB, Color3.new(0,0,0)); boxBs.Thickness = 3
            local boxF = New("Frame", {BackgroundColor3 = W1, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false}, ov)
            local boxFs = Stroke(boxF, W1)
            local cn = {}; for i = 1, 8 do cn[i] = frame() end
            local nameL, weapL = lab(LP.DisplayName), lab("AK-47")
            local hpBack = frame(Color3.new(0,0,0)); local hpFill = New("Frame", {BackgroundColor3 = Color3.fromRGB(80,220,80), BorderSizePixel = 0}, hpBack)
            local amBack = frame(Color3.new(0,0,0)); local amFill = New("Frame", {BackgroundColor3 = Color3.fromRGB(80,160,255), BorderSizePixel = 0}, amBack)
            local flagN = {"Armor", "Scoped", "Reloading"}
            local flagL = {lab("ARMOR", Enum.TextXAlignment.Left), lab("SCOPED", Enum.TextXAlignment.Left), lab("RELOADING", Enum.TextXAlignment.Left)}

            local function proj(p)
                -- manual perspective projection into the viewport's pixel space (cam:WorldToViewportPoint is unreliable for ViewportFrame cameras)
                local sz = vp.AbsoluteSize
                local rel = cam.CFrame:PointToObjectSpace(p)
                local d = math.max(-rel.Z, 0.05)
                local f = (sz.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
                return Vector2.new(sz.X / 2 + rel.X / d * f, sz.Y / 2 - rel.Y / d * f)
            end
            local function setf(f, x, y, w, hh) f.Position, f.Size, f.Visible = UDim2.fromOffset(x, y), UDim2.fromOffset(w, hh), true end
            local function hideAll()
                boxB.Visible, boxF.Visible, nameL.Visible, weapL.Visible, hpBack.Visible, amBack.Visible = false, false, false, false, false, false
                for _, f in ipairs(cn) do f.Visible = false end
                for _, f in ipairs(flagL) do f.Visible = false end
                for _, b in ipairs(bones) do b[3].Visible = false end
            end

            -- ===== chams on the preview model =====
            local lastOn, lastCol
            local function paint(on, col)
                for d, o in pairs(orig) do
                    if d.Parent then
                        if on then d.Color, d.Material = col, Enum.Material.SmoothPlastic else d.Color, d.Material = o[1], o[2] end
                    end
                end
            end
            function P:SetColor(c) P.Color = c; lastOn = nil end

            -- ===== camera orbit =====
            local yaw, pitch, dist, base, origin = 0, 0, 8.5, 8.5, Vector3.new()
            local function place()
                local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
                cam.CFrame = CFrame.lookAt(origin + rot * Vector3.new(0, 0, dist), origin)
            end
            local rotating, over, lastM = false, false, nil
            hit.MouseEnter:Connect(function() over = true end)
            hit.MouseLeave:Connect(function() over = false end)
            hit.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    rotating, lastM = true, UIS:GetMouseLocation()
                end
            end)
            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then rotating = false end
            end)
            UIS.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseWheel and over and #popups == 0 then
                    dist = math.clamp(dist - i.Position.Z * base * 0.08, base * 0.4, base * 2.5); place()
                elseif i.UserInputType == Enum.UserInputType.Touch and rotating then
                    yaw -= i.Delta.X * 0.012; pitch = math.clamp(pitch - i.Delta.Y * 0.008, -1.2, 1.2); place()
                end
            end)

            -- ===== character: game character clone (custom meshes) -> fallback to your roblox avatar =====
            local function buildModel()
                local m
                local ch = LP.Character
                if ch then pcall(function() ch.Archivable = true; m = ch:Clone() end) end
                if not m or #m:GetDescendants() == 0 then
                    m = nil
                    pcall(function()
                        local desc = Players:GetHumanoidDescriptionFromUserId(LP.UserId)
                        m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
                    end)
                end
                return m
            end
            local function setup(m)
                if model then model:Destroy() end
                for _, b in ipairs(bones) do b[3]:Destroy() end
                bones, corners, orig = {}, {}, {}
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.Anchored, d.CanCollide = true, false
                        orig[d] = {d.Color, d.Material}
                    elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("ForceField")
                        or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d:Destroy() end
                end
                m:PivotTo(CFrame.new(0, 0, 0))
                m.Parent = vp
                model = m
                local bcf, bsz = m:GetBoundingBox()
                origin = bcf.Position
                base = math.max(bsz.Y, 3) * 1.65
                dist, yaw, pitch = base, 0, 0
                place()
                for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
                    corners[#corners+1] = (bcf * CFrame.new(bsz.X/2*x, bsz.Y/2*y, bsz.Z/2*z)).Position
                end end end
                local defs = {
                    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
                    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},
                    {"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
                    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
                }
                for _, d in ipairs(defs) do
                    local a, b = m:FindFirstChild(d[1], true), m:FindFirstChild(d[2], true)
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local f = frame(); f.AnchorPoint = Vector2.new(.5,.5)
                        bones[#bones+1] = {a, b, f}
                    end
                end
                lastOn = nil
                status.Visible = false
            end
            function P:Reload() local m = buildModel(); if m then setup(m) else status.Text, status.Visible = "no character", true end end
            task.spawn(function() P:Reload() end)
            local ca = LP.CharacterAdded:Connect(function() task.wait(1.5); P:Reload() end)

            -- ===== per-frame: rotation + ESP overlay =====
            local function upd()
                if not model or not shown() or vp.AbsoluteSize.X < 10 then return end
                local on, col = tgl("c_visEnemy", true), opt("c_vis_colEnemy", P.Color)
                if on ~= lastOn or col ~= lastCol then lastOn, lastCol = on, col; paint(on, col) end
                if not tgl("esp") then hideAll(); return end

                local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
                for _, c in ipairs(corners) do
                    local v = proj(c)
                    minx, miny, maxx, maxy = math.min(minx, v.X), math.min(miny, v.Y), math.max(maxx, v.X), math.max(maxy, v.Y)
                end
                local w, hh = maxx - minx, maxy - miny
                local cx = minx + w / 2

                if tgl("esp_box") then
                    local bc = opt("esp_box_col", W1)
                    local style, th = opt("esp_box_g_Style", "Full"), opt("esp_box_g_Thickness", 1)
                    boxFs.Thickness, boxFs.Color, boxF.BackgroundColor3 = th, bc, bc
                    if style == "Full" then
                        setf(boxF, minx, miny, w, hh)
                        boxF.BackgroundTransparency = opt("esp_box_g_Filled", false) and 0.85 or 1
                        if opt("esp_box_g_Outline", true) then setf(boxB, minx, miny, w, hh) else boxB.Visible = false end
                        for _, f in ipairs(cn) do f.Visible = false end
                    else
                        boxF.Visible, boxB.Visible = false, false
                        local lw, lh = math.max(w * 0.25, 4), math.max(hh * 0.18, 4)
                        local sp = {{minx,miny,lw,th},{minx,miny,th,lh},{maxx-lw,miny,lw,th},{maxx-th,miny,th,lh},
                                    {minx,maxy-th,lw,th},{minx,maxy-lh,th,lh},{maxx-lw,maxy-th,lw,th},{maxx-th,maxy-lh,th,lh}}
                        for i, f in ipairs(cn) do setf(f, sp[i][1], sp[i][2], sp[i][3], sp[i][4]); f.BackgroundColor3 = bc end
                    end
                else
                    boxF.Visible, boxB.Visible = false, false
                    for _, f in ipairs(cn) do f.Visible = false end
                end

                if tgl("esp_Name") then
                    nameL.Text, nameL.TextColor3 = LP.DisplayName, opt("esp_Name_col", W1)
                    nameL.AnchorPoint = Vector2.new(.5,1); nameL.Position = UDim2.fromOffset(cx, miny - 3); nameL.Visible = true
                else nameL.Visible = false end
                if tgl("esp_Health") then
                    setf(hpBack, minx - 6, miny, 3, hh)
                    hpFill.AnchorPoint = Vector2.new(0,1); hpFill.Position = UDim2.new(0,0,1,0); hpFill.Size = UDim2.new(1,0,0.78,0)
                else hpBack.Visible = false end
                local by = maxy + 2
                if tgl("esp_Ammo") then setf(amBack, minx, by, w, 3); amFill.Size = UDim2.new(0.8,0,1,0); by += 5 else amBack.Visible = false end
                if tgl("esp_Weapon") then
                    weapL.Text, weapL.TextColor3 = tostring(opt("wpslot", "AK-47")), opt("esp_Weapon_col", W1)
                    weapL.AnchorPoint = Vector2.new(.5,0); weapL.Position = UDim2.fromOffset(cx, by); weapL.Visible = true
                else weapL.Visible = false end

                local fy = 0
                for i, f in ipairs(flagL) do
                    if tgl("esp_Flags") and tgl("esp_Flags_g_" .. flagN[i], true) then
                        f.Position = UDim2.fromOffset(maxx + 5, miny + fy * 11); f.Visible = true; fy += 1
                    else f.Visible = false end
                end

                local sk, sc = tgl("esp_Skeleton"), opt("esp_Skeleton_col", W1)
                for _, b in ipairs(bones) do
                    if sk then
                        local a, c = proj(b[1].Position), proj(b[2].Position)
                        local d = c - a
                        b[3].Size = UDim2.fromOffset(d.Magnitude, 1)
                        b[3].Position = UDim2.fromOffset((a.X + c.X) / 2, (a.Y + c.Y) / 2)
                        b[3].Rotation = math.deg(math.atan2(d.Y, d.X))
                        b[3].BackgroundColor3, b[3].Visible = sc, true
                    else b[3].Visible = false end
                end
            end
            local function dock()
                local org = Origin()
                local mp, ms = Main.AbsolutePosition, Main.AbsoluteSize
                local scr = ScreenSize()
                local x = mp.X - org.X + ms.X + 8                          -- right of the window
                if x + PW > scr.X - 4 then x = mp.X - org.X - PW - 8 end   -- no room -> left of the window
                panel.Position = UDim2.fromOffset(math.max(x, 4), mp.Y - org.Y)
                panel.Size = UDim2.fromOffset(PW, ms.Y)
                panel.GroupTransparency = Main.GroupTransparency            -- fades with the menu
                panel.Visible = Main.Visible and page.Visible and not Lib._tvBusy               -- only on this tab
            end
            local conn = RS.RenderStepped:Connect(function()
                pcall(dock)
                if rotating and lastM and UIS:GetLastInputType() ~= Enum.UserInputType.Touch then
                    local m = UIS:GetMouseLocation()
                    local d = m - lastM; lastM = m
                    if d.Magnitude > 0 then
                        yaw -= d.X * 0.012
                        pitch = math.clamp(pitch - d.Y * 0.008, -1.2, 1.2)
                        place()
                    end
                end
                local ok, err = pcall(upd)
                if not ok and err ~= P._err then P._err = err; warn("[cynth preview] " .. tostring(err)) end
            end)
            Lib:OnUnload(function() conn:Disconnect(); ca:Disconnect() end)
            return P
        end
        return Tab
    end
    return W
end


local function Tog(g, idx, text, info)
    info = info or {}
    info.Text = text
    return g:AddToggle(idx, info)
end

local function Dd(g, idx, text, values, default, multi)
    return g:AddDropdown(idx, {
        Text = text,
        Values = values or {},
        Default = default,
        Multi = multi,
    })
end

local function Sld(g, idx, text, min, max, default, suffix)
    return g:AddSlider(idx, {
        Text = text,
        Min = min,
        Max = max,
        Default = default,
        Suffix = suffix,
    })
end

local WindowTitle = 'Cynth | Dev ' .. (type(identifyexecutor) == 'function' and identifyexecutor() or 'unknown')

local Window = Library:CreateWindow({
    Title = WindowTitle,
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,

    Size = UDim2.fromOffset(650, 480)
})

Players.PlayerAdded:Connect(function(player)
	Library:Notify(player.Name .. " Has joined the server", 5)
end)

local TabCfg  = Window:AddTab("Config")

local cf = TabCfg:AddLeftGroupbox("Configs", 245)
cf:AddInput("cfg_name", {Text = "Config name", Placeholder = "new config name"})
Dd(cf, "cfg_list", "Config list", {}, nil)
local function cleanName(s) return (tostring(s or ""):gsub("[^%w%-_ ]",""):gsub("^%s+",""):gsub("%s+$","")) end
local function refreshCfg(selName)
    Options.cfg_list:SetValues(Lib:CfgList())
    if selName then Options.cfg_list:SetValue(selName) end
end
cf:AddButton({Text="Create", Func=function()
    local n = cleanName(Options.cfg_name.Value)
    if n=="" then return Library:Notify("Type a config name first") end
    if Lib:CfgExists(n) then return Library:Notify("'"..n.."' already exists") end
    Lib:CfgWrite(n); refreshCfg(n); Library:Notify("Config created: "..n)
end}):AddButton({Text="Load", Func=function()
    local n = Options.cfg_list.Value
    if not n then return Library:Notify("Select a config first") end
    local s = Lib:CfgRead(n)
    if s and Lib:CfgApply(s) then Library:Notify("Loaded: "..n) else Library:Notify("Could not load '"..n.."'") end
end})
cf:AddButton({Text="Overwrite", DoubleClick=true, Func=function()
    local n = Options.cfg_list.Value
    if not n then return Library:Notify("Select a config first") end
    Lib:CfgWrite(n); Library:Notify("Overwritten: "..n)
end}):AddButton({Text="Delete", DoubleClick=true, Func=function()
    local n = Options.cfg_list.Value
    if not n then return Library:Notify("Select a config first") end
    Lib:CfgDel(n); refreshCfg(); Library:Notify("Deleted: "..n)
end})
cf:AddButton("Refresh list", function() refreshCfg(Options.cfg_list.Value) end)
Tog(cf, "autoload", "Auto load", {Callback=function(v)
    pcall(function()
        if v then
            local n = Options.cfg_list and Options.cfg_list.Value
            if n then writefile("cynth/autoload.txt", n) end
        elseif isfile and isfile("cynth/autoload.txt") then delfile("cynth/autoload.txt") end
    end)
end})
Tog(cf, "saveexit", "Save on exit")
Lib:OnUnload(function()
    local n = Options.cfg_list and Options.cfg_list.Value
    if Toggles.saveexit and Toggles.saveexit.Value and n then Lib:CfgWrite(n) end
end)

local ui = TabCfg:AddRightGroupbox("Interface", 245)
Tog(ui,"ui_wm","Watermark",{Default=true,Callback=function(v) if Lib.Watermark then Lib.Watermark.Visible=v end end})
Dd(ui,"ui_wm_items","Watermark elements",{"Ping","FPS","Player name","Game name","Time","Last heartbeat (ms)"},{"Ping","FPS"},true)
Options.ui_wm_items:OnChanged(function(v) Lib.WMItems=v or{}; if Lib.RefreshWatermark then Lib:RefreshWatermark() end end)
Tog(ui,"ui_kbl","Keybind list",{Default=true,Callback=function(v) if Lib.KeybindFrame then Lib.KeybindFrame.Visible=v end end})
Tog(ui,"ui_thud","Target HUD",{Default=true,Callback=function(v) if Lib.TargetHud then Lib.TargetHud.Enabled=v end end})
Tog(ui,"ui_tv","TV open animation",{Default=true,Callback=function(v) Lib.TVEffect=v end})
Sld(ui,"ui_thud_size","Target HUD size",50,250,100,"%")
Options.ui_thud_size:OnChanged(function(v) if Lib.TargetHud then Lib.TargetHud:SetScale((v or 100)/100) end end)
Tog(ui,"ui_notif","Notifications",{Default=true,Callback=function(v) Lib.NotifyEnabled=v end})
Dd(ui,"ui_notifside","Notification side",{"Up left","Up right","Down left","Down right"},"Up right")
Options.ui_notifside:OnChanged(function(v) if v then Lib:SetNotifySide(v) end end)
ui:AddSlider("ui_notiftime",{Text="Notification time",Min=1,Max=10,Default=3,Suffix="s",Callback=function(v) Lib.NotifyTime=v end})
ui:AddLabel("Accent color"):AddColorPicker("ui_accent_col",{Default=T.Accent,Title="Accent color",Callback=function(c) Lib:SetAccent(c) end})
Sld(ui,"ui_dpi","Menu opacity",30,100,100,"%")
Options.ui_dpi:OnChanged(function(v)
    Lib._baseTrans = 1-(v or 100)/100
    local m = Lib._main
    if m and Lib.Open then
        if Lib._fade then Lib._fade:Cancel() end
        m.GroupTransparency = Lib._baseTrans
    end
end)

local ab = TabCfg:AddLeftGroupbox("About", 160)
ab:AddLabel("click [KEY] next to a toggle to rebind")
ab:AddLabel("Menu key"):AddKeyPicker("MenuKeybind",{Default="Insert",NoUI=true,Text="Menu keybind",Mode="Always"})
Lib.ToggleKeybind = Options.MenuKeybind
ab:AddDropdown("ui_font",{Text="Font",Values={"Code","Pixel","Mono","Verdana","Jura","Josefin","Gotham"},Default=Lib.FontPreset,
    Callback=function(v) if v then Lib:SetFont(v) end end})
ab:AddButton("Unload", function() Lib:Unload() end)

refreshCfg()
task.defer(function()
    pcall(function()
        if isfile and isfile("cynth/autoload.txt") then
            local n = readfile("cynth/autoload.txt")
            local s = Lib:CfgRead(n)
            if s then
                Options.cfg_list:SetValue(n); Lib:CfgApply(s)
                Toggles.autoload:SetValue(true)
                Library:Notify("Auto loaded: "..n)
            end
        end
    end)
end)

return Lib
