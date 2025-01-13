local mouse = {}
local log = hs.logger.new('mouse', 'debug')

mouse.eventtaps = {}

-----------
-- setup --
-----------

function mouse:activate(app)
    for _, v in pairs(mouse.eventtaps) do v:start() end
    mouse.app = app
    log.d('mouse activated')
end

function mouse:deactivate()
    for _, v in pairs(mouse.eventtaps) do v:stop() end
    log.d('mouse deactivated')
end

-----------
-- eventtaps --
-----------

mouse.eventtaps.mouse4Disable = hs.eventtap.new(
    { hs.eventtap.event.types.otherMouseUp }, function(event)
        local buttonNumber = tonumber(hs.inspect(event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)))
        if buttonNumber == 3 then
            hs.eventtap.event.newKeyEvent('0', true):setFlags({}):post()
            hs.eventtap.event.newKeyEvent('0', false):setFlags({}):post()
            log.d('mouse4 disable')
        end
    end)

mouse.eventtaps.mouse5Delete = hs.eventtap.new(
    { hs.eventtap.event.types.otherMouseUp }, function(event)
        local buttonNumber = tonumber(hs.inspect(event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)))
        if buttonNumber == 4 then
            log.d('mouse5 delete')
            hs.eventtap.event.newKeyEvent('delete', true):setFlags({}):post()
            hs.eventtap.event.newKeyEvent('delete', false):setFlags({}):post()
        end
    end)

return mouse
