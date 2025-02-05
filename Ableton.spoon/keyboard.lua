local keyboard = {}
local log = hs.logger.new('keyboard', 'debug')

keyboard.hotkeys = {}
keyboard.socket = hs.socket.udp.new()

-----------
-- setup --
-----------

function keyboard:start(socket)
    self.socket = socket
end

function keyboard:bindHotkeys(maps)
    self:menukey(maps, 'consolidate', { 'Edit', 'Consolidate' })
    self:menukey(maps, 'insertMidiClip', { 'Create', 'Insert Empty MIDI Clip' })
    self:menukey(maps, 'browser', { 'View', 'Browser' })
    self:menukey(maps, 'search', { 'View', 'Search in Browser' })
    self:hotkey(maps, 'loopSelection', self.loopSelection)
    self:hotkey(maps, 'closePluginWindows', self.closePluginWindows)
    self:menukey(maps, 'playFromMarker', { 'Playback', 'Play From Insert Marker' })
end

function keyboard:activate(app)
    for _, v in pairs(self.hotkeys) do v:enable() end
    self.app = app
    log.d('keyboard activated')
end

function keyboard:deactivate()
    for _, v in pairs(self.hotkeys) do v:disable() end
    log.d('keyboard deactivated')
end

-- helper function for keybinds that just select a menu item
function keyboard:menukey(maps, name, tbl)
    table.insert(self.hotkeys, hs.hotkey.new(maps[name][1], maps[name][2], function()
        self.app:selectMenuItem(tbl)
        log.d(name)
    end))
end

-- helper function for keybinds that have more complex logic
function keyboard:hotkey(maps, name, func)
    table.insert(self.hotkeys, hs.hotkey.new(maps[name][1], maps[name][2], hs.fnutils.partial(func, self)))
end

-- helper function for keybinds that send commands to the remote
function keyboard:udpkey(maps, name, msg)
    table.insert(self.hotkeys, hs.hotkey.new(maps[name][1], maps[name][2], function()
        self.socket:sendMessage(msg)
        log.d(msg)
    end))
end

--------------
-- keybinds --
--------------

function keyboard:loopSelection()
    local ok = self.app:selectMenuItem({ 'Edit', 'Loop Selection' })
    if ok then
        log.d('looping selection')
        return
    end

    ok = self.app:selectMenuItem({ 'Edit', 'Select Loop' })
    if ok then
        log.d('selected loop')
        return
    end
end

function keyboard:deviceView()
    local menuItem = self.app:findMenuItem({ 'View', 'Device View' })
    if menuItem.ticked then
        self.app:selectMenuItem({ 'View', 'Device View' })
    else
        self.app:selectMenuItem({ 'Navigate', 'Device View' })
    end
end

function keyboard:clipView()
    local ok = self.app:selectMenuItem({ 'View', 'Hide Clip View' })
    if not ok then
        self.app:selectMenuItem({ 'Navigate', 'Clip View' })
    end
end

function keyboard:closePluginWindows()
    local allWindows = self.app:allWindows()
    local mainWindow = self.app:mainWindow()
    for _, win in ipairs(allWindows) do
        if win ~= mainWindow and not win:isStandard() then
            win:close()
        end
    end
end

return keyboard
