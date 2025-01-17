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

-----------
-- setup --
-----------

function createDevice:start()
    createDevice:initDb()

    createDevice.chooser = hs.chooser.new(function(choice)
        return createDevice:select(choice)
    end):queryChangedCallback(function()
        return createDevice:queryChanged()
    end)

    createDevice.socket = hs.socket.udp.new()

    createDevice:refresh()
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
    table.insert(createDevice.hotkeys, hs.hotkey.new(maps.createDevice[1], maps.createDevice[2], createDevice.show))
end

function createDevice:activate(app)
    for _, v in pairs(createDevice.hotkeys) do v:enable() end
    createDevice.app = app
end

function createDevice:deactivate()
    for _, v in pairs(createDevice.hotkeys) do v:disable() end
end

function createDevice:initDb()
    createDevice.db = hs.sqlite3.open(createDevice.freqFile)

    -- schema
    local res = createDevice.db:exec [=[
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
        error('error creating table: ' .. createDevice.db:errmsg())
    end

    -- indexes
    local indexes = {
        'create index if not exists idx_devices_uri on devices(uri);',
        'create index if not exists idx_devices_freq on devices(freq);',
        'create index if not exists idx_devices_is_preset on devices(is_preset);',
        'create index if not exists idx_devices_preset_freq on devices(is_preset, freq desc);',
    }
    for _, idx in ipairs(indexes) do
        res = createDevice.db:exec(idx)
        if res ~= hs.sqlite3.OK then
            print('error creating index: ' .. createDevice.db:errmsg())
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
    createDevice.insertStmt = createDevice.db:prepare(insertSQL)
    if not createDevice.insertStmt then
        error('failed to prepare insert statement: ' .. createDevice.db:errmsg())
    end

    -- update freq statement
    createDevice.updateFreqStmt = createDevice.db:prepare([[
        update devices
        set freq = freq + 1
        where uri = ?
    ]])
    if not createDevice.updateFreqStmt then
        error('failed to prepare update freq statement: ' .. createDevice.db:errmsg())
    end
end

--------------------
-- implementation --
--------------------

function createDevice:show()
    if createDevice.chooser:isVisible() then
        createDevice:buildList()
        hs.alert('rebuilt device list')
    else
        createDevice.chooser:show()
    end
end

function createDevice:select(choice)
    if not choice then return end

    log.d(string.format('selected %s', choice['text']))
    createDevice.socket:send(string.format('create_plugin %s', choice['uri']), '0.0.0.0', 42069)


    createDevice.updateFreqStmt:bind_values(choice['uri'])
    local result = createDevice.updateFreqStmt:step()
    if result ~= hs.sqlite3.DONE then
        error('error updating device freq: ' .. createDevice.db:errmsg())
    end
    createDevice.updateFreqStmt:reset()
    createDevice:refresh()
end

function createDevice:refresh()
    createDevice.deviceData = {}
    for row in createDevice.db:nrows([[
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
        table.insert(createDevice.deviceData, row)
    end

    createDevice.chooser:choices(createDevice.deviceData)
end

function createDevice:queryChanged()
    local query = createDevice.chooser:query()
    if query == '' then
        -- reset choices
        createDevice.chooser:choices(createDevice.deviceData)
        return
    end

    results = {}
    for i = 1, #createDevice.deviceData do
        local dev = createDevice.deviceData[i]
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
    createDevice.chooser:choices(results)
end

function createDevice:buildList()
    createDevice:batchInsert(hs.json.read(createDevice.dataFile))
    createDevice:refresh()
end

function createDevice:batchInsert(objects, batchSize)
    if #objects == 0 then return end
    batchSize = batchSize or 500

    if not createDevice.insertStmt then
        error('insert statement not prepared - was initDb called?')
    end

    local count = 0
    createDevice.db:exec('begin transaction')

    for _, obj in ipairs(objects) do
        local values = {
            obj.uri, -- main uri insert
            obj.chooser_text,
            obj.chooser_subtext,
            obj.uri, -- coalesce subquery
            obj.freq or 0,
            obj.is_preset
        }

        createDevice.insertStmt:bind_values(table.unpack(values))
        local result = createDevice.insertStmt:step()

        if result ~= hs.sqlite3.DONE then
            createDevice.db:exec('rollback')
            error('failed to insert record: ' .. createDevice.db:errmsg())
        end

        createDevice.insertStmt:reset()
        count = count + 1

        if count % batchSize == 0 then
            createDevice.db:exec('commit')
            createDevice.db:exec('begin transaction')
            print(string.format('inserted %d records', count))
        end
    end

    createDevice.db:exec('commit')
    print(string.format('total records inserted: %d', count))
end

return createDevice
