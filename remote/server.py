import errno
import logging
import socket
import traceback
from typing import Callable

RECV_PORT = 42069


class Server:
    def __init__(self, addr: tuple[str, int] = ("0.0.0.0", RECV_PORT)):
        self.addr = addr

        self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._socket.setblocking(False)
        self._socket.bind(self.addr)
        self._callbacks = {}

        self.logger = logging.getLogger("remote")
        self.logger.info(
            "starting server (local %s, response port %d)",
            str(self.addr),
            self.addr[1],
        )

    def add_handler(self, cmd: str, handler: Callable):
        self._callbacks[cmd] = handler

    def process_message(self, message):
        message = message.decode("utf-8").strip().split(" ", 1)

        if message[0] in self._callbacks:
            callback = self._callbacks[message[0]]
            if len(message) > 1:
                callback(message)
            else:
                callback()

    def process(self) -> None:
        try:
            while True:
                data, remote_addr = self._socket.recvfrom(65536)
                self.logger.info(f"Message from {remote_addr}: {data.decode('utf-8')}")
                self.process_message(data)

        except socket.error as e:
            if e.errno == errno.ECONNRESET:
                self.logger.warning(f"non-fatal socket error: {traceback.format_exc()}")
            elif e.errno == errno.EAGAIN or e.errno == errno.EWOULDBLOCK:
                pass
            else:
                self.logger.error(f"socket error: {traceback.format_exc()}")

        except Exception as e:
            self.logger.error(f"error handling message: {e}")
            self.logger.warning(f"error: {traceback.format_exc()}")

    def shutdown(self) -> None:
        self._socket.close()
