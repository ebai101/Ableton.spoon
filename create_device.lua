local createDevice = {}
local log = hs.logger.new('createDev', 'debug')

createDevice.hotkeys = {}
createDevice.dataFile = '~/Music/Ableton/User Library/Remote Scripts/AAAremote/data/plugins.json'
createDevice.freqFile = 'abcd_freq.json'

-----------
-- setup --
-----------

function createDevice:start()
    createDevice.deviceData = hs.json.read(createDevice.dataFile)
    createDevice.freqData = hs.json.read(createDevice.freqFile)
    createDevice.chooser = hs.chooser.new(function(choice)
        return createDevice:select(choice)
    end)
    createDevice.socket = hs.socket.udp.new()
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
        createDevice:refresh()
        hs.alert('refreshed device list')
    else
        createDevice.chooser:choices(createDevice.deviceData)
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

    if createDevice.freqData[choice['text']] == nil then
        createDevice.freqData[choice['text']] = 0
    else
        createDevice.freqData[choice['text']] = createDevice.freqData[choice['text']] + 1
    end

    hs.json.write(createDevice.freqData, createDevice.freqFile, true, true)
    createDevice:refresh()
end

-- createDevice:refresh()
-- Method
-- Sorts the device table using the frequency data from createDevice.freqData
-- Writes the list of devices to createDevice.dataFile
function createDevice:refresh()
    createDevice.deviceData = hs.json.read(createDevice.dataFile)
    table.sort(createDevice.deviceData, function(left, right)
        if createDevice.freqData[left['text']] == nil then
            createDevice.freqData[left['text']] = 0
        end
        if createDevice.freqData[right['text']] == nil then
            createDevice.freqData[right['text']] = 0
        end
        return createDevice.freqData[left['text']] > createDevice.freqData[right['text']]
    end)
    hs.json.write(createDevice.deviceData, createDevice.dataFile, true, true)
    createDevice.chooser:choices(createDevice.deviceData)
end

return createDevice
