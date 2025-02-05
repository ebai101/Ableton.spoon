local socket = {}
local log = hs.logger.new('socket', 'debug')

local SEND_PORT = 42069
local RECV_PORT = 42070

socket.callbacks = {}

function socket:init()
    self._socket = hs.socket.udp.server(RECV_PORT, hs.fnutils.partial(self.receiveMessage, self))
    self._socket:receive()
    log.d('listening on port ' .. RECV_PORT)

    return socket
end

function socket:receiveMessage(data, sockaddr)
    local addr = hs.socket.parseAddress(sockaddr)
    log.d(string.format('msg from %s:%d: %s', addr.host, addr.port, data))

    local parsedMsg = {}
    for i in string.gmatch(data, '%S+') do
        table.insert(parsedMsg, i)
    end
    for k, v in pairs(self.callbacks) do
        if parsedMsg[1] == k then
            v(parsedMsg)
        end
    end
end

function socket:sendMessage(msg)
    self._socket:send(msg, '0.0.0.0', SEND_PORT)
end

function socket:addHandler(msg, fn)
    self.callbacks[msg] = fn
end

function socket:clearHandlers()
    self.callbacks = {}
end

function socket:close()
    self._socket:close()
end

return socket
