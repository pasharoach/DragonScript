--[[
  ScriptViewer.lua  v1.5
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

local function getProjectFPS()
  local ok, r = pcall(function() return Resolve() end)
  if not ok or not r then return 24 end
  local pm   = r:GetProjectManager()
  local proj = pm and pm:GetCurrentProject()
  if not proj then return 24 end
  return tonumber(proj:GetSetting("timelineFrameRate")) or 24
end

local function jumpToTimecode(tc)
  local tl = getTimeline()
  if not tl then
    print("[ScriptViewer] jumpToTimecode: no timeline")
    return false
  end
  print("[ScriptViewer] SetCurrentTimecode("..tc..")")
  local ok = tl:SetCurrentTimecode(tc)
  print("[ScriptViewer] result: "..tostring(ok))
  return ok
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
  t[#t+1] = string.format([[<html><body style="font-family:'Courier New',monospace;]]
    ..[[font-size:%dpx;background-color:#1a1a1a;color:#cccccc;">]], fontSize)
  for _, segs in ipairs(parsed) do
    for _, seg in ipairs(segs) do
      if seg.isTc then
        t[#t+1] = string.format(
          [[<a href="tc://%s" style="color:#f5a623;background-color:#3a2e00;]]
          ..[[text-decoration:none;font-weight:bold;padding:0 3px;">%s</a>]],
          seg.text, esc(seg.text))
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
}

-- ─── UI ──────────────────────────────────────────────────────────────────────

local win = disp:AddWindow({
  ID          = "SVWin",
  WindowTitle = "Script Viewer",
  Geometry    = { 180, 80, WIN_W, WIN_H },
  MinimumSize = { 500, 400 },

  ui:VGroup{
    Spacing = 4,
    ui:HGroup{
      Weight=0, Spacing=4,
      ui:Button{ ID="BtnOpen",   Text="Open…",    MinimumSize={80,30} },
      ui:Button{ ID="BtnSaveAs", Text="Save As…", MinimumSize={80,30} },
      ui:Button{ ID="BtnToggle", Text="Edit",      MinimumSize={60,30} },
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

    ui:TextEdit{ ID="TxtMain", ReadOnly=true, Weight=1 },

    ui:HGroup{
      Weight=0,
      ui:Label{
        ID="LblStatus", Text="", Weight=1,
        Alignment={AlignLeft=true, AlignVCenter=true},
        StyleSheet="color:#888888; font-size:11px;",
      },
    },
  },
})

local itm = win:GetItems()

-- ─── Применить HTML ───────────────────────────────────────────────────────────
-- Fusion TextEdit: надёжнее всего через присвоение свойства .HTML
-- Двойной вызов сбрасывает внутренний Qt-документ и пересоздаёт его

local BLANK_HTML = [[<html><body style="background-color:#1a1a1a;"></body></html>]]

local function showHtml(html)
  itm.TxtMain.HTML = BLANK_HTML
  itm.TxtMain.HTML = html
end

local function setStatus(msg)
  itm.LblStatus.Text = msg
end

-- ─── Режимы ──────────────────────────────────────────────────────────────────

local function enterViewMode()
  -- Зафиксировать текст из виджета ТОЛЬКО если мы были в edit
  if state.mode == "edit" then
    state.rawText = itm.TxtMain.PlainText or state.rawText or ""
    state.parsed  = parseText(state.rawText)
  end

  -- Сначала ReadOnly=true — Qt начинает режим просмотра
  itm.TxtMain.ReadOnly = true
  state.mode = "view"
  itm.BtnToggle.Text = "Edit"

  if state.parsed then
    showHtml(buildHtml(state.parsed, state.fontSize))
    setStatus(string.format("%d строк · %d таймкодов · FPS %g",
      #state.parsed, countTimecodes(state.parsed), state.fps))
  end
end

local function enterEditMode()
  -- rawText — источник истины, кладём его в виджет как plain text
  itm.TxtMain.ReadOnly  = false
  itm.TxtMain.PlainText = state.rawText or ""
  state.mode = "edit"
  itm.BtnToggle.Text = "View"
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

  itm.TxtMain.ReadOnly = true
  itm.BtnToggle.Text   = "Edit"

  itm.LblFile.Text = path:match("([^/]+)$") or path
  setStatus(string.format("%d строк · %d таймкодов · FPS %g",
    #state.parsed, countTimecodes(state.parsed), state.fps))
  showHtml(buildHtml(state.parsed, state.fontSize))
end

win.On.BtnToggle.Clicked = function()
  if state.mode == "view" then
    enterEditMode()
  else
    enterViewMode()
  end
end

win.On.SpinSize.ValueChanged = function(ev)
  state.fontSize = ev.Value
  if state.mode == "view" and state.parsed then
    showHtml(buildHtml(state.parsed, state.fontSize))
  end
end

win.On.TxtMain.AnchorClicked = function(ev)
  local url = ev.URL or ""
  local tc  = url:match("^tc://(.+)$")
  if not tc then
    print("[ScriptViewer] AnchorClicked: no tc in URL: "..url)
    return
  end
  print("[ScriptViewer] AnchorClicked: "..tc)
  setStatus("-> "..tc)
  local ok = jumpToTimecode(tc)
  setStatus(ok and ("OK: jumped to "..tc) or ("ERR: no timeline ("..tc..")"))
end

win.On.BtnSaveAs.Clicked = function()
  local textToSave
  if state.mode == "edit" then
    textToSave    = itm.TxtMain.PlainText or ""
    state.rawText = textToSave
    state.parsed  = parseText(textToSave)
  else
    textToSave = state.rawText or ""
  end

  if textToSave=="" then setStatus("Нечего сохранять"); return end

  local defaultDir  = ""
  local defaultName = "script.txt"
  if state.lastPath then
    defaultDir  = state.lastPath:match("^(.+)/[^/]+$") or ""
    defaultName = state.lastPath:match("([^/]+)$") or defaultName
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
    if not name:find("%.%w+$") then name=name..".txt" end
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

showHtml([[<html><body style="background-color:#1a1a1a;color:#555;]]
  ..[[font-family:'Courier New',monospace;font-size:13px;">]]
  ..[[<br>&nbsp;&nbsp;Open a file to begin...</body></html>]])

print("[ScriptViewer] v1.5 started")
win:Show()
disp:RunLoop()
win:Hide()
