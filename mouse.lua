local mouse = {}
local log = hs.logger.new('mouse', 'debug')

mouse.eventtaps = {}
mouse.IGNORE = 9999
mouse.panZoomCmdDown = false
mouse.currentlyDrawing = false

-----------
-- setup --
-----------

function mouse:start(socket)
    self.socket = socket
end

function mouse:activate(app)
    for _, v in pairs(self.eventtaps) do v:start() end
    self.app = app
    log.d('mouse activated')
end

function mouse:deactivate()
    for _, v in pairs(self.eventtaps) do v:stop() end
    log.d('mouse deactivated')
end

local function keyEvent(key, down)
    hs.eventtap.event.newKeyEvent(key, down)
        :setProperty(hs.eventtap.event.properties.eventSourceUserData, mouse.IGNORE)
        :setFlags({})
        :post()
end

---------------
-- eventtaps --
---------------

mouse.eventtaps.mouse4Disable = hs.eventtap.new(
    { hs.eventtap.event.types.otherMouseUp }, function(event)
        local buttonNumber = tonumber(hs.inspect(event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)))
        if buttonNumber == 3 then
            keyEvent('0', true)
            keyEvent('0', false)
            log.d('mouse4 disable')
        end
    end
)

mouse.eventtaps.mouse5Delete = hs.eventtap.new(
    { hs.eventtap.event.types.otherMouseUp }, function(event)
        local buttonNumber = tonumber(hs.inspect(event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)))
        if buttonNumber == 4 then
            keyEvent('delete', true)
            keyEvent('delete', false)
            log.d('mouse5 delete')
        end
    end
)

return mouse
