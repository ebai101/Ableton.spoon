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
    self.create_device:start()

    local app = hs.application.frontmostApplication()
    if app:title() == 'Live' then
        self:_activateAll(app)
        log.d('ableton already at the front, automatically activating')
    end

    self.watcher = hs.application.watcher.new(function(appName, eventType)
        if appName == self.appName then
            if eventType == hs.application.watcher.activated then
                self:_activateAll(hs.appfinder.appFromName(appName))
                log.d('ableton activated')
            elseif eventType == hs.application.watcher.deactivated then
                self:_deactivateAll()
                log.d('ableton deactivated')
            end
        end
    end)
    self.watcher:start()
end

function ableton:stop()
    self.watcher:stop()
    self.create_device:stop()
end

function ableton:bindHotkeys(maps)
    maps = maps or self.defaultKeys
    self.keyboard:bindHotkeys(maps)
    self.create_device:bindHotkeys(maps)
end

function ableton:_activateAll(app)
    self.mouse:activate(app)
    self.keyboard:activate(app)
    self.create_device:activate(app)
end

function ableton:_deactivateAll()
    self.mouse:deactivate()
    self.keyboard:deactivate()
    self.create_device:deactivate()
end

return ableton
