--[[
  DragonScript.lua  v3.0
  DaVinci Resolve / Fusion Script
--]]

local ui   = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local WIN_W      = 820
local WIN_H      = 680
local TC_PATTERN = "%d%d:[0-5]%d:[0-5]%d[;:]%d%d"

-- ─── Resolve API ─────────────────────────────────────────────────────────────

local function getTimeline()
  local ok, r = pcall(function() return Resolve() end)
  if not ok or not r then return nil end
  local pm   = r:GetProjectManager()
  local proj = pm and pm:GetCurrentProject()
  return proj and proj:GetCurrentTimeline()
end

local function getResolveAndProject()
  local ok, r = pcall(function() return Resolve() end)
  if not ok or not r then return nil, nil end
  local pm   = r:GetProjectManager()
  local proj = pm and pm:GetCurrentProject()
  return r, proj
end

local function getProjectFPS()
  local ok, r = pcall(function() return Resolve() end)
  if not ok or not r then return 24 end
  local pm   = r:GetProjectManager()
  local proj = pm and pm:GetCurrentProject()
  if not proj then return 24 end
  return tonumber(proj:GetSetting("timelineFrameRate")) or 24
end

local function tcToFrames(tc, fps)
  local h, m, s, f = tc:match("^(%d%d):(%d%d):(%d%d)[;:](%d%d)$")
  if not h then return nil end
  local base = math.max(1, math.floor((tonumber(fps) or 24) + 0.5))
  h, m, s, f = tonumber(h), tonumber(m), tonumber(s), tonumber(f)
  if not (h and m and s and f) then return nil end
  return (((h * 60 + m) * 60) + s) * base + f
end

local function trySetCurrentFrame(tl, frame)
  if not tl or not tl.SetCurrentFrame or type(frame) ~= "number" then return false end
  if frame < 0 then return false end
  local ok, res = pcall(function() return tl:SetCurrentFrame(frame) end)
  if not ok then return false end
  return res and true or false
end

local function getCurrentTimelineTimecode(tl)
  if not tl or not tl.GetCurrentTimecode then return nil end
  local ok, tc = pcall(function() return tl:GetCurrentTimecode() end)
  if not ok or type(tc) ~= "string" or tc == "" then return nil end
  return tc
end

local function jumpToTimecode(tc)
  local tl = getTimeline()
  local resolve, proj = getResolveAndProject()
  if not tl and not proj then
    return false
  end

  local normalized = tc:gsub(";", ":")
  local ok = false
  local beforeTc = getCurrentTimelineTimecode(tl)

  local function applyAndVerify(label, fn)
    local callOk, res = pcall(fn)
    local afterTc = getCurrentTimelineTimecode(tl)

    if afterTc and (afterTc == normalized or afterTc == tc) then
      return true
    end

    if callOk and res and beforeTc and afterTc and beforeTc ~= afterTc then
      return true
    end

    if callOk and res and not beforeTc then
      return true
    end

    return false
  end

  if proj and proj.SetCurrentTimeline and tl then
    pcall(function() proj:SetCurrentTimeline(tl) end)
  end

  if tl and tl.SetCurrentTimecode then
    ok = applyAndVerify("timeline:SetCurrentTimecode("..normalized..")"  , function()
      return tl:SetCurrentTimecode(normalized)
    end)
    if not ok and normalized ~= tc then
      ok = applyAndVerify("timeline:SetCurrentTimecode("..tc..")", function()
        return tl:SetCurrentTimecode(tc)
      end)
    end
  end

  if not ok and proj and proj.SetCurrentTimecode then
    ok = applyAndVerify("project:SetCurrentTimecode("..normalized..")"  , function()
      return proj:SetCurrentTimecode(normalized)
    end)
    if not ok and normalized ~= tc then
      ok = applyAndVerify("project:SetCurrentTimecode("..tc..")", function()
        return proj:SetCurrentTimecode(tc)
      end)
    end
  end

  if not ok and tl then
    local fps = getProjectFPS()
    local targetFrames = tcToFrames(normalized, fps)
    local relFrames = targetFrames

    if targetFrames and tl.GetStartTimecode then
      local okStartTc, startTc = pcall(function() return tl:GetStartTimecode() end)
      if okStartTc and type(startTc) == "string" and startTc ~= "" then
        local startFrames = tcToFrames(startTc, fps)
        if startFrames then
          relFrames = targetFrames - startFrames
        end
      end
    end

    local candidates = {}
    local seen = {}
    local function addCandidate(v)
      if type(v) ~= "number" then return end
      if seen[v] then return end
      seen[v] = true
      candidates[#candidates + 1] = v
    end

    addCandidate(relFrames)
    addCandidate(targetFrames)

    if tl.GetStartFrame then
      local okStartFrame, startFrame = pcall(function() return tonumber(tl:GetStartFrame()) end)
      if okStartFrame and startFrame then
        addCandidate(startFrame + (relFrames or 0))
        addCandidate(startFrame + (targetFrames or 0))
      end
    end

    for _, frame in ipairs(candidates) do
      if applyAndVerify("timeline:SetCurrentFrame("..tostring(frame)..")"  , function()
        return trySetCurrentFrame(tl, frame)
      end) then
        ok = true
        break
      end
    end
  end

  if ok and resolve and resolve.OpenPage then
    -- Keep the playhead move visible in the Edit page.
    pcall(function() resolve:OpenPage("edit") end)
  end

  return ok
end

local function findTcAtPos(text, pos)
  if not text or text=="" or not pos then return nil end
  local n = #text
  if n == 0 then return nil end

  if pos < 1 then pos = 1 end
  if pos > n then pos = n end

  local function isTcChar(ch)
    return ch and ch:match("[%d:;]") ~= nil
  end

  if not isTcChar(text:sub(pos, pos)) and pos > 1 and isTcChar(text:sub(pos-1, pos-1)) then
    pos = pos - 1
  end
  if not isTcChar(text:sub(pos, pos)) then return nil end

  local s, e = pos, pos
  while s > 1 and isTcChar(text:sub(s-1, s-1)) do s = s - 1 end
  while e < n and isTcChar(text:sub(e+1, e+1)) do e = e + 1 end

  local token = text:sub(s, e)
  if token:match("^"..TC_PATTERN.."$") then
    return token
  end
  return nil
end

local function findTcNearPos(text, pos)
  if not text or text == "" or not pos then return nil end
  local from = math.max(1, pos - 24)
  local to   = math.min(#text, pos + 24)
  local chunk = text:sub(from, to)

  local bestTc, bestDist = nil, 999999
  local scanPos = 1
  while scanPos <= #chunk do
    local s, e = chunk:find(TC_PATTERN, scanPos)
    if not s then break end
    local absS = from + s - 1
    local absE = from + e - 1
    local mid = math.floor((absS + absE) / 2)
    local dist = math.abs(mid - pos)
    if dist < bestDist then
      bestDist = dist
      bestTc = text:sub(absS, absE)
    end
    scanPos = e + 1
  end
  return bestTc
end

local function selectedTc()
  local textEdit = itm and itm.TxtMain
  if not textEdit then return nil end
  local ok, sel = pcall(function() return textEdit.SelectedText end)
  if not ok or type(sel)~="string" or sel=="" then return nil end
  return sel:match(TC_PATTERN)
end

local function cursorPosFromEvent(ev)
  local keys = {"Pos", "Position", "CursorPosition", "Index", "NewPosition", "Caret"}

  if type(ev)=="table" then
    for _, k in ipairs(keys) do
      local v = ev[k]
      if type(v)=="number" then return math.floor(v) + 1 end
      if type(v)=="string" then
        local n = tonumber(v)
        if n then return math.floor(n) + 1 end
      end
    end
  end

  for _, prop in ipairs(keys) do
    local textEdit = itm and itm.TxtMain
    if not textEdit then break end
    local ok, v = pcall(function() return textEdit[prop] end)
    if ok then
      if type(v)=="number" then return math.floor(v) + 1 end
      if type(v)=="string" then
        local n = tonumber(v)
        if n then return math.floor(n) + 1 end
      end
    end
  end

  return nil
end

local function detectTcFromWidget(ev)
  local tc = selectedTc()
  if tc then return tc end

  local textEdit = itm and itm.TxtMain
  if not textEdit then return nil end
  local text = textEdit.PlainText or ""
  if text == "" then return nil end

  local pos = cursorPosFromEvent(ev)
  if not pos then return nil end

  tc = findTcAtPos(text, pos)
  if tc then return tc end

  return findTcNearPos(text, pos)
end

local function collectTimecodesFromRaw(raw)
  local out = {}
  local lines = {}

  local function takeWords(s, maxWords)
    local words = {}
    for w in s:gmatch("%S+") do
      words[#words+1] = w
      if #words >= maxWords then break end
    end
    return table.concat(words, " ")
  end

  for line in (tostring(raw or "").."\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  for lineNo, line in ipairs(lines) do
    local pos = 1
    while true do
      local s, e = line:find(TC_PATTERN, pos)
      if not s then break end

      local tail = line:sub(e + 1):gsub("^%s+", "")
      local preview = takeWords(tail, 7)
      if preview == "" then
        for i = lineNo + 1, #lines do
          local candidate = takeWords((lines[i] or ""):gsub("^%s+", ""), 7)
          if candidate ~= "" then
            preview = candidate
            break
          end
        end
      end

      local anchor = "tc_"..tostring(#out + 1)
      out[#out+1] = {
        tc = line:sub(s, e),
        line = lineNo,
        text = line,
        preview = preview,
        anchor = anchor,
      }
      pos = e + 1
    end
  end
  return out
end

-- ─── Чтение файлов ───────────────────────────────────────────────────────────

local function shellRead(cmd)
  local h = io.popen(cmd.." 2>/dev/null")
  if not h then return nil end
  local out = h:read("*a"); h:close()
  return out
end

local function fileExt(path)
  return (path:match("%.([^%.]+)$") or ""):lower()
end

local function stripXml(s)
  s = s:gsub("<w:p[ >]", "\n"):gsub("<w:tab/>", "\t"):gsub("<[^>]+>","")
  s = s:gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
  s = s:gsub("&quot;",'"'):gsub("&apos;","'")
  s = s:gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
  return s
end

local function readDocx(path)
  local xml = shellRead(string.format("unzip -p '%s' word/document.xml", path))
  if not xml or xml=="" then return nil, "Не удалось извлечь текст из docx" end
  return stripXml(xml), nil
end

local function readViaTextutil(path)
  local tmp = "/tmp/_scriptviewer_out.txt"
  os.execute(string.format("textutil -convert txt -output '%s' '%s'", tmp, path))
  local f = io.open(tmp, "r")
  if not f then return nil, "textutil не смог конвертировать файл" end
  local text = f:read("*a"); f:close(); os.remove(tmp)
  return text, nil
end

local function readFile(path)
  local ext = fileExt(path)
  if ext=="txt" or ext=="fountain" or ext=="md" or ext=="srt"
     or ext=="fdx" or ext=="csv" or ext=="" then
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local raw = f:read("*a"); f:close()
    if raw:sub(1,3)=="\xEF\xBB\xBF" then raw=raw:sub(4) end
    return raw, nil
  end
  if ext=="docx" then return readDocx(path) end
  if ext=="doc" or ext=="rtf" or ext=="odt" or ext=="pages" then
    return readViaTextutil(path)
  end
  local f = io.open(path, "r")
  if f then
    local raw = f:read("*a"); f:close()
    if raw:sub(1,3)=="\xEF\xBB\xBF" then raw=raw:sub(4) end
    if not raw:find("\0") then return raw, nil end
  end
  return nil, "Формат не поддерживается: ."..ext
end

-- ─── Парсинг ─────────────────────────────────────────────────────────────────

local function parseLine(line)
  local segs, pos = {}, 1
  while pos <= #line do
    local s, e = line:find(TC_PATTERN, pos)
    if s then
      if s > pos then table.insert(segs, {text=line:sub(pos,s-1), isTc=false}) end
      table.insert(segs, {text=line:sub(s,e), isTc=true})
      pos = e+1
    else
      table.insert(segs, {text=line:sub(pos), isTc=false})
      break
    end
  end
  return segs
end

local function parseText(raw)
  local lines = {}
  for line in (raw.."\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, parseLine(line))
  end
  return lines
end

local function countTimecodes(parsed)
  local n = 0
  for _, segs in ipairs(parsed) do
    for _, seg in ipairs(segs) do if seg.isTc then n=n+1 end end
  end
  return n
end

-- ─── HTML ────────────────────────────────────────────────────────────────────

local function esc(s)
  return (s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

local function buildHtml(parsed, fontSize)
  local t = {}
  local tcIndex = 0
  t[#t+1] = string.format([[<html><body style="font-family:'Courier New',monospace;]]
    ..[[font-size:%dpx;background-color:#1a1a1a;color:#cccccc;">]], fontSize)
  for _, segs in ipairs(parsed) do
    for _, seg in ipairs(segs) do
      if seg.isTc then
        tcIndex = tcIndex + 1
        local anchorName = "tc_"..tostring(tcIndex)
        t[#t+1] = string.format(
          [[<a name="%s"></a><a href="tc://%s" style="color:#f5a623;background-color:#3a2e00;]]
          ..[[text-decoration:none;font-weight:bold;padding:0 3px;">%s</a>]],
          anchorName, seg.text, esc(seg.text))
      else
        t[#t+1] = esc(seg.text)
      end
    end
    t[#t+1] = "<br>"
  end
  t[#t+1] = "</body></html>"
  return table.concat(t)
end

-- ─── Состояние ───────────────────────────────────────────────────────────────
-- rawText — всегда актуальный plain text, источник истины
-- В режиме edit виджет редактируется напрямую
-- В режиме view виджет показывает HTML, rawText НЕ берётся из виджета

local state = {
  rawText  = nil,   -- актуальный plain text (источник истины)
  parsed   = nil,
  fontSize = 13,
  fps      = 24,
  mode     = "view",
  lastPath = nil,
  lastJumpTc = nil,
  lastJumpClock = 0,
  tcItems = {},
}

-- ─── UI ──────────────────────────────────────────────────────────────────────

local win = disp:AddWindow({
  ID          = "SVWin",
  WindowTitle = "DragonScript",
  Geometry    = { 180, 80, WIN_W, WIN_H },
  MinimumSize = { 500, 400 },

  ui:VGroup{
    Spacing = 4,
    ui:HGroup{
      Weight=0, Spacing=4,
      ui:Button{ ID="BtnOpen",   Text="Open…",    MinimumSize={80,30} },
      ui:Button{ ID="BtnSaveAs", Text="Save As…", MinimumSize={80,30} },
      ui:Label{
        ID="LblFile",
        Text="txt · fountain · md · srt · docx · doc · rtf",
        Weight=1,
        Alignment={AlignLeft=true, AlignVCenter=true},
        StyleSheet="color:#888888;",
      },
      ui:Label{ Text="Size:", Weight=0 },
      ui:SpinBox{
        ID="SpinSize", Minimum=8, Maximum=36, Value=13,
        Weight=0, MinimumSize={55,30},
      },
    },

    ui:HGroup{
      Weight=1,
      Spacing=6,
      ui:TextEdit{
        ID="TxtMain", ReadOnly=false, Weight=4,
        Events={
          CursorPositionChanged=true,
          SelectionChanged=true,
          MousePress=true,
          MouseRelease=true,
        },
      },

      ui:Tree{
        ID="TcList",
        Weight=2,
        ColumnCount=2,
        HeaderHidden=false,
        SortingEnabled=false,
        AlternatingRowColors=true,
      },
    },

    ui:HGroup{
      Weight=0,
      ui:Button{ ID="BtnRefresh", Text="Обновить", MinimumSize={94,30}, Weight=0 },
      ui:HGap(0,1),
      ui:Button{ ID="BtnSetTc", Text="SET TC", MinimumSize={84,30}, Weight=0 },
    },
  },
})

local itm = win:GetItems()

-- ─── Применить HTML ───────────────────────────────────────────────────────────
-- Fusion TextEdit: надёжнее всего через присвоение свойства .HTML
-- Двойной вызов сбрасывает внутренний Qt-документ и пересоздаёт его

local BLANK_HTML = [[<html><body style="background-color:#1a1a1a;"></body></html>]]

local function showHtml(html)
  state.updatingHtml = true
  itm.TxtMain.HTML = BLANK_HTML
  itm.TxtMain.HTML = html
  state.updatingHtml = false
end

local function setStatus(msg)
  -- Status bar removed by request; keep function as no-op for compatibility.
end

local rebuildTimecodeList

local function refreshFromEditor()
  if state.updatingHtml then return end
  state.rawText = itm.TxtMain.PlainText or state.rawText or ""
  state.parsed = parseText(state.rawText)
  state.mode = "view"
  showHtml(buildHtml(state.parsed, state.fontSize))
  rebuildTimecodeList()
end

rebuildTimecodeList = function()
  local tree = itm.TcList
  if not tree then return end

  tree:Clear()
  tree:SetHeaderLabels({"TC", ""})

  state.tcItems = collectTimecodesFromRaw(state.rawText or "")
  for _, rec in ipairs(state.tcItems) do
    local item = tree:NewItem()
    item.Text[0] = rec.tc
    item.Text[1] = tostring(rec.preview or "...")
    tree:AddTopLevelItem(item)
  end

  pcall(function() tree.ColumnWidth[0] = 110 end)
  pcall(function() tree.ColumnWidth[1] = 220 end)

  setStatus(string.format("%d строк · %d таймкодов · FPS %g",
    #(state.parsed or {}), #state.tcItems, state.fps))
end

local function tryJumpInput(tc)
  local clean = tostring(tc or ""):gsub("^%s+",""):gsub("%s+$","")
  if clean == "" then
    setStatus("Введите таймкод, например 01:00:00:00")
    return
  end

  local matchTc = clean:match(TC_PATTERN)
  if not matchTc then
    setStatus("Неверный формат TC: "..clean)
    return
  end

  local ok = jumpToTimecode(matchTc)
  if ok then
    state.lastJumpTc = matchTc
    state.lastJumpClock = os.clock()
    setStatus("Переход: "..matchTc)
  else
    setStatus("Ошибка: не удалось перейти к "..matchTc)
  end
end

-- ─── Режимы ──────────────────────────────────────────────────────────────────

local function enterViewMode()
  -- Зафиксировать текст из виджета ТОЛЬКО если мы были в edit
  if state.mode == "edit" then
    state.rawText = itm.TxtMain.PlainText or state.rawText or ""
    state.parsed  = parseText(state.rawText)
  end

  -- В некоторых версиях Resolve клики по HTML-якорям не дают отдельного события.
  -- Оставляем курсор активным, чтобы CursorPositionChanged ловил клик по таймкоду.
  itm.TxtMain.ReadOnly = false
  state.mode = "view"

  if state.parsed then
    showHtml(buildHtml(state.parsed, state.fontSize))
    rebuildTimecodeList()
  end
end

local function enterEditMode()
  -- rawText — источник истины, кладём его в виджет как plain text
  itm.TxtMain.ReadOnly  = false
  itm.TxtMain.PlainText = state.rawText or ""
  state.mode = "edit"
  setStatus("Режим редактирования")
end

-- ─── События ─────────────────────────────────────────────────────────────────

win.On.BtnOpen.Clicked = function()
  local path = fu:RequestFile()
  if not path or path=="" then return end

  itm.LblFile.Text = "Читаю файл…"; setStatus("")

  local raw, err = readFile(path)
  if not raw then
    itm.LblFile.Text = "Ошибка: "..(err or "неизвестная")
    return
  end

  state.rawText  = raw
  state.parsed   = parseText(raw)
  state.fps      = getProjectFPS()
  state.lastPath = path
  state.mode     = "view"

  itm.LblFile.Text = path:match("([^/]+)$") or path
  showHtml(buildHtml(state.parsed, state.fontSize))
  rebuildTimecodeList()
end

win.On.SpinSize.ValueChanged = function(ev)
  state.fontSize = ev.Value
  if state.parsed then
    showHtml(buildHtml(state.parsed, state.fontSize))
  end
end

win.On.BtnRefresh.Clicked = function()
  refreshFromEditor()
end

win.On.BtnSetTc.Clicked = function()
  local tl = getTimeline()
  local tc = getCurrentTimelineTimecode(tl)
  if not tc or tc == "" then
    setStatus("Не удалось получить текущий TC таймлайна")
    return
  end

  if itm.TxtMain and itm.TxtMain.InsertPlainText then
    itm.TxtMain.ReadOnly = false
    local ok = pcall(function() itm.TxtMain:InsertPlainText(tc .. " ") end)
    if not ok then pcall(function() itm.TxtMain.InsertPlainText(tc .. " ") end) end
  else
    itm.TxtMain.PlainText = (itm.TxtMain.PlainText or "") .. tc .. " "
  end

  state.rawText = itm.TxtMain.PlainText or state.rawText or ""
  state.parsed  = parseText(state.rawText)
  rebuildTimecodeList()

  setStatus("Вставлен TC: "..tc)
end

win.On.TcList.ItemClicked = function(ev)
  local tree = itm.TcList
  if not tree or not tree.CurrentItem then return end
  local cur = tree:CurrentItem()
  if not cur or not cur.Text then return end
  local tc = tostring(cur.Text[0] or "")
  if tc == "" then return end

  local row = nil
  if tree.IndexOfTopLevelItem then
    local okRow, idx = pcall(function() return tree:IndexOfTopLevelItem(cur) end)
    if okRow and type(idx) == "number" then row = idx + 1 end
  end
  local rec = row and state.tcItems[row] or nil

  setStatus("TC -> Jump: "..tc)

  if itm.TxtMain then
    local scrolled = false
    if rec and rec.anchor and rec.anchor ~= "" and itm.TxtMain.ScrollToAnchor then
      local okScroll = pcall(function() itm.TxtMain:ScrollToAnchor(rec.anchor) end)
      scrolled = okScroll and true or false
    end

    if not scrolled and itm.TxtMain.Find then
      pcall(function() itm.TxtMain:Find(tc, {FindCaseSensitively=true}) end)
      pcall(function() itm.TxtMain:EnsureCursorVisible() end)
    end
  end

  -- Instant jump on right-list click (no need to press Go).
  tryJumpInput(tc)
end

local function tcFromLinkAtPoint(pos)
  local textEdit = itm and itm.TxtMain
  if not textEdit or not pos then return nil end

  local okAnchor, anchor = pcall(function() return textEdit:AnchorAt(pos) end)
  if (not okAnchor or not anchor or anchor == "") and textEdit.AnchorAt then
    okAnchor, anchor = pcall(function() return textEdit.AnchorAt(pos) end)
  end

  anchor = tostring(anchor or "")
  if anchor == "" then return nil end

  local tc = anchor:match(TC_PATTERN)
  if not tc then
    local raw = anchor:match("^tc://(.+)$")
    if raw then tc = raw:match(TC_PATTERN) or raw end
  end
  return tc
end

local function tcFromCursor(ev)
  local tc = detectTcFromWidget(ev)
  return tc
end

local function putTcIntoJumpField(tc, origin)
  if not tc or tc == "" then return end
  setStatus("TC -> Jump: "..tc)

end

win.On.TxtMain.CursorPositionChanged = function(ev)
end

win.On.TxtMain.SelectionChanged = function(ev)
end

win.On.TxtMain.TextChanged = function(ev)
  if state.updatingHtml then return end
  state.rawText = itm.TxtMain.PlainText or ""
end

win.On.TxtMain.MouseRelease = function(ev)
  local tc = nil
  tc = tcFromCursor(ev)
  putTcIntoJumpField(tc, "MouseRelease")
end

win.On.BtnSaveAs.Clicked = function()
  local textToSave = itm.TxtMain.PlainText or state.rawText or ""
  state.rawText = textToSave
  state.parsed  = parseText(textToSave)

  if textToSave=="" then setStatus("Нечего сохранять"); return end

  local defaultDir  = ""
  local defaultName = "script.txt"
  if state.lastPath then
    defaultDir  = state.lastPath:match("^(.+)/[^/]+$") or ""
    defaultName = state.lastPath:match("([^/]+)$") or defaultName
    defaultName = (defaultName:gsub("%.[^%.]+$", ""))..".txt"
  end
  if defaultDir=="" then defaultDir = os.getenv("HOME").."/Desktop" end

  local saveWin = disp:AddWindow({
    ID="SaveDlg", WindowTitle="Save As",
    Geometry={300,300,540,160},
    ui:VGroup{
      Spacing=8,
      ui:Label{ Text="Папка:" },
      ui:HGroup{
        ui:LineEdit{ ID="TxtDir",    Text=defaultDir,  Weight=1 },
        ui:Button{   ID="BtnPickDir",Text="...", MinimumSize={36,28}, Weight=0 },
      },
      ui:Label{ Text="Имя файла:" },
      ui:LineEdit{ ID="TxtName", Text=defaultName },
      ui:HGroup{
        Weight=0,
        ui:HGap(0,1),
        ui:Button{ ID="BtnCancel", Text="Отмена",    MinimumSize={80,30} },
        ui:Button{ ID="BtnSave",   Text="Сохранить", MinimumSize={100,30} },
      },
    },
  })

  local sw = saveWin:GetItems()
  local chosenPath = nil

  saveWin.On.BtnPickDir.Clicked = function()
    local picked = fu:RequestFile(sw.TxtDir.Text)
    if picked and picked~="" then
      sw.TxtDir.Text = picked:match("^(.+)/[^/]+$") or picked
    end
  end
  saveWin.On.BtnSave.Clicked = function()
    local dir  = sw.TxtDir.Text:gsub("/+$","")
    local name = sw.TxtName.Text
    if name=="" then name="script.txt" end
    name = name:gsub("%.[^%.]+$", "")..".txt"
    chosenPath = dir.."/"..name
    disp:ExitLoop()
  end
  saveWin.On.BtnCancel.Clicked = function() disp:ExitLoop() end
  saveWin.On.SaveDlg.Close     = function() disp:ExitLoop() end

  saveWin:Show(); disp:RunLoop(); saveWin:Hide()

  if not chosenPath or chosenPath=="" then return end

  local f, err = io.open(chosenPath, "w")
  if not f then setStatus("Ошибка: "..(err or "")); return end
  f:write(textToSave); f:close()

  state.lastPath = chosenPath
  itm.LblFile.Text = chosenPath:match("([^/]+)$") or chosenPath
  setStatus("Сохранено: "..chosenPath)
end

win.On.SVWin.Close = function()
  disp:ExitLoop()
end

-- ─── Старт ───────────────────────────────────────────────────────────────────

itm.TxtMain.ReadOnly = false
showHtml([[<html><body style="background-color:#1a1a1a;color:#555;]]
  ..[[font-family:'Courier New',monospace;font-size:13px;">]]
  ..[[<br>&nbsp;&nbsp;Open a file to begin...</body></html>]])

win:Show()
disp:RunLoop()
win:Hide()
