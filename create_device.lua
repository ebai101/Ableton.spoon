local createDevice = {}
local log = hs.logger.new('createDev', 'debug')

createDevice.hotkeys = {}
createDevice.dataFile = '~/Music/Ableton/User Library/Remote Scripts/AAAremote/data/devices.json'
createDevice.freqFile = 'abcd_freq_data.db'

-----------
-- setup --
-----------

function createDevice:start()
    createDevice.db = hs.sqlite3.open(createDevice.freqFile)
    local res = createDevice.db:exec [=[
        create table if not exists devices (
            id integer primary key,
            uri text unique not null,
            chooser_text text not null,
            chooser_subtext text,
            freq integer default 0
        )
    ]=]
    if res ~= hs.sqlite3.OK then
        print('error creating table: ' .. createDevice.db:errmsg())
    end

    createDevice.chooser = hs.chooser.new(function(choice)
        return createDevice:select(choice)
    end)
    createDevice.socket = hs.socket.udp.new()

    createDevice:refresh()
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

--------------------
-- implementation --
--------------------

-- createDevice:show()
-- Method
-- Shows the device chooser
-- If the device chooser is already active (double press) then it calls createDevice:refresh()
function createDevice:show()
    if createDevice.chooser:isVisible() then
        createDevice:buildList()
        hs.alert('rebuilt device list')
    else
        createDevice.chooser:show()
    end
end

-- createDevice:select(choice)
-- Method
-- Creates an instance of the selected device/preset
-- Writes the updated frequency data to createDevice.freqFile
--
-- Parameters:
-- * choice - A choice from the chooser's choices table
function createDevice:select(choice)
    if not choice then return end

    log.d(string.format('selected %s', choice['text']))
    createDevice.socket:send(string.format('create_plugin %s', choice['uri']), '0.0.0.0', 42069)


    local err = createDevice.db:exec(string.format([[
        update devices
        set freq = freq + 1
        where uri = '%s'
    ]], choice['uri']))
    if err ~= 0 then
        error('error updating device freq: ' .. createDevice.db:errmsg())
    end

    createDevice:refresh()
end

-- createDevice:refresh()
-- Method
-- Sorts the device table using the frequency data from createDevice.freqData
-- Writes the list of devices to createDevice.dataFile
function createDevice:refresh()
    local sortedData = {}
    for row in createDevice.db:nrows([[
    select
        uri,
        chooser_text as text,
        chooser_subtext as subText,
        freq
    from devices
    order by freq desc
    ]]) do
        table.insert(sortedData, row)
    end

    createDevice.chooser:choices(sortedData)
end

function createDevice:buildList()
    createDevice.deviceData = hs.json.read(createDevice.dataFile)
    createDevice:batchInsert(createDevice.deviceData)
    createDevice:refresh()
end

function createDevice:batchInsert(objects, batchSize)
    if #objects == 0 then return end
    batchSize = batchSize or 1000

    local columns = {}
    for key, _ in pairs(objects[1]) do
        colName = key
        if colName == 'text' then
            colName = 'chooser_text'
        elseif colName == 'subText' then
            colName = 'chooser_subtext'
        end
        table.insert(columns, colName)
    end

    local placeholders = table.concat(table.rep({ '?' }, #columns), ',')
    local insertSQL = string.format(
        'insert or replace into devices (%s) values (%s)',
        table.concat(columns, ', '),
        placeholders
    )

    local stmt = createDevice.db:prepare(insertSQL)
    if not stmt then
        error('failed to prepare statement: ' .. createDevice.db:errmsg())
    end

    local count = 0
    createDevice.db:exec('begin transaction')

    for _, obj in ipairs(objects) do
        local values = {}
        for _, col in ipairs(columns) do
            colName = col
            if colName == 'chooser_text' then
                colName = 'text'
            elseif colName == 'chooser_subtext' then
                colName = 'subText'
            end
            local value = obj[colName]
            table.insert(values, value)
        end

        stmt:bind_values(table.unpack(values))
        local result = stmt:step()

        if result ~= hs.sqlite3.DONE then
            stmt:finalize()
            createDevice.db:exec('rollback')
            error('failed to insert record: ' .. createDevice.db:errmsg())
        end

        stmt:reset()
        count = count + 1

        if count % batchSize == 0 then
            createDevice.db:exec('commit')
            createDevice.db:exec('begin transaction')
            print(string.format('inserted %d records', count))
        end
    end

    createDevice.db:exec('commit')
    stmt:finalize()
    print(string.format('total records inserted: %d', count))
end

function table.rep(tbl, n)
    local result = {}
    for i = 1, n do
        for _, v in ipairs(tbl) do
            table.insert(result, v)
        end
    end
    return result
end

return createDevice
