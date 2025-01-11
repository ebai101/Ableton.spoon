local createDevice = {}
local log = hs.logger.new('createDev', 'debug')

createDevice.hotkeys = {}
createDevice.dataFile = '~/Music/Ableton/User Library/Remote Scripts/AAAremote/data/plugins.json'

-----------
-- setup --
-----------

function createDevice:start()
    createDevice.deviceData = hs.json.read(createDevice.dataFile)
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
-- If the device chooser is already active (double press) then it calls createDevice:rebuild()
function createDevice:show()
    if createDevice.chooser:isVisible() then
        createDevice:rebuild()
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
end

return createDevice
