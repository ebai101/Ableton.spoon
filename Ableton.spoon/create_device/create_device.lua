local createDevice = {}
local log = hs.logger.new('createDev', 'debug')
local fzy = dofile(hs.spoons.resourcePath('fzy.lua'))

createDevice.hotkeys = {}
createDevice.dataFile = '~/Music/Ableton/User Library/Remote Scripts/AbletonSpoonRemote/data/devices.json'
createDevice.repo = dofile(hs.spoons.resourcePath('repo.lua'))

local FZY_WEIGHT = 0.6
local FREQ_WEIGHT = 0.4

-----------
-- setup --
-----------

function createDevice:start(socket)
    self.repo:open()

    self.chooser = hs.chooser.new(function(choice)
        return self:select(choice)
    end):queryChangedCallback(function()
        self:queryChanged()
    end)

    self.socket = socket
    self:refresh()
end

function createDevice:bindHotkeys(maps)
    table.insert(self.hotkeys, hs.hotkey.new(
        maps.createDevice[1],
        maps.createDevice[2],
        hs.fnutils.partial(self.show, self)
    ))
end

function createDevice:activate(app)
    for _, v in pairs(self.hotkeys) do v:enable() end
    self.app = app
    self.repo:open()
end

function createDevice:deactivate()
    for _, v in pairs(self.hotkeys) do v:disable() end
    self.repo:close()
end

--------------------
-- implementation --
--------------------

function createDevice:show()
    if self.chooser:isVisible() then
        print('starting')
        local start = hs.timer.absoluteTime()
        self:buildList()
        hs.alert('rebuilt device list')
        local elapsed = hs.timer.absoluteTime() - start
        print('insert took ' .. elapsed / 1000000 .. ' ms')
    else
        self.chooser:show()
    end
end

function createDevice:select(choice)
    if not choice then return end

    log.d(string.format('selected %s', choice['text']))
    self.socket:sendMessage(string.format('create_plugin %s', choice['uri']))
    self.repo:updateFreq(choice['uri'])

    self:refresh()
end

function createDevice:refresh()
    self.deviceData = self.repo:getDevices()
    self.chooser:choices(self.deviceData)
end

function createDevice:queryChanged()
    local query = self.chooser:query()
    if query == '' then
        self.chooser:choices(self.deviceData)
        return
    end

    results = {}
    for i = 1, #self.deviceData do
        local dev = self.deviceData[i]
        local line = dev['text']
        if fzy.has_match(query, line) then
            dev['score'] = fzy.score(query, line)
            local logFreq = 1
            if dev['freq'] ~= nil then
                logFreq = hs.math.log(dev['freq'] + 1)
            end
            dev['weightedRank'] = (dev['score'] * FZY_WEIGHT) + (logFreq * FREQ_WEIGHT)
            table.insert(results, dev)
        end
    end

    table.sort(results, function(a, b)
        return a['weightedRank'] > b['weightedRank']
    end)
    self.chooser:choices(results)
end

function createDevice:buildList()
    local jsonData = hs.json.read(self.dataFile)
    self.repo:insertDevices(jsonData)
    self:refresh()
end

return createDevice
