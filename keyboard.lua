local keyboard = {}
local log = hs.logger.new('keyboard', 'debug')

keyboard.hotkeys = {}
keyboard.socket = hs.socket.udp.new()

-----------
-- setup --
-----------

function keyboard:bindHotkeys(maps)
    table.insert(keyboard.hotkeys, keyboard:consolidate(maps))
    table.insert(keyboard.hotkeys, keyboard:insertMidiClip(maps))
    table.insert(keyboard.hotkeys, keyboard:selectLoop(maps))
    table.insert(keyboard.hotkeys, keyboard:clipView(maps))
    table.insert(keyboard.hotkeys, keyboard:deviceView(maps))
    table.insert(keyboard.hotkeys, keyboard:browser(maps))
    table.insert(keyboard.hotkeys, keyboard:mixer(maps))
    table.insert(keyboard.hotkeys, keyboard:stop(maps))
    table.insert(keyboard.hotkeys, keyboard:groovePool(maps))
end

function keyboard:activate(app)
    for _, v in pairs(keyboard.hotkeys) do v:enable() end
    keyboard.app = app
    log.d('keyboard activated')
end

function keyboard:deactivate()
    for _, v in pairs(keyboard.hotkeys) do v:disable() end
    log.d('keyboard deactivated')
end

--------------
-- keybinds --
--------------

function keyboard:consolidate(m)
    return hs.hotkey.new(m.consolidate[1], m.consolidate[2], function()
        keyboard.app:selectMenuItem({ 'Edit', 'Consolidate' })
        log.d('consolidate')
    end)
end

function keyboard:insertMidiClip(m)
    return hs.hotkey.new(m.insertMidiClip[1], m.insertMidiClip[2], function()
        keyboard.app:selectMenuItem({ 'Create', 'Insert Empty MIDI Clip' })
    end)
end

function keyboard:selectLoop(m)
    return hs.hotkey.new(m.selectLoop[1], m.selectLoop[2], function()
        hs.eventtap.event.newKeyEvent({ 'cmd' }, 'l', true):post()
        hs.eventtap.event.newKeyEvent({ 'cmd' }, 'l', false):post()
    end)
end

function keyboard:clipView(m)
    return hs.hotkey.new(m.clipView[1], m.clipView[2], function()
        keyboard.app:selectMenuItem({ 'View', 'Clip View' })
    end)
end

function keyboard:deviceView(m)
    return hs.hotkey.new(m.deviceView[1], m.deviceView[2], function()
        keyboard.app:selectMenuItem({ 'View', 'Device View' })
    end)
end

function keyboard:browser(m)
    return hs.hotkey.new(m.browser[1], m.browser[2], function()
        -- keyboard.socket:send('toggle_browser', '0.0.0.0', 42069)
        keyboard.app:selectMenuItem({ 'View', 'Browser' })
    end)
end

function keyboard:mixer(m)
    return hs.hotkey.new(m.mixer[1], m.mixer[2], function()
        keyboard.app:selectMenuItem({ 'View', 'Mixer' })
    end)
end

function keyboard:groovePool(m)
    return hs.hotkey.new(m.groovePool[1], m.groovePool[2], function()
        keyboard.app:selectMenuItem({ 'View', 'Groove Pool' })
    end)
end

function keyboard:stop(m)
    return hs.hotkey.new(m.stop[1], m.stop[2], function()
        keyboard.app:selectMenuItem({ 'Playback', 'Return Play Position to 1.1.1' })
    end)
end

return keyboard
