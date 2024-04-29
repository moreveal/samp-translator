script_version_number(17)
script_version("release-1.9")
script_authors("moreveal")
script_description("SAMP Translator")
script_dependencies("sampfuncs, mimgui, lfs, effil/requests")
script_properties("work-in-pause")

-- built-in
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require 'inicfg'
local ffi = require 'ffi'
local lfs = require 'lfs'
local wm = require 'windows.message'
-- additionaly
local imgui = require 'mimgui'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
-- variables
local threads, textlabels, chatbubbles = {}, {}, {}
local phrases = {}
local langs_association = {"en", "ru", "uk", "be", "it", "bg", "es", "kk", "de", "pl", "sr", "fr", "ro", "pt"}
local langs_version = 2
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
for k, v in ipairs(langs_association) do
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
    updateScriptLang()
    
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
                        thisScript():reload()
                    end
                    wait(50)
                    os.remove(tempname_script)
                end)
            end
        end)
    else updated = true end
    while not updated do wait(0) end
    local headers = {
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54 Safari/537.36',
        ['Content-Type'] = 'application/x-www-form-urlencoded',
        ["sec-ch-ua-platform"] = "Windows",
        ["sec-ch-ua"] = "\" Not A;Brand\";v=\"99\", \"Chromium\";v=\"101\", \"Google Chrome\";v=\"101\"",
    }
    math.randomseed(os.time())

    local api_url = "http://127.0.0.1:9550" -- Local API

    lua_thread.create(function()
        while true do
            wait(0)

            if inifile.translate.enable_in then
                for index, textlabel in ipairs(textlabels) do
                    if sampIs3dTextDefined(textlabel.id) then
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        if textlabel.pid ~= 65535 then
                            local res, handle = sampGetCharHandleBySampPlayerId(textlabel.pid)
                            if res then textlabel.position.x, textlabel.position.y, textlabel.position.z = getCharCoordinates(handle) end
                        elseif textlabel.vid ~= 65535 then
                            local res, handle = sampGetCarHandleBySampVehicleId(textlabel.vid)
                            if res then textlabel.position.x, textlabel.position.y, textlabel.position.z = getCarCoordinates(handle) end
                        end
                        if getDistanceBetweenCoords3d(x, y, z, textlabel.position.x, textlabel.position.y, textlabel.position.z) <= 10.0 then
                            table.insert(threads, {
                                style = 3,
                                messages = {
                                    {false, textlabel.id},
                                    {false, textlabel.color},
                                    {true, textlabel.text}
                                }
                            })
                            table.remove(textlabels, index)
                        end
                    else
                        table.remove(textlabels, index)
                    end
                end

                for index, chatbubble in ipairs(chatbubbles) do
                    if os.clock() - chatbubble.duration < 0 then
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        local r, handle = sampGetCharHandleBySampPlayerId(chatbubble.playerid)
                        if r then
                            local px, py, pz = getCharCoordinates(handle)
                            if getDistanceBetweenCoords3d(x, y, z, px, py, pz) <= chatbubble.distance then
                                table.insert(threads, {
                                    style = 4,
                                    messages = {
                                        {false, chatbubble.playerid},
                                        {false, chatbubble.color},
                                        {false, chatbubble.distance},
                                        {false, (chatbubble.duration - os.clock()) * 1000},
                                        {true, chatbubble.message}
                                    }
                                })
                                table.remove(chatbubbles, index)
                            end
                        end
                    else
                        table.remove(chatbubbles, index)
                    end
                end
            end
        end
    end)
    while true do
        wait(0)

        if inifile.translate.enable_in or inifile.translate.enable_out and api_url then
            for thread_index, thread in ipairs(threads) do
                local finish = false
                for message_index, message_info in pairs(thread.messages) do
                    local is_translatable, message, is_out_message = message_info[1], message_info[2], message_info[3]
                    local need_translate = is_translatable and (message:len() > 0 and message:find("%S") and message:find("%D"))

                    except = {}
                    if need_translate then
                        -- fix translation of commands
                        for word in message:gmatch("[^%s]+") do
                            word = word:match("^(/%w+)")
                            if word then
                                local cmd = word:match("/(%w+)")
                                if cmd then
                                    local fixcmd = "/".."2x"..cmd.."2x"
                                    message = message:gsub(word, fixcmd)
                                    table.insert(except, {old = word, new = fixcmd})
                                end
                            end
                        end

                        local tab_replace = "__TAB__" -- to escaping the tab is not the best solution, cause it can also be translated
                        if message:find("\t") then message = message:gsub("\t", tab_replace) end -- to save tabs
                        local function split_by_parts(str, limit)
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
                        local result = split_by_parts(message, 650)
                        for index, source_text in ipairs(result) do
                            if result[index] then
                                local source, target = (is_out_message and inifile.lang.target or inifile.lang.source), (is_out_message and inifile.lang.source or inifile.lang.target)
                                local url, data = api_url, "source="..source.."&target="..target.."&text="..u8(source_text)

                                local temp_str = false
                                asyncHttpRequest('POST', url, {data = data, headers = headers},
                                function(response)
                                    local isjson, array = pcall(decodeJson, response.text)
                                    if isjson and response.status_code == 200 then
                                        if array.text then
                                            local result_text = array.text

                                            -- fix tabs
                                            if result_text:find(tab_replace) then result_text = result_text:gsub(tab_replace, "\t") end

                                            -- fix translation of commands
                                            if result_text:find("%s/%s") then result_text = result_text:gsub("%s/%s", "") end
                                            for _, v in ipairs(except) do result_text = result_text:gsub(v.new, v.old) end
                                            if result_text:find("2x.-2x") then result_text = result_text:gsub("2x", "") end

                                            -- fix broken color tags
                                            result_text = result_text:gsub("{%s*(%x%x%x%x%x%x)%s*}", "{%1}")
                                            -- fix broken square brackets
                                            result_text = result_text:gsub("%[%s*(.-)%s*]", '[%1]')

                                            temp_str = u8:decode(result_text)
                                            if message_index == #thread.messages then finish = true end
                                        end
                                    else -- if there is no connection
                                        -- disable the translation, cancel all threads
                                        inifile.translate.enable_out = false
                                        inifile.translate.enable_in = false
                                        cb_enable_in[0] = false
                                        cb_enable_out[0] = false
                                        thread.messages = {}
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
                                    result[index] = temp_str
                                else
                                    if message:find(tab_replace) then message = message:gsub(tab_replace, "\t") end -- return tabs
                                    for _, v in ipairs(except) do message = message:gsub(v.new, v.old) end -- return commands
                                    result = {message}
                                end
                            end
                        end
                        message_info[2] = table.concat(result, " ")
                        if message_index == #thread.messages then finish = true end
                    else
                        if message_index == #thread.messages then finish = true end
                    end
                    if reqerror then reqerror = false break end
                end
                while not finish do wait(0) end

                local messages = {}
                for _, v in ipairs(thread.messages) do
                    table.insert(messages, v[2])
                end

                local bs = raknetNewBitStream()
                if thread.style == 5 or thread.style == 6 then nop_sendchat = true end
                if thread.style == 1 then -- onServerMessage
                    sampAddChatMessage(messages[2], bit.rshift(messages[1], 8)) -- text, color
                elseif thread.style == 2 then -- onShowDialog
                    raknetBitStreamWriteInt16(bs, messages[1]) -- dialogid
                    raknetBitStreamWriteInt8(bs, messages[2]) -- style
                    raknetBitStreamWriteInt8(bs, messages[3]:len()) -- title length
                    raknetBitStreamWriteString(bs, messages[3]) -- title
                    raknetBitStreamWriteInt8(bs, messages[4]:len()) -- button1 length
                    raknetBitStreamWriteString(bs, messages[4]) -- button1
                    raknetBitStreamWriteInt8(bs, messages[5]:len()) -- button2 length
                    raknetBitStreamWriteString(bs, messages[5]) -- button2
                    raknetBitStreamEncodeString(bs, messages[6]) -- text
                    raknetEmulRpcReceiveBitStream(61, bs)
                    sampSetDialogClientside(false)
                elseif thread.style == 3 then -- onCreate3DText
                    local textlabel_id, color = messages[1], messages[2]
                    if sampIs3dTextDefined(textlabel_id) then
                        local _, _, x, y, z, distance, walls, playerid, vehicleid = sampGet3dTextInfoById(textlabel_id)

                        -- Create new label
                        raknetBitStreamWriteInt16(bs, textlabel_id)
                        raknetBitStreamWriteInt32(bs, color)
                        raknetBitStreamWriteFloat(bs, x)
                        raknetBitStreamWriteFloat(bs, y)
                        raknetBitStreamWriteFloat(bs, z)
                        raknetBitStreamWriteFloat(bs, distance)
                        raknetBitStreamWriteInt8(bs, walls)
                        raknetBitStreamWriteInt16(bs, playerid)
                        raknetBitStreamWriteInt16(bs, vehicleid)
                        raknetBitStreamEncodeString(bs, messages[3])
                        raknetEmulRpcReceiveBitStream(36, bs)
                    end
                elseif thread.style == 4 then -- onPlayerChatBubble
                    raknetBitStreamWriteInt16(bs, messages[1]) -- playerid
                    raknetBitStreamWriteInt32(bs, messages[2]) -- color
                    raknetBitStreamWriteFloat(bs, messages[3]) -- distance
                    raknetBitStreamWriteInt32(bs, messages[4]) -- duration
                    raknetBitStreamWriteInt8(bs, messages[5]:len()) -- text length
                    raknetBitStreamWriteString(bs, messages[5]) -- text
                    raknetEmulRpcReceiveBitStream(59, bs)
                elseif thread.style == 5 then -- onSendChat
                    sampSendChat(messages[1])
                elseif thread.style == 6 then -- onSendCommand
                    sampSendChat(messages[1].." "..messages[2])
                elseif thread.style == 7 then -- onSendDialogResponse
                    sampSendDialogResponse(messages[1], messages[2], messages[3], messages[4]) -- dialogid, button, list, input
                end
                raknetDeleteBitStream(bs)
                table.remove(threads, thread_index)
            end
        end

    end
end

-- hooks
function onReceiveRpc(id, bs)
    if inifile.translate.enable_in then 
        if id == 93 and inifile.options.t_chat then
            local color = raknetBitStreamReadInt32(bs)
            local tlength = raknetBitStreamReadInt32(bs)
            local text = raknetBitStreamReadString(bs, tlength)
            table.insert(threads, {
                style = 1, 
                messages = {
                    {false, color},
                    {true, text}
                }
            })
            return false
        elseif id == 61 and inifile.options.t_dialogs then
            local dialogid = raknetBitStreamReadInt16(bs)
            local style = raknetBitStreamReadInt8(bs)
            local tlength = raknetBitStreamReadInt8(bs)
            local title = raknetBitStreamReadString(bs, tlength)
            local b1len = raknetBitStreamReadInt8(bs)
            local b1 = raknetBitStreamReadString(bs, b1len)
            local b2len = raknetBitStreamReadInt8(bs)
            local b2 = raknetBitStreamReadString(bs, b2len)
            local text = raknetBitStreamDecodeString(bs, 4096)
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
        elseif id == 36 and inifile.options.t_textlabels then
            local id = raknetBitStreamReadInt16(bs)
            local color = raknetBitStreamReadInt32(bs)
            local position = {x = raknetBitStreamReadFloat(bs), y = raknetBitStreamReadFloat(bs), z = raknetBitStreamReadFloat(bs)}
            local distance = raknetBitStreamReadFloat(bs)
            local walls = raknetBitStreamReadInt8(bs) ~= 0
            local pid = raknetBitStreamReadInt16(bs)
            local vid = raknetBitStreamReadInt16(bs)
            local text = raknetBitStreamDecodeString(bs, 4096)
            table.insert(textlabels, {id = id, color = color, position = position, text = text, pid = pid, vid = vid})
        elseif id == 59 and inifile.options.t_chatbubbles then
            local playerid = raknetBitStreamReadInt16(bs)
            local color = raknetBitStreamReadInt32(bs)
            local distance = raknetBitStreamReadFloat(bs)
            local duration = raknetBitStreamReadInt32(bs)
            local mlength = raknetBitStreamReadInt8(bs)
            local message = raknetBitStreamReadString(bs, mlength)
            table.insert(chatbubbles, {playerid = playerid, color = color, distance = distance, duration = os.clock() + duration/1000, message = message})
            return false
        end
    end
end

function onSendRpc(id, bs)
    if inifile.translate.enable_out then
        if (id == 101 or id == 50) and inifile.options.t_chat then
            local tlength = id == 101 and raknetBitStreamReadInt8(bs) or raknetBitStreamReadInt32(bs)
            local text = raknetBitStreamReadString(bs, tlength)
            if not nop_sendchat then
                if text:find("^/") then
                    local command, arg = text:match("(/.-)%s+(.+)")
                    if command and arg then
                        table.insert(threads, {
                            style = 6,
                            messages = {
                                {false, command},
                                {true, arg, "out"}
                            }
                        })
                        return false
                    end
                else
                    table.insert(threads, {
                        style = 5,
                        messages = {
                            {true, text, "out"}
                        }
                    })
                    return false
                end
            else
                nop_sendchat = false
            end
        elseif id == 62 and inifile.options.t_dialogs and sampGetCurrentDialogType() == 1 then
            local dialogid = raknetBitStreamReadInt16(bs)
            local button = raknetBitStreamReadInt8(bs)
            local list = raknetBitStreamReadInt16(bs)
            local tlength = raknetBitStreamReadInt8(bs)
            local input = raknetBitStreamReadString(bs, tlength)
            table.insert(threads, {
                style = 7,
                messages = {
                    {false, dialogid},
                    {false, button},
                    {false, list},
                    {true, input, "out"}
                }
            })
            return false
        end
    end
end

-- loading lang-file
function updateScriptLang()
    lua_thread.create(function()
        local update_langs = false
        if inifile.options.autoupdate then
            local function updateLangs()
                for i = 2, #langs_url do
                    downloadUrlToFile(langs_url[i], main_dir.."languages\\"..langs_url[i]:match(".+/(.+%.lang)"), function(id, status)
                        if status == 6 then
                            if i == #langs_url then update_langs = true end
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
                        if tonumber(content) > langs_version then updateLangs() else update_langs = true end
                        wait(50)
                        os.remove(tempname_lang)
                    end)
                end
            end)
        else update_langs = true end
        while not update_langs do wait(0) end
        wait(400)
        local f = io.open(main_dir.."languages\\"..inifile.options.scriptlang..".lang", "r")
        assert(f, "The language file was not found")
        combo_langs_text = {}
        for line in f:lines() do
            local var, text = line:match("{(.-),%s+\"(.-)\"}")
            phrases[var] = u8:decode(text)
            if var:find("^L_") then
                table.insert(combo_langs_text, text)
            end
        end
        f:close()
        combo_langs = new['const char*'][#combo_langs_text](combo_langs_text)
    end)
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

local function getComboIndexFromLang(lang)
    for index, current_lang in ipairs(langs_association) do
        if current_lang == lang then
            return index - 1
        end
    end
end

local function getLangFromComboIndex(index)
    return langs_association[index + 1]
end

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
            if combo_langs_sindex[0] == combo_langs_tindex[0] then
                combo_langs_sindex[0], combo_langs_tindex[0] = getComboIndexFromLang(inifile.lang.target), getComboIndexFromLang(inifile.lang.source)
            end
            inifile.lang.source = getLangFromComboIndex(combo_langs_sindex[0])
            inifile.lang.target = getLangFromComboIndex(combo_langs_tindex[0])

            inicfg.save(inifile, cpath)
        end
        if imgui.Combo(u8(phrases.CB_TARGET), combo_langs_tindex, combo_langs, #combo_langs_text) then
            if combo_langs_sindex[0] == combo_langs_tindex[0] then
                combo_langs_sindex[0], combo_langs_tindex[0] = getComboIndexFromLang(inifile.lang.target), getComboIndexFromLang(inifile.lang.source)
            end
            inifile.lang.source = getLangFromComboIndex(combo_langs_sindex[0])
            inifile.lang.target = getLangFromComboIndex(combo_langs_tindex[0])

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