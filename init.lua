--- === ableton ===
---
--- workflow optimizations for ableton
---

local ableton = {}
ableton.__index = ableton

-- Metadata
ableton.name = 'ableton config'
ableton.version = '0.1.0'
ableton.author = 'Ethan Bailey <ebailey256@gmail.com>'
ableton.homepage = 'https://github.com/ebai101/ableton.spoon'
ableton.license = 'MIT - https://opensource.org/licenses/MIT'

ableton.appName = 'Live'
ableton.mouse = dofile(hs.spoons.resourcePath('mouse.lua'))
ableton.keyboard = dofile(hs.spoons.resourcePath('keyboard.lua'))
ableton.create_device = dofile(hs.spoons.resourcePath('create_device.lua'))
ableton.defaultKeys = dofile(hs.spoons.resourcePath('default_keys.lua'))


local log = hs.logger.new('ableton', 'debug')

function ableton:start()
    ableton.create_device:start()

    local app = hs.application.frontmostApplication()
    if app:title() == 'Live' then
        ableton:_activateAll(app)
        log.d('ableton already at the front, automatically activating')
    end

    ableton.watcher = hs.application.watcher.new(function(appName, eventType)
        if appName == ableton.appName then
            if eventType == hs.application.watcher.activated then
                ableton:_activateAll(hs.appfinder.appFromName(appName))
                log.d('ableton activated')
            elseif eventType == hs.application.watcher.deactivated then
                ableton:_deactivateAll()
                log.d('ableton deactivated')
            end
        end
    end)
    ableton.watcher:start()
end

function ableton:stop()
    ableton.watcher:stop()
    ableton.create_device:stop()
end

function ableton:bindHotkeys(maps)
    maps = maps or ableton.defaultKeys
    ableton.keyboard:bindHotkeys(maps)
    ableton.create_device:bindHotkeys(maps)
end

function ableton:_activateAll(app)
    ableton.mouse:activate(app)
    ableton.keyboard:activate(app)
    ableton.create_device:activate(app)
end

function ableton:_deactivateAll()
    ableton.mouse:deactivate()
    ableton.keyboard:deactivate()
    ableton.create_device:deactivate()
end

return ableton
