"""
This script will get a list of unauthorized UAD plugins on your system
and hide them from the create device chooser.
"""

import json
import os
import socket
import sqlite3


class UADSocket:
    def __init__(self):
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._socket.connect(("127.0.0.1", 4710))

    def recvall(self):
        data = bytearray()
        while True:
            packet = self._socket.recv(4096)
            if not packet:
                break
            data.extend(packet)
            if b"\x00" in data:
                break
        return data

    def command_recv(self, cmd: str) -> dict[str, str]:
        self.command(cmd)
        return dict(json.loads(self.recvall().decode().replace("\u0000", ""))["data"])

    def command(self, cmd: str) -> None:
        cmd = cmd + "\u0000"
        cmd_bytes = cmd.encode("utf-8")
        self._socket.send(cmd_bytes)

    def close(self):
        self._socket.close()

    def get_plugins(self, authorized: bool) -> list[str]:
        authorized_plugs = []
        self.command("set /Sleep false")
        plugin_count = len(self.command_recv("get /plugins")["children"])
        for p in range(plugin_count):
            plugin = self.command_recv(f"get /plugins/{p}")
            if plugin["properties"]["Authorized"]["value"] == authorized:
                authorized_plugs.append(plugin["properties"]["Name"]["value"])
        return authorized_plugs


class DB:
    def __init__(self):
        self.conn = sqlite3.connect(
            os.path.expanduser("~/.hammerspoon/abcd_freq_data.db")
        )

    def update_visibility(self, plugins: list[str], show: bool):
        action_msg = "showing" if show else "hiding"
        print(f"{action_msg} {len(plugins)} plugins")

        vals = []
        show_int = 1 if show else 0
        for p in plugins:
            vals.append((show_int, p))

        cur = self.conn.cursor()
        cur.executemany(
            """
            update devices
            set show_in_chooser = (?)
            where chooser_text = (?)
            """,
            vals,
        )
        self.conn.commit()

    def close(self):
        self.conn.close()


if __name__ == "__main__":
    uad_sock = UADSocket()
    disable = uad_sock.get_plugins(False)
    enable = uad_sock.get_plugins(True)
    uad_sock.close()

    db = DB()
    db.update_visibility(disable, False)
    db.update_visibility(enable, True)
    db.close()
