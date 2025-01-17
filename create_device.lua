local createDevice = {}
local log = hs.logger.new('createDev', 'debug')
local fzy = dofile(hs.spoons.resourcePath('fzy.lua'))

createDevice.hotkeys = {}
createDevice.dataFile = '~/Music/Ableton/User Library/Remote Scripts/AAAremote/data/devices.json'
createDevice.freqFile = 'abcd_freq_data.db'

createDevice.insertStmt = nil
createDevice.updateFreqStmt = nil

local FZY_WEIGHT = 0.6
local FREQ_WEIGHT = 0.4
local QUERY_DELAY_SEC = 0.05
local NANOS_PER_SEC = 1000000000

-----------
-- setup --
-----------

function createDevice:start()
    self:initDb()

    self.chooser = hs.chooser.new(function(choice)
        return self:select(choice)
    end):queryChangedCallback(function()
        local now = hs.timer.absoluteTime()
        if now - self.queryChangedTime < (QUERY_DELAY_SEC * NANOS_PER_SEC) then
            local wait = ((QUERY_DELAY_SEC * NANOS_PER_SEC) - (now - self.queryChangedTime)) / NANOS_PER_SEC
            print('waiting ' .. wait .. ' sec')
            hs.timer.doAfter(wait, hs.fnutils.partial(self.queryChanged, self))
        else
            self:queryChanged()
        end
        self.queryChangedTime = hs.timer.absoluteTime()
    end)

    self.socket = hs.socket.udp.new()

    self.queryChangedTime = hs.timer.absoluteTime()

    self:refresh()
end

function createDevice:stop()
    if self.insertStmt then
        self.insertStmt:finalize()
        self.insertStmt = nil
    end

    if self.updateFreqStmt then
        self.updateFreqStmt:finalize()
        self.updateFreqStmt = nil
    end

    if self.db then
        self.db:close()
        self.db = nil
    end
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
end

function createDevice:deactivate()
    for _, v in pairs(self.hotkeys) do v:disable() end
end

function createDevice:initDb()
    self.db = hs.sqlite3.open(self.freqFile)

    -- schema
    local res = self.db:exec [=[
        create table if not exists devices (
            id integer primary key,
            uri text unique not null,
            chooser_text text not null,
            chooser_subtext text,
            freq integer default 0,
            is_preset boolean not null
        );
    ]=]
    if res ~= hs.sqlite3.OK then
        error('error creating table: ' .. self.db:errmsg())
    end

    -- performance optimizations
    self.db:exec([[
        PRAGMA synchronous = OFF;
        PRAGMA journal_mode = MEMORY;
        PRAGMA temp_store = MEMORY;
        PRAGMA cache_size = -2000;
    ]])

    -- indexes
    local indexes = {
        'create index if not exists idx_devices_uri on devices(uri);',
        'create index if not exists idx_devices_freq on devices(freq);',
        'create index if not exists idx_devices_is_preset on devices(is_preset);',
        'create index if not exists idx_devices_preset_freq on devices(is_preset, freq desc);',
    }
    for _, idx in ipairs(indexes) do
        res = self.db:exec(idx)
        if res ~= hs.sqlite3.OK then
            print('error creating index: ' .. self.db:errmsg())
        end
    end

    -- insert statement
    local columns = { 'uri', 'chooser_text', 'chooser_subtext', 'freq', 'is_preset' }
    local insertSQL = string.format([[
        insert or replace into devices
            (%s)
        values
            (?, ?, ?,
            coalesce((select freq from devices where uri = ?), ?),
            ?)
        ]],
        table.concat(columns, ', ')
    )
    self.insertStmt = self.db:prepare(insertSQL)
    if not self.insertStmt then
        error('failed to prepare insert statement: ' .. self.db:errmsg())
    end

    -- update freq statement
    self.updateFreqStmt = self.db:prepare([[
        update devices
        set freq = freq + 1
        where uri = ?
    ]])
    if not self.updateFreqStmt then
        error('failed to prepare update freq statement: ' .. self.db:errmsg())
    end
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
    self.socket:send(string.format('create_plugin %s', choice['uri']), '0.0.0.0', 42069)


    self.updateFreqStmt:bind_values(choice['uri'])
    local result = self.updateFreqStmt:step()
    if result ~= hs.sqlite3.DONE then
        error('error updating device freq: ' .. self.db:errmsg())
    end
    self.updateFreqStmt:reset()
    self:refresh()
end

function createDevice:refresh()
    self.deviceData = {}
    for row in self.db:nrows([[
    select
        uri,
        chooser_text as text,
        chooser_subtext as subText,
        freq,
        is_preset
    from devices
    order by
        is_preset asc,
        freq desc
    ]]) do
        table.insert(self.deviceData, row)
    end

    self.chooser:choices(self.deviceData)
end

function createDevice:queryChanged()
    local query = self.chooser:query()
    if query == '' then
        -- reset choices
        self.chooser:choices(self.deviceData)
        return
    end

    results = {}
    for i = 1, #self.deviceData do
        local dev = self.deviceData[i]
        local line = dev['text']
        if fzy.has_match(query, line) then
            dev['score'] = fzy.score(query, line)
            local logFreq = hs.math.log(dev['freq'] + 1) -- add 1 in case freq is 0
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
    self:fastBatchInsertTemp(jsonData)
    self:refresh()
end

function createDevice:fastBatchInsertTemp(objects)
    if #objects == 0 then return end

    self.db:exec('begin transaction')

    -- Create temporary table
    self.db:exec([[
        create temporary table if not exists temp_devices (
            uri text primary key,
            chooser_text text not null,
            chooser_subtext text,
            new_freq integer default 0,
            is_preset boolean not null
        ) without rowid
    ]])

    -- Prepare temp insert statement
    local tempInsert = self.db:prepare([[
        insert into temp_devices
            (uri, chooser_text, chooser_subtext, new_freq, is_preset)
        values (?, ?, ?, ?, ?)
    ]])

    -- Insert all records into temp table
    for _, obj in ipairs(objects) do
        tempInsert:bind_values(
            obj.uri,
            obj.chooser_text,
            obj.chooser_subtext,
            obj.freq or 0,
            obj.is_preset
        )
        tempInsert:step()
        tempInsert:reset()
    end

    tempInsert:finalize()

    -- Merge temp table into main table, preserving frequencies
    self.db:exec([[
        insert or replace into devices
            (uri, chooser_text, chooser_subtext, freq, is_preset)
        select
            t.uri,
            t.chooser_text,
            t.chooser_subtext,
            coalesce(d.freq, t.new_freq),
            t.is_preset
        from temp_devices t
        left join devices d on d.uri = t.uri
    ]])

    -- Clean up
    self.db:exec('drop table temp_devices')
    self.db:exec('commit')
end

function createDevice:batchInsert(objects, batchSize)
    if #objects == 0 then return end
    batchSize = batchSize or 500

    if not self.insertStmt then
        error('insert statement not prepared - was initDb called?')
    end

    local count = 0
    self.db:exec('begin transaction')

    for _, obj in ipairs(objects) do
        local values = {
            obj.uri, -- main uri insert
            obj.chooser_text,
            obj.chooser_subtext,
            obj.uri, -- coalesce subquery
            obj.freq or 0,
            obj.is_preset
        }

        self.insertStmt:bind_values(table.unpack(values))
        local result = self.insertStmt:step()

        if result ~= hs.sqlite3.DONE then
            self.db:exec('rollback')
            error('failed to insert record: ' .. self.db:errmsg())
        end

        self.insertStmt:reset()
        count = count + 1

        if count % batchSize == 0 then
            self.db:exec('commit')
            self.db:exec('begin transaction')
            print(string.format('inserted %d records', count))
        end
    end

    self.db:exec('commit')
    print(string.format('total records inserted: %d', count))
end

return createDevice
