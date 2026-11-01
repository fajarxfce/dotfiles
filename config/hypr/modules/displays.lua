-- Read the machine-local files maintained by nwg-displays as data, not code.
-- This preserves saved layouts, including separate transform lines.
local root = os.getenv("HOME") .. "/.config/hypr/"
local function trim(s) return s:match("^%s*(.-)%s*$") end
local function fields(s)
    local result = {}
    for value in (s .. ","):gmatch("(.-),") do result[#result + 1] = trim(value) end
    return result
end
local function read_lines(name, callback)
    local file = io.open(root .. name, "r")
    if not file then return end
    for line in file:lines() do
        local cleaned = trim(line:gsub("#.*$", ""))
        if cleaned ~= "" then callback(cleaned) end
    end
    file:close()
end

local monitors, order = {}, {}
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
local numeric = { transform = true, vrr = true, bitdepth = true,
                  sdrbrightness = true, sdrsaturation = true }
local extras = { mirror = true, cm = true }
for key in pairs(numeric) do extras[key] = true end
read_lines("monitors.conf", function(line)
    local value = line:match("^monitor%s*=%s*(.*)$")
    if not value then return end
    local parts = fields(value)
    local output = parts[1]
    if not monitors[output] then
        monitors[output] = { output = output }
        order[#order + 1] = output
    end
    local monitor = monitors[output]
    local index
    if parts[2] == "disable" then
        monitor.disabled = true
        return
    elseif extras[parts[2]] then
        index = 2
    else
        monitor.mode = parts[2] or "preferred"
        monitor.position = parts[3] or "auto"
        monitor.scale = tonumber(parts[4]) or parts[4] or 1
        monitor.disabled = false
        index = 5
    end
    while index <= #parts do
        local key, item = parts[index], parts[index + 1]
        assert(extras[key] and item, "Unsupported monitor option in monitors.conf: " .. tostring(key))
        monitor[key] = numeric[key] and assert(tonumber(item), "Invalid monitor value") or item
        index = index + 2
    end
end)
for _, output in ipairs(order) do hl.monitor(monitors[output]) end

read_lines("workspaces.conf", function(line)
    local value = line:match("^workspace%s*=%s*(.*)$")
    if not value then return end
    local parts = fields(value)
    local rule = { workspace = parts[1] }
    for index = 2, #parts do
        local key, item = parts[index]:match("^([^:]+):(.+)$")
        assert(key and item, "Invalid workspace option: " .. parts[index])
        key = key:gsub("-", "_")
        if item == "true" then rule[key] = true
        elseif item == "false" then rule[key] = false
        else rule[key] = tonumber(item) or item end
    end
    -- Keep numbered workspace buttons available even when they have no apps.
    -- Hyprland creates these only while their assigned monitor is connected.
    if rule.persistent == nil and rule.workspace:match("^%d+$") then
        rule.persistent = true
    end
    hl.workspace_rule(rule)
end)
