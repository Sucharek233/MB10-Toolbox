_G.getFileSize = function (path)
    local rf = io.open(path,"rb")
    local len = rf:seek("end")
    rf:close()
    return len
end

_G.getFolderSize =  function (path)
    local size = 0
    local dir, msg, code = lvgl.fs.open_dir(path)
    if not dir then
        -- print("open dir failed: ", msg, code)
        return size
    end

    while true do
        local d = dir:read()
        if not d then break end
        local is_dir = string.byte(d, 1) == string.byte("/", 1)
        local str = (is_dir and "dir: " or "file: ") .. d
        -- printf(str)

        if is_dir == true then
            size = size + getFolderSize(path .. d)
        else
            size = size + getFileSize(path .. '/' .. d)
        end
    end
    dir:close()

    return size
end

----
---json 转换工具
---@class JSON @by wx771720@outlook.com 2019-08-07 16:03:34
_G.JSON = {escape = "\\", comma = ",", colon = ":", null = "null"}

---将数据转换成 json 字符串
---@param data any @数据
---@param space number|string @美化输出时缩进空格数量或者字符串，默认 nil 表示不美化
---@param toArray boolean @如果是数组，是否按数组格式输出，默认 true
---@return string @返回 json 格式的字符串
function JSON.toString(data, space, toArray, __tableList, __keyList, __indent)
	if "boolean" ~= type(toArray) then toArray = true end
	if "table" ~= type(__tableList) then __tableList = {} end
	if "table" ~= type(__keyList) then __keyList = {} end
	if "number" == type(space) then space = space > 0 and string.format("%" .. tostring(space) .. "s", " ") or nil end
	if nil ~= space and nil == __indent then __indent = "" end

	local dataType = type(data)
	-- string
	if "string" == dataType then
		data = string.gsub(data, "\\", "\\\\")
		data = string.gsub(data, "\"", "\\\"")
		return "\"" .. data .. "\""
	end
	-- number
	if "number" == dataType then return tostring(data) end
	-- boolean
	if "boolean" == dataType then return data and "true" or "false" end
	-- table
	if "table" == dataType then
		table.insert(__tableList, data)

		local result, value
		if 0 == JSON._tableCount(data) then
			result = "{}"
		elseif toArray and JSON._isArray(data) then
			result = nil == space and "[" or (__indent .. "[")
			local subIndent = __indent and (__indent .. space)
			for i = 1, #data do
				value = data[i]
				if "table" == type(value) and JSON._indexOf(__tableList, value) >= 1 then
					print(string.format("json array loop refs warning : %s[%i]", JSON.toString(__keyList), i))
				else
					local valueString = JSON.toString(data[i], space, toArray, __tableList, table.insert({table.unpack(__keyList)}, i), subIndent)
					if valueString and subIndent and JSON._isBeginWith(valueString, subIndent) then valueString = string.sub(valueString, #subIndent + 1) end
					if nil == space then
						result = result .. (i > 1 and "," or "") .. (valueString or JSON.null)
					else
						result = result .. (i > 1 and "," or "") .. "\n" .. subIndent .. (valueString or JSON.null)
					end
				end
			end
			result = result .. (nil == space and "]" or ("\n" .. __indent .. "]"))
		else
			result = nil == space and "{" or (__indent .. "{")
			local index = 0
			local subIndent = __indent and (__indent .. space)
			for k, v in pairs(data) do
				if "table" == type(v) and JSON._indexOf(__tableList, v) >= 1 then
					print(string.format("json map loop refs warning : %s[%s]", JSON.toString(__keyList), k))
				else
					local valueString = JSON.toString(v, space, toArray, __tableList, table.insert({table.unpack(__keyList)}, k), subIndent)
					if valueString then
						if subIndent and JSON._isBeginWith(valueString, subIndent) then valueString = string.sub(valueString, #subIndent + 1) end
						if nil == space then
							result = result .. (index > 0 and "," or "") .. ("\"" .. k .. "\":") .. valueString
						else
							result = result .. (index > 0 and "," or "") .. "\n" .. subIndent .. ("\"" .. k .. "\" : ") .. valueString
						end
						index = index + 1
					end
				end
			end
			result = result .. (nil == space and "}" or ("\n" .. __indent .. "}"))
		end
		return result
	end
end

---去掉字符串首尾空格
---@param target string
---@return string
JSON._trim = function(target) return target and string.gsub(target, "^%s*(.-)%s*$", "%1") end
---判断字符串是否已指定字符串开始
---@param str string @需要判断的字符串
---@param match string @需要匹配的字符串
---@return boolean
JSON._isBeginWith = function(str, match) return nil ~= string.match(str, "^" .. match) end
---计算指定表键值对数量
---@param map table @表
---@return number @返回表数量
JSON._tableCount = function(map)
	local count = 0
	for _, __ in pairs(map) do count = count + 1 end
	return count
end
---判断指定表是否是数组（不包含字符串索引的表）
---@param target any @表
---@return boolean @如果不包含字符串索引则返回 true，否则返回 false
JSON._isArray = function(target)
	if "table" == type(target) then
		for key, _ in pairs(target) do if "string" == type(key) then return false end end
		return true
	end
	return false
end
---获取数组中第一个项索引
JSON._indexOf = function(array, item)
	for i = 1, #array do if item == array[i] then return i end end
	return -1
end

---将字符串转换成 table 对象
---@param text string json @格式的字符串
---@return any|nil @如果解析成功返回对应数据，否则返回 nil
JSON.toJSON = function(text)
	text = JSON._trim(text)
	-- string
	if "\"" == string.sub(text, 1, 1) and "\"" == string.sub(text, -1, -1) then return string.sub(JSON.findMeta(text), 2, -2) end
	if 4 == #text then
		-- boolean
		local lowerText = string.lower(text)
		if "false" == lowerText then
			return false
		elseif "true" == lowerText then
			return true
		end
		-- nil
		if JSON.null == lowerText then return end
	end
	-- number
	local number = tonumber(text)
	if number then return number end
	-- array
	if "[" == string.sub(text, 1, 1) and "]" == string.sub(text, -1, -1) then
		local remain = string.gsub(text, "[\r\n]+", "")
		remain = string.sub(remain, 2, -2)
		local array, index, value = {}, 1
		while #remain > 0 do
			value, remain = JSON.findMeta(remain)
			if value then
				value = JSON.toJSON(value)
				array[index] = value
				index = index + 1
			end
		end
		return array
	end
	-- table
	if "{" == string.sub(text, 1, 1) and "}" == string.sub(text, -1, -1) then
		local remain = string.gsub(text, "[\r\n]+", "")
		remain = string.sub(remain, 2, -2)
		local key, value
		local map = {}
		while #remain > 0 do
			key, remain = JSON.findMeta(remain)
			value, remain = JSON.findMeta(remain)
			if key and #key > 0 and value then
				key = JSON.toJSON(key)
				value = JSON.toJSON(value)
				if key and value then map[key] = value end
			end
		end
		return map
	end
end

---查找字符串中的 json 元数据
---@param text string @json 格式的字符串
---@return string,string @元数据,剩余字符串
JSON.findMeta = function(text)
	local stack = {}
	local index = 1
	local lastChar = nil
	while index <= #text do
		local char = string.sub(text, index, index)
		if "\"" == char then
			if char == lastChar then
				table.remove(stack, #stack)
				lastChar = #stack > 0 and stack[#stack] or nil
			else
				table.insert(stack, char)
				lastChar = char
			end
		elseif "\"" ~= lastChar then
			if "{" == char then
				table.insert(stack, "}")
				lastChar = char
			elseif "[" == char then
				table.insert(stack, "]")
				lastChar = char
			elseif "}" == char or "]" == char then
				-- assert(char == lastChar, text .. " " .. index .. " not expect " .. char .. "<=>" .. lastChar)
				table.remove(stack, #stack)
				lastChar = #stack > 0 and stack[#stack] or nil
			elseif JSON.comma == char or JSON.colon == char then
				if not lastChar then return string.sub(text, 1, index - 1), string.sub(text, index + 1) end
			end
		elseif JSON.escape == char then
			text = string.sub(text, 1, index - 1) .. string.sub(text, index + 1)
		end

		index = index + 1
	end
	return string.sub(text, 1, index - 1), string.sub(text, index + 1)
end


--------------------------------------------------------main部分
---@diagnostic disable: unused-function, missing-fields
local lvgl = require("lvgl")
-- require("imgs.json")
-- require("imgs.fs2")
-- local SCRIPT_PATH = SCRIPT_PATH
local DEBUG_ENABLE = false
-- local TEXT_FONT = lvgl.BUILTIN_FONT.MONTSERRAT_14

local function fileExists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

-- Original from MB9
-- local appJsonPath = '/data/quickapp/apps.json'
-- local appJsonPathHide = '/data/quickapp/apps.json_hide'
-- local appPathApp = '/data/quickapp/app/'

-- New for MB10
local appJsonPath = '/data/apps.json'
local appJsonPathHide = '/data/apps.json_hide'
local appPathApp = '/data/app/'

local appPathSystem = '/data/quickapp/system/'
local appPathApp_file1 = '/data/quickapp/cache/'
local appPathApp_file2 = '/data/quickapp/files/'
local appPathApp_file3 = '/data/quickapp/mass/'
local appLsFilePath = '/data/mass/'

if string.find(SCRIPT_PATH, '/home/watchface') ~= nil then
    DEBUG_ENABLE = true
    appPathApp = '/home/watchface/simulator/luavgl/examples/app/'
    appPathSystem = '/home/watchface/simulator/luavgl/examples/app1/'
    appJsonPath = '/home/watchface/simulator/luavgl/examples/fm2/apps.json'
    appJsonPathHide = '/home/watchface/simulator/luavgl/examples/fm2/apps.json_hide'
    appPathApp_file1 = '/home/watchface/simulator/luavgl/examples/app2/'
    appPathApp_file2 = '/home/watchface/simulator/luavgl/examples/app3/'
    appPathApp_file3 = '/home/watchface/simulator/luavgl/examples/app4/'
    appLsFilePath = '/home/watchface/simulator/luavgl/examples/ls2/'
else
    -- 在独立lua中可以使用
    -- TEXT_FONT = lvgl.Font('misansw medium', 22)
    -- TEXT_FONT = lvgl.Font('misansw_demibold', 22)
end

local isS3 = fileExists('/font/MiSans-Demibold.ttf')

local TEXT_FONT = lvgl.BUILTIN_FONT.MONTSERRAT_14
if DEBUG_ENABLE == false then
    if isS3 then
        TEXT_FONT = lvgl.Font('MiSans-Demibold', 22)
    else
        TEXT_FONT = lvgl.Font('misansw_demibold', 22)
    end
end

local printf = DEBUG_ENABLE and print or function(...)
    end

local img_suff = {}

local function imgPath(src)
    if DEBUG_ENABLE then
        return SCRIPT_PATH .. 'fm2/' .. src .. '.png'
    end
    local path = SCRIPT_PATH .. src
    if img_suff[src] ~= nil then
        return path .. img_suff[src]
    end
    if fileExists(path .. '.bin') then
        img_suff[src] = '.bin'
        return path .. img_suff[src]
    elseif fileExists(path .. '.rle') then
        img_suff[src] = '.rle'
        return path .. img_suff[src]
    end
    return path
end


local rootbase1 = lvgl.Object(nil, {
    outline_width = 0,
    border_width = 0,
    pad_all = 0,
    bg_opa = lvgl.OPA(100),
    bg_color = 0,
    align = lvgl.ALIGN.CENTER,
    w = lvgl.HOR_RES(),
    h = lvgl.VER_RES()
})

rootbase1:clear_flag(lvgl.FLAG.SCROLLABLE)
rootbase1:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local rootbase = lvgl.Object(rootbase1, {
        outline_width = 0,
        border_width = 0,
        pad_all = 0,
        bg_opa = lvgl.OPA(100),
        bg_color = 0,
        align = lvgl.ALIGN.CENTER,
        w = 192,
        h = 490
    })

rootbase:clear_flag(lvgl.FLAG.SCROLLABLE)
rootbase:add_flag(lvgl.FLAG.EVENT_BUBBLE)

---- 执行命令相关

local timer
local commandIndex = 1
local commandTable = {}

local function showToast(name)

    local img = rootbase:Object {
        w = 192,
        h = 70,
        bg_color = "#222",
        bg_opa = lvgl.OPA(100),
        border_width = 0,
        radius = 10,
        pad_all = 20,
        x = 0,
        y = -76
    }

    local lbl = img:Label {
        text = name,
        text_color = "#fff",
        text_font = TEXT_FONT,
        align = lvgl.ALIGN.CENTER,
    }


    local aimY = 60
    local inTimer = false
    img:Anim {
        run = true,
        start_value = -76,
        end_value = aimY + 86,
        time = 900, -- 560ms fixed
        repeat_count = 1,
        path = "ease_in_out",
        exec_cb = function(obj, now)
            if now <= aimY then
                img:set { y = now }
            else
                if now == aimY + 86 then
                    lbl:delete()
                    img:delete()
                end
            end           
        end
    }
end

--BTN NEUX

local function createBTN(rwd, x, y, w, h, title)
    local btnnn = rwd:Object {
        w = w,
        h = h,
        bg_color = "#222",
        bg_opa = lvgl.OPA(100),
        border_width = 0,
        radius = 10,
        pad_all = 20,
        x = x,
        y = y
    }

    btnnn:add_flag(lvgl.FLAG.CLICKABLE)
    btnnn:Label {
        text = title,
        text_color = "#fff",
        text_font = TEXT_FONT,
        align = lvgl.ALIGN.CENTER,
    }
    return btnnn
end

local sayi = true

local function runCommandAndShowMsg(cmd)
    if cmd == 'waitfor' then
        if sayi then
            showToast('Rebooting')
            sayi = false
        end
        return
    end

    printf('nsh:' .. cmd)
    if DEBUG_ENABLE then
        return
    end
    local dircmd = cmd
    os.execute(dircmd)
end

local function runCommandAndgetResult(cmd)
    printf('nsh:' .. cmd)
    -- if DEBUG_ENABLE then
    --     return
    -- end
    local tmpFilePath = '/data/tmpFile'
    if DEBUG_ENABLE then
        tmpFilePath = '/home/watchface/simulator/luavgl/examples/tmpFile'
    end
    local dircmd = cmd
    os.execute(dircmd .. " > " .. tmpFilePath)
    local strs = ''
    for f in io.lines(tmpFilePath) do
        strs = strs .. f .. '\n'
    end

    if #strs > 0 then
        strs = string.sub(strs, 1, -2)
    end
    printf(strs)
    os.execute("rm " .. tmpFilePath)

    return strs
end

local function doNextCommand()
    if commandIndex <= #commandTable then
        local cmd = commandTable[commandIndex]
        runCommandAndShowMsg(cmd)
        commandIndex = commandIndex + 1
    else
        -- timer:pause()
    end
end

lvgl.Timer {
    period = 1000,
    paused = false,
    cb = function(t)
        doNextCommand()
    end
}

local function doMuiltCommand(cmds)
    showToast("Running")
    commandTable = cmds
    commandIndex = 1
    -- timer:resume()
end

---- 文件读写相关
local function readFileToStr(file)
    if fileExists(file) == false then
        printf('File Not Found : ' .. file)
        return ''
    end
    local text = ''
    for f in io.lines(file) do
        text = text .. f .. '\n'
    end
    return text
end

function split(input, delimiter)
    local arr = {}
    function fAdd(w)
        if w and w ~= '' then
            table.insert(arr, w)
        end
    end
    string.gsub(input, '[^' .. delimiter ..']+', fAdd)
    return arr
end
---- 页面相关

local mainPage
local appsPage1
local appList
local reloadAppsFunc


local function showPage(wd)
    if mainPage == wd then
        printf("show mainpage")
        mainPage:clear_flag(lvgl.FLAG.HIDDEN)
    else
        printf("hide mainpage")
        mainPage:add_flag(lvgl.FLAG.HIDDEN)
    end

    if appsPage1 == wd then
        printf("show appsPage1")
        reloadAppsFunc()
        appsPage1:clear_flag(lvgl.FLAG.HIDDEN)
    else
        printf("hide appsPage1")
        appsPage1:add_flag(lvgl.FLAG.HIDDEN)
    end
end

---- 首页
local function createMainPage(rootWd)
    local root = lvgl.Object(rootWd, {
        outline_width = 0,
        border_width = 0,
        pad_all = 0,
        bg_opa = lvgl.OPA(100),
        bg_color = 0,
        align = lvgl.ALIGN.CENTER,
        w = 192,
        h = 490
    })

    root:clear_flag(lvgl.FLAG.SCROLLABLE)
    root:add_flag(lvgl.FLAG.EVENT_BUBBLE)


    root:Label {
        w = 132,
        h = 30,
        x = 37,
        y = 53,
        text = "Toolbox v1",
        text_color = '#999999',
        bg_color = 0,
        border_width = 0,
        text_font = TEXT_FONT,
        text_align = lvgl.ALIGN.CENTER,
    }

    local appsButton = root:Object {
        w = 182,
        h = 70,
        bg_color = "#222",
        bg_opa = lvgl.OPA(100),
        border_width = 0,
        radius = 10,
        pad_all = 20,
        x = 5,
        y = 88
    }

    appsButton:onClicked(function()
        showPage(appsPage1)
    end)
    appsButton:add_flag(lvgl.FLAG.CLICKABLE)
    appsButton:Label {
        text = "Apps",
        text_color = "#fff",
        text_font = TEXT_FONT,
        align = lvgl.ALIGN.CENTER,
    }

    return root
end

mainPage = createMainPage(rootbase)


local function removeAndSave(path,appInfo)
    local jsonStr = readFileToStr(path)

    local jsonObj = {
        InstalledApps = {}
    }

    if jsonStr ~= '' then
        jsonObj = JSON.toJSON(jsonStr)
    else
        return
    end

    for i=1,#jsonObj.InstalledApps,1 do
        local app = jsonObj.InstalledApps[i]
        if app.package == appInfo.package then
            table.remove(jsonObj.InstalledApps,i)
            break
        end
    end

    local newJsonStr = JSON.toString(jsonObj,4,true)

    printf('removeAndSave')
    printf(newJsonStr)

    local f = io.open(path, "w+")
    f:write(newJsonStr)
    f:close()
end

local function addAndSave(path,appInfo)
    local jsonStr = readFileToStr(path)

    local jsonObj = {
        InstalledApps = {}
    }

    if jsonStr ~= '' then
        jsonObj = JSON.toJSON(jsonStr)
    end

    table.insert(jsonObj.InstalledApps,appInfo)

    local newJsonStr = JSON.toString(jsonObj,4,true)

    printf('addAndSave')
    printf(newJsonStr)

    local f = io.open(path, "w+")
    f:write(newJsonStr)
    f:close()
end

local function getAllAppSize(package)
    local size = 0
    size = size + getFolderSize(appPathApp .. package)
    size = size + getFolderSize(appPathSystem .. package)
    size = size + getFolderSize(appPathApp_file1 .. package)
    size = size + getFolderSize(appPathApp_file2 .. package)
    size = size + getFolderSize(appPathApp_file3 .. package)

    local rs = ''
    if size > 1024 * 1024 then
        rs = math.floor(size*100/(1024*1024))/100 .. 'M'
    else
        rs = math.floor(size*100/(1024))/100 .. 'K'
    end
    return rs
end

local function createAppDetailPage(rootWd,appInfo)
    local root = lvgl.Object(rootWd, {
        outline_width = 0,
        border_width = 0,
        pad_all = 0,
        bg_opa = lvgl.OPA(100),
        bg_color = 0,
        align = lvgl.ALIGN.CENTER,
        w = 192,
        h = 490
    })

    root:clear_flag(lvgl.FLAG.SCROLLABLE)
    root:add_flag(lvgl.FLAG.EVENT_BUBBLE)

    local title_txt = root:Label {
        w = 182,
        h = 30,
        x = 50,
        y = 30,
        text = "< return",
        text_color = "#999999",
        text_font = TEXT_FONT,
        text_align = lvgl.ALIGN.CENTER,
    }

    title_txt:add_flag(lvgl.FLAG.CLICKABLE)
    title_txt:onevent(lvgl.EVENT.SHORT_CLICKED, function(obj, code)
        root:clean()
        root:delete()
    end)

    local imgIconPath = appPathApp .. appInfo.package .. '/' .. appInfo.icon
    if fileExists(imgIconPath) == false then
        imgIconPath = imgPath('notfound')
    end
    local img = root:Image { src = imgIconPath, x = 48, y = 78 }
    local w, h = img:get_img_size()
    if w ~= 96 then
        local scale = math.floor(256*96/w)
        img:set {
            zoom = scale,
            w = w,
            h = w,
            x = 48 - math.floor((w - 96)/2),
            y = 78 - math.floor((w - 96)/2)
        }
    end

    local text = appInfo.package .. '\nVersion:' .. appInfo.versionName
    local label = root:Label {
        w = 192,
        h = 140,
        x = 0,
        y = 192,
        text = text,
        text_color = '#eeeeee',
        bg_color = 0,
        border_width = 0,
        font_size = 30,
        text_align = lvgl.ALIGN.TOP_MID,
        text_font = TEXT_FONT
    }

    label:Anim {
        run = true,
        start_value = 0,
        end_value = 10,
        time = 10, -- 560ms fixed
        repeat_count = 1,
        path = "ease_in_out",
        exec_cb = function(obj, now)
            if now == 10 then
                local txt = getAllAppSize(appInfo.package)
                label:set {
                    text = text .. '\n' .. txt
                }
            end
        end
    }


    local flag = false

    if appInfo.hideFlag == nil or appInfo.hideFlag == false then
        local btn2 = root:Image { src = imgPath('hide'), x = 45, y = 330 }

        btn2:add_flag(lvgl.FLAG.CLICKABLE)
        btn2:onevent(lvgl.EVENT.SHORT_CLICKED, function(obj, code)
            if flag then
                return
            end
            flag = true
    
            -- 隐藏APP
            removeAndSave(appJsonPath,appInfo)
            appInfo.hideFlag = true
            addAndSave(appJsonPathHide,appInfo)
    
            local cmds = {
                "waitfor",
                "waitfor",
                "reboot"
            }
            doMuiltCommand(cmds)
        end)
    else
        local btn2 = root:Image { src = imgPath('unhide'), x = 45, y = 330 }

        btn2:add_flag(lvgl.FLAG.CLICKABLE)
        btn2:onevent(lvgl.EVENT.SHORT_CLICKED, function(obj, code)
            if flag then
                return
            end
            flag = true
            -- 显示APP
    
            removeAndSave(appJsonPathHide,appInfo)
            appInfo.hideFlag = nil
            addAndSave(appJsonPath,appInfo)
    
            local cmds = {
                "waitfor",
                "waitfor",
                "reboot"
            }
            doMuiltCommand(cmds)
        end)
    end

    local btn = root:Image { src = imgPath('uninstallapp'), x = 45, y = 412 }
    
    btn:add_flag(lvgl.FLAG.CLICKABLE)
    btn:onevent(lvgl.EVENT.SHORT_CLICKED, function(obj, code)
        if flag then
            return
        end
        flag = true

        removeAndSave(appJsonPath,appInfo)
        removeAndSave(appJsonPathHide,appInfo)
        
        local cmds = {
            "rm -r " .. appPathApp .. appInfo.package .. '/',
            "rm -r " .. appPathSystem .. appInfo.package .. '/',
            "rm -r " .. appPathApp_file1 .. appInfo.package .. '/',
            "rm -r " .. appPathApp_file2 .. appInfo.package .. '/',
            "rm -r " .. appPathApp_file3 .. appInfo.package .. '/',
            "waitfor",
            "waitfor",
            "reboot"
        }
        doMuiltCommand(cmds)
    end)


end

local function showAppDetailPage(root,app)
    printf(JSON.toString(app,4,true))

    createAppDetailPage(root,app)
end

local function reloadApps(root,list)
    local jsonStr = readFileToStr(appJsonPath)
    local jsonObj = JSON.toJSON(jsonStr)

    local jsonStrHide = readFileToStr(appJsonPathHide)
    if jsonStrHide ~= '' then
        local jsonObjHide = JSON.toJSON(jsonStrHide)
        for i=1,#jsonObjHide.InstalledApps,1 do
            table.insert(jsonObj.InstalledApps,jsonObjHide.InstalledApps[i])
        end
    end
    list:clean()

    local baseIndex = 0
    for i=1,#jsonObj.InstalledApps,1 do
        local app = jsonObj.InstalledApps[i]
        local x = 48
        local y = (i - 1 + baseIndex)*104
        local imgIconPath = appPathApp .. app.package .. '/' .. app.icon
        if fileExists(imgIconPath) == false then
            imgIconPath = imgPath('notfound')
        end
        local img = list:Image { src = imgIconPath, x = x, y = y}
        img:set {
            w = 96,
            h = 96
        }
        if app.hideFlag ~= nil and app.hideFlag == true then
            list:Image { src = imgPath('hideicon'), x = x + 96 - 32, y = y + 96 - 32}
        end
        local w, h = img:get_img_size()
        if w ~= 96 then
            local scale = math.floor(256*96/w)
            img:set {
                zoom = scale,
                w = w,
                h = w,
                x = 48 - math.floor((w - 96)/2),
                y = (i - 1 + baseIndex)*104 - math.floor((w - 96)/2)
            }
        end
        img:add_flag(lvgl.FLAG.CLICKABLE)
        img:onevent(lvgl.EVENT.CLICKED, function(obj, code)
            showAppDetailPage(root,app)
        end)
    end

    baseIndex = baseIndex + #jsonObj.InstalledApps
end

local function createAppPage(rootWd)

    local root = lvgl.Object(rootWd, {
        outline_width = 0,
        border_width = 0,
        pad_all = 0,
        bg_opa = lvgl.OPA(100),
        bg_color = 0,
        align = lvgl.ALIGN.CENTER,
        w = 192,
        h = 490
    })

    root:clear_flag(lvgl.FLAG.SCROLLABLE)
    root:add_flag(lvgl.FLAG.EVENT_BUBBLE)

    local title_txt = root:Label {
        w = 182,
        h = 30,
        x = 50,
        y = 30,
        text = "< return",
        text_color = '#999999',
        bg_color = 0,
        border_width = 0,
        text_font = TEXT_FONT,
        text_align = lvgl.ALIGN.CENTER,
    }

    title_txt:add_flag(lvgl.FLAG.CLICKABLE)
    title_txt:onevent(lvgl.EVENT.SHORT_CLICKED, function(obj, code)
        showPage(mainPage)
    end)

    appList = lvgl.Object(root, {
        x = 0,
        y = 78,
        w = 192,
        h = 412,
        bg_color = 0,
        border_width = 0,
        pad_all = 0,
        text_font = TEXT_FONT
    })

    reloadAppsFunc = function()
        reloadApps(root,appList)
    end

    return root
end

appsPage1 = createAppPage(rootbase)

showPage(mainPage)

