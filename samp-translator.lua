script_version_number(5)
script_version("release-1.4")
script_authors("moreveal")
script_description("SAMP Translator")
script_dependencies("sampfuncs, sampev, mimgui, lfs, effil/requests")
script_properties("work-in-pause")

require 'lib.sampfuncs'
-- built-in
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require 'inicfg'
local ffi = require 'ffi'
local lfs = require 'lfs'
local wm = require 'windows.message'
local vkeys = require 'vkeys'
-- additionaly
local sampev = require 'samp.events'
local imgui = require 'mimgui'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
-- variables
local threads, textlabels, chatbubbles = {}, {}, {}
local phrases = {}
local langs_association = {"en", "ru", "uk", "be", "it", "bg", "es", "kk", "de", "pl", "sr", "fr", "ro"}
local langs_version = 1
local main_dir = getWorkingDirectory().."\\config\\samp-translator\\" -- directory of files for correct operation of the script
local sizeX, sizeY = getScreenResolution()
local update_url = "https://github.com/moreveal/samp-translator/raw/main/samp-translator.lua"
local langs_url = {
    "https://raw.githubusercontent.com/moreveal/samp-translator/main/languages/version", -- get actual version of the langs
    "https://github.com/moreveal/samp-translator/raw/main/languages/English.lang",
    "https://github.com/moreveal/samp-translator/raw/main/languages/Russian.lang",
    "https://github.com/moreveal/samp-translator/raw/main/languages/Ukranian.lang"
}
------------

if not doesDirectoryExist(main_dir.."languages") then createDirectory(main_dir.."languages") end
cpath = main_dir.."config.ini"
if not doesFileExist(cpath) then io.open(cpath, "w"):close() end
local defaultIni = {
    lang = {
        source = "en", -- server language
        target = "ru", -- desired language
    },
    translate = {
        enable_out = false, -- status of translation incoming messages
        enable_in = false, -- status of translation outgoing messages
    },
    options = {
        scriptlang = "English", -- script language
        autoupdate = false, -- status of autoupdate
        server = false, -- whether to transfer requests through the script server
        t_chat = true, -- chat translation
        t_dialogs = true, -- dialogs translation
        t_chatbubbles = true, -- chatbubbles translation
        t_textlabels = true, -- textlabels translation
    }
}
inifile = inicfg.load(defaultIni, cpath)
-- imgui variables
local imguiFrame = {}
local renderMainWindow = new.bool()

local cb_enable_in = new.bool(inifile.translate.enable_in)
local cb_enable_out = new.bool(inifile.translate.enable_out)
local cb_chat = new.bool(inifile.options.t_chat)
local cb_dialogs = new.bool(inifile.options.t_dialogs)
local cb_chatbubbles = new.bool(inifile.options.t_chatbubbles)
local cb_textlabels = new.bool(inifile.options.t_textlabels)
local cb_autoupdate = new.bool(inifile.options.autoupdate)
local cb_scriptserver = new.bool(inifile.options.server)

local combo_scriptlangs_index = new.int(0)
local combo_scriptlangs_text = {}
local scriptlangs_num = -1
for file in lfs.dir(main_dir.."languages") do
    if file:match("%.lang$") then
        scriptlangs_num = scriptlangs_num + 1
        local filename = u8(file:match("(.+)%.lang"))
        if inifile.options.scriptlang == filename then
            combo_scriptlangs_index[0] = scriptlangs_num
        end
        table.insert(combo_scriptlangs_text, filename)
    end
end
local combo_scriptlangs = new['const char*'][#combo_scriptlangs_text](combo_scriptlangs_text)
local combo_langs_tindex, combo_langs_sindex = new.int(0), new.int(0)
for k,v in ipairs(langs_association) do
    if inifile.lang.source == v then
        combo_langs_sindex[0] = k-1
    elseif inifile.lang.target == v then
        combo_langs_tindex[0] = k-1
    end
end
---------------
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("translate", function() renderMainWindow[0] = not renderMainWindow[0] end)

    -- auto-update
    if inifile.options.autoupdate then
        local tempname_script = os.tmpname()
        downloadUrlToFile(update_url, tempname_script, function(id, status)
            if status == 6 then
                lua_thread.create(function()
                    wait(100)
                    local f = io.open(tempname_script, "r")
                    local content = f:read("*a")
                    wait(100)
                    f:close()
                    if tonumber(content:match("script_version_number%((%d+)%)")) > thisScript().version_num then
                        f = io.open(thisScript().path, "w+")
                        f:write(content)
                        f:close()
                        sampAddChatMessage("[Translator]: "..u8(phrases.SCRIPT_GUPDATE), 0xCCCCCC)
                        thisScript():reload()
                    end
                    wait(50)
                    os.remove(tempname_script)
                end)
            end
        end)
        local function updateLangs()
            for i = 2, #langs_url do
                downloadUrlToFile(langs_url[i], main_dir.."languages\\"..langs_url[i]:match(".+/(.+%.lang)"), function(id, status)
                    if status == 6 then
                        if i == #langs_url then updated = true end
                    end
                end)
            end
        end
        local tempname_lang = os.tmpname()
        downloadUrlToFile(langs_url[1], tempname_lang, function(id, status)
            if status == 6 then
                lua_thread.create(function()
                    wait(100)
                    local f = io.open(tempname_lang, "r")
                    local content = f:read("*a")
                    wait(100)
                    f:close()
                    if tonumber(content) > langs_version then updateLangs() else updated = true end
                    wait(50)
                    os.remove(tempname_lang)
                end)
            end
        end)
    else updated = true end
    while not updated do wait(0) end
    wait(500)
    updateScriptLang()

    lua_thread.create(function()
        while true do
            wait(0)

            if inifile.translate.enable_in then
                for k,v in ipairs(textlabels) do
                    if sampIs3dTextDefined(v.id) then
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        if v.pid ~= 65535 then
                            local res, handle = sampGetCharHandleBySampPlayerId(v.pid)
                            if res then v.position.x, v.position.y, v.position.z = getCharCoordinates(handle) end
                        elseif v.vid ~= 65535 then
                            local res, handle = sampGetCarHandleBySampVehicleId(v.vid)
                            if res then v.position.x, v.position.y, v.position.z = getCarCoordinates(handle) end
                        end
                        if getDistanceBetweenCoords3d(x, y, z, v.position.x, v.position.y, v.position.z) <= 15.0 then
                            table.insert(threads, {
                                style = 3, 
                                messages = {
                                    {false, v.id},
                                    {false, v.color},
                                    {true, v.text}
                                }
                            })
                            table.remove(textlabels, k)
                        end
                    else
                        table.remove(textlabels, k)
                    end
                end

                for k,v in ipairs(chatbubbles) do
                    if os.clock() - v.duration < 0 then
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        local r, handle = sampGetCharHandleBySampPlayerId(v.playerid)
                        if r then
                            local px, py, pz = getCharCoordinates(handle)
                            if getDistanceBetweenCoords3d(x, y, z, px, py, pz) <= v.distance then
                                table.insert(threads, {
                                    style = 4,
                                    messages = {
                                        {false, v.playerid},
                                        {false, v.color},
                                        {false, v.distance},
                                        {false, (v.duration - os.clock()) * 1000},
                                        {true, v.message}
                                    }
                                })
                                table.remove(chatbubbles, k)
                            end
                        end
                    else
                        table.remove(chatbubbles, k)
                    end
                end
            end
        end
    end)
    while true do
        wait(0)

        if inifile.translate.enable_in or inifile.translate.enable_out then
            for k,v in ipairs(threads) do
                local finish = false
                for s,t in pairs(v.messages) do
                    except = {}
                    if t[1] and t[2]:len() > 0 and t[2]:find("%S") then -- if need to translate
                        for word in t[2]:gmatch("[^%s]+") do
                            word = word:match("^(/%w+)")
                            if word then
                                local cmd = word:match("/(%w+)")
                                if cmd then
                                    math.randomseed(os.time())
                                    local fixcmd = "/".."2x"..cmd.."2x"
                                    t[2] = t[2]:gsub(word, fixcmd) -- dont translate a commands
                                    table.insert(except, {old = word, new = fixcmd})
                                end
                            end
                        end
                        local tab_replace = "0x"..math.random(10,999) -- to escaping the tab is not the best solution, cause it can also be translated
                        if t[2]:find("\t") then t[2] = t[2]:gsub("\t", tab_replace) end -- to save tabs
                        local headers = {
                            ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36',
                            ['Content-Type'] = 'application/x-www-form-urlencoded',
                            ["sec-ch-ua-platform"] = "Windows",
                            ["sec-ch-ua"] = "\" Not A;Brand\";v=\"99\", \"Chromium\";v=\"101\", \"Google Chrome\";v=\"101\"",
                        }
                        local function split_by_lines(str, limit)
                            local lines = {}
                            local line = ""
                            for word in (str .. " "):gmatch("(.-) ") do
                                if #line + #word < limit then
                                    line = line .. " " .. word
                                else
                                    table.insert(lines, line)
                                    line = word
                                end
                                line = line:match("^%s*(.-)%s*$")
                            end
                            table.insert(lines, line:match("^%s*(.-)%s*$"))
                            return lines
                        end
                        local result = split_by_lines(t[2], 650)
                        for r,l in ipairs(result) do
                            if result[r] then
                                local source, target, url, data = t[3] and inifile.lang.target or inifile.lang.source, t[3] and inifile.lang.source or inifile.lang.target
                                if inifile.options.server then url, data = 'http://d952488j.beget.tech/translate.php', "source="..source.."&target="..target.."&text="..l
                                else url, data = 'https://translate.yandex.net/api/v1/tr.json/translate?id=d4d6d78b.627ff9fb.55d49441.74722d74657874-0-0&srv=tr-text&lang='..source..'-'..target..'&reason=auto&format=text&yu=1634153241652478613&yum=1642274859919564853', "text="..url_encode(u8(l)).."&options=4" end
                                local temp_str = false
                                asyncHttpRequest('POST', url, {data = data, headers = headers},
                                function(response)
                                    local isjson, array = pcall(decodeJson, response.text)
                                    if isjson and response.status_code == 200 then
                                        if array.text[1] then
                                            local result_text = array.text[1]
                                            if result_text:find("%s/%s") then result_text = result_text:gsub("%s/%s", "") end
                                            if result_text:find(tab_replace) then result_text = result_text:gsub(tab_replace, "\t") end
                                            for _,v in ipairs(except) do result_text = result_text:gsub(v.new, v.old) end
                                            temp_str = u8:decode(result_text)
                                            if s == #v.messages then finish = true end
                                        end
                                    else -- if there is no connection
                                        -- disable the translation, cancel all threads
                                        inifile.translate.enable_out = false
                                        inifile.translate.enable_in = false
                                        cb_enable_in[0] = false
                                        cb_enable_out[0] = false
                                        v.messages = {}
                                        sampAddChatMessage("[Translator]: "..phrases.NO_CONNECTION, 0xCCCCCC)
                                    end
                                end,
                                function(err) 
                                    reqerror = true
                                    inifile.translate.enable_out = false
                                    inifile.translate.enable_in = false
                                    cb_enable_in[0] = false
                                    cb_enable_out[0] = false
                                    threads = {}
                                    sampAddChatMessage("[Translator]: "..phrases.NO_CONNECTION, 0xCCCCCC)
                                    finish = true
                                end)
                                while not temp_str and not reqerror do wait(0) end
                                if not reqerror then 
                                    result[r] = temp_str
                                else
                                    if t[2]:find(tab_replace) then t[2] = t[2]:gsub(tab_replace, "\t") end -- return tabs
                                    for _,v in ipairs(except) do t[2] = t[2]:gsub(v.new, v.old) end -- return commands
                                    result = {t[2]}
                                end
                            end
                        end
                        t[2] = table.concat(result, " ")
                        if s == #v.messages then finish = true end
                    else
                        if s == #v.messages then finish = true end
                    end
                    if reqerror then reqerror = false break end
                end
                while not finish do wait(0) end
                local bs = raknetNewBitStream()
                if v.style == 5 or v.style == 6 then nop_sendchat = true end
                if v.style == 1 then -- onServerMessage
                    raknetBitStreamWriteInt32(bs, v.messages[1][2]) -- color
                    raknetBitStreamWriteInt32(bs, v.messages[2][2]:len()) -- text length
                    raknetBitStreamWriteString(bs, v.messages[2][2]) -- text
                    raknetEmulRpcReceiveBitStream(93, bs)
                elseif v.style == 2 then -- onShowDialog
                    sampShowDialog(v.messages[1][2], v.messages[3][2], v.messages[6][2], v.messages[4][2], v.messages[5][2], v.messages[2][2]) -- dialogid, title, text, b1, b2, style
                    sampSetDialogClientside(false)
                elseif v.style == 3 then -- onCreate3DText
                    sampSet3dTextString(v.messages[1][2], "{"..bit.tohex(bit.rshift(v.messages[2][2], 8), 6).."}"..v.messages[3][2]) -- id, {color}..text
                elseif v.style == 4 then -- onPlayerChatBubble
                    raknetBitStreamWriteInt16(bs, v.messages[1][2]) -- playerid
                    raknetBitStreamWriteInt32(bs, v.messages[2][2]) -- color
                    raknetBitStreamWriteFloat(bs, v.messages[3][2]) -- distance
                    raknetBitStreamWriteInt32(bs, v.messages[4][2]) -- duration
                    raknetBitStreamWriteInt8(bs, v.messages[5][2]:len()) -- text length
                    raknetBitStreamWriteString(bs, v.messages[5][2]) -- text
                    raknetEmulRpcReceiveBitStream(59, bs)
                elseif v.style == 5 then -- onSendChat
                    sampSendChat(v.messages[1][2])
                elseif v.style == 6 then -- onSendCommand
                    sampSendChat(v.messages[1][2].." "..v.messages[2][2])
                end
                raknetDeleteBitStream(bs)
                table.remove(threads, k)
            end
        end

    end
end

-- hooks
function sampev.onServerMessage(color, text)
    if inifile.translate.enable_in and inifile.options.t_chat then
        table.insert(threads, {
            style = 1, 
            messages = {
                {false, color},
                {true, text}
            }
        })
        return false
    end
end

function sampev.onShowDialog(dialogid, style, title, b1, b2, text)
    if inifile.translate.enable_in and inifile.options.t_dialogs then
        table.insert(threads, {
            style = 2,
            messages = {
                {false, dialogid},
                {false, style},
                {true, title},
                {true, b1},
                {true, b2},
                {true, text}
            }
        })
        return false
    end
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, pid, vid, text)
    if inifile.translate.enable_in and inifile.options.t_textlabels then
        table.insert(textlabels, {id = id, color = color, position = position, text = text, pid = pid, vid = vid})
    end
end

function sampev.onPlayerChatBubble(playerid, color, distance, duration, message)
    if inifile.translate.enable_in and inifile.options.t_chatbubbles then
        table.insert(chatbubbles, {playerid = playerid, color = color, distance = distance, duration = os.clock() + duration/1000, message = message})
        return false
    end
end

function sampev.onSendChat(text)
    if inifile.translate.enable_out then
        if not nop_sendchat then
            table.insert(threads, {
                style = 5,
                messages = {
                    {true, text, "out"}
                }
            })
            return false
        else
            nop_sendchat = false
        end
    end
end

function sampev.onSendCommand(cmd)
    if inifile.translate.enable_out and cmd:find("/.-%s+.+") then
        if not nop_sendchat then
            local command, text = cmd:match("(/.-)%s+(.+)")
            table.insert(threads, {
                style = 6,
                messages = {
                    {false, command},
                    {true, text, "out"}
                }
            })
            return false
        else
            nop_sendchat = false
        end
    end
end

function updateCombo()
    combo_langs_text = {u8(phrases.L_ENGLISH), u8(phrases.L_RUSSIAN), u8(phrases.L_UKRANIAN), u8(phrases.L_BELARUSIAN), u8(phrases.L_ITALIAN), u8(phrases.L_BULGARIAN), u8(phrases.L_SPANISH), u8(phrases.L_KAZAKH), u8(phrases.L_GERMAN), u8(phrases.L_POLISH), u8(phrases.L_SERBIAN), u8(phrases.L_FRENCH), u8(phrases.L_ROMANIAN)}
    combo_langs = new['const char*'][#combo_langs_text](combo_langs_text)
end
-- loading lang-file
function updateScriptLang()
    local f = io.open(main_dir.."languages\\"..inifile.options.scriptlang..".lang", "r")
    assert(f, "The language file was not found")
    local content = f:read("*a")
    f:close()
    for var, text in content:gmatch("{(.-),%s+\"(.-)\"}") do phrases[var] = u8:decode(text) end
    updateCombo()
end
------------------

imgui.OnInitialize(function()
    local config = imgui.ImFontConfig()
    config.MergeMode = true

    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.Colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    style.Colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.60, 0.60, 0.60, 1.00)
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.11, 0.10, 0.11, 1.00)
    style.Colors[imgui.Col.ChildBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.PopupBg] = imgui.ImVec4(0.10, 0.10, 0.10, 0.80)
    style.Colors[imgui.Col.Border] = imgui.ImVec4(0.86, 0.86, 0.86, 0.00)
    style.Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.21, 0.20, 0.21, 0.40)
    style.Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.21, 0.20, 0.21, 0.60)
    style.Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.00, 0.46, 0.65, 0.00)
    style.Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.11, 0.10, 0.11, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.CheckMark] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.30, 0.30, 0.30, 0.90)
    style.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.00, 0.53, 1.00, 1.00)
    style.Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.Header] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.00, 0.53, 1.00, 1.00)
    style.Colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.00, 0.46, 0.65, 1.00)
    style.Colors[imgui.Col.ResizeGrip] = imgui.ImVec4(1.00, 1.00, 1.00, 0.30)
    style.Colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.00, 0.53, 1.00, 1.00)
    style.Colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(1.00, 1.00, 1.00, 0.90)
    style.Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
end)

imguiFrame[1] = imgui.OnFrame(
    function() return renderMainWindow[0] and not isPauseMenuActive() end,
    function(player)
        local function imguiHint(text)
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.PushTextWrapPos(600)
                        imgui.TextUnformatted(u8(text))
                    imgui.PopTextWrapPos()
                imgui.EndTooltip()
            end
        end
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(380, 240), imgui.Cond.FirstUseEver)
        imgui.Begin("SAMP Translator", renderMainWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
        if imgui.Checkbox(u8(phrases.AU_STATUS), cb_autoupdate) then
            inifile.options.autoupdate = not inifile.options.autoupdate
            inicfg.save(inifile, cpath)
        end
        imguiHint(phrases.H_AUINFO)
        imgui.SameLine(280)
        imgui.PushItemWidth(95)
        if imgui.Combo("##ScriptLang", combo_scriptlangs_index, combo_scriptlangs, #combo_scriptlangs_text) then
            inifile.options.scriptlang = combo_scriptlangs_text[combo_scriptlangs_index[0] + 1]
            inicfg.save(inifile, cpath)
            updateScriptLang()
            updateCombo()
        end
        imgui.PopItemWidth()
        imgui.Separator()
        if imgui.Checkbox(u8(phrases.TRANSLATE_MES_OUT), cb_enable_out) then
            inifile.translate.enable_out = not inifile.translate.enable_out
            if inifile.translate.enable_out then threads = {} end
            inicfg.save(inifile, cpath)
        end
        imguiHint(phrases.H_TMO)
        if imgui.Checkbox(u8(phrases.TRANSLATE_MES_IN), cb_enable_in) then
            inifile.translate.enable_in = not inifile.translate.enable_in
            if inifile.translate.enable_in then threads = {} end
            inicfg.save(inifile, cpath)
        end
        imguiHint(phrases.H_TMI)
        imgui.Separator()
        imgui.PushItemWidth(235)
        if imgui.Combo(u8(phrases.CB_SOURCE), combo_langs_sindex, combo_langs, #combo_langs_text) then
            inifile.lang.source = langs_association[combo_langs_sindex[0] + 1]
            inicfg.save(inifile, cpath)
        end
        if imgui.Combo(u8(phrases.CB_TARGET), combo_langs_tindex, combo_langs, #combo_langs_text) then
            inifile.lang.target = langs_association[combo_langs_tindex[0] + 1]
            inicfg.save(inifile, cpath)
        end
        imgui.Separator()
        if imgui.Checkbox(u8(phrases.T_CHAT), cb_chat) then
            inifile.options.t_chat = not inifile.options.t_chat
            inicfg.save(inifile, cpath)
        end
        imgui.SameLine(224)
        if imgui.Checkbox(u8(phrases.T_DIALOGS), cb_dialogs) then
            inifile.options.t_dialogs = not inifile.options.t_dialogs
            inicfg.save(inifile, cpath)
        end
        if imgui.Checkbox(u8(phrases.T_CHATBUBBLES), cb_chatbubbles) then
            inifile.options.t_chatbubbles = not inifile.options.t_chatbubbles
            inicfg.save(inifile, cpath)
        end
        imgui.SameLine(224)
        if imgui.Checkbox(u8(phrases.T_TEXTLABELS), cb_textlabels) then
            inifile.options.t_textlabels = not inifile.options.t_textlabels
            inicfg.save(inifile, cpath)
        end
        imgui.PopItemWidth()
        imgui.Separator()
        if imgui.Checkbox(u8(phrases.S_STATUS), cb_scriptserver) then
            inifile.options.server = not inifile.options.server
            inicfg.save(inifile, cpath)
        end
        imguiHint(phrases.H_SINFO)
        imgui.End()
    end
)
addEventHandler('onWindowMessage', function(msg, wparam, lparam)
    if msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN then
        if wparam == 27 and not sampIsChatInputActive() and not sampIsDialogActive() then -- escape button
            if renderMainWindow[0] then
                renderMainWindow[0] = false
                consumeWindowMessage(true, false)
            end
        end
    end
end)

-- other
local effil = require 'effil'
function asyncHttpRequest(method, url, args, resolve, reject)
    local request_thread = effil.thread(function (method, url, args)
       local requests = require 'requests'
       local result, response = pcall(requests.request, method, url, args)
       if result then
          response.json, response.xml = nil, nil
          return true, response
       else
          return false, response
       end
    end)(method, url, args)
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end
    lua_thread.create(function()
       local runner = request_thread
       while true do
          local status, err = runner:status()
          if not err then
             if status == 'completed' then
                local result, response = runner:get()
                if result then
                   resolve(response)
                else
                   reject(response)
                end
                return
             elseif status == 'canceled' then
                return reject(status)
             end
          else
             return reject(err)
          end
          wait(0)
       end
    end)
end

function char_to_hex(str)
    return string.format("%%%02X", string.byte(str))
end
function url_encode(str)
    local str = string.gsub(str, "\\", "\\")
    local str = string.gsub(str, "([^%w])", char_to_hex)
    return str
end