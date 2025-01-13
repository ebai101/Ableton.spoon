from __future__ import absolute_import, print_function, unicode_literals

import json
import logging
import os

from ableton.v3.control_surface import ControlSurface, ControlSurfaceSpecification

from .elements import Elements
from .handlers import Handlers
from .server import RECV_PORT, Server

logger = logging.getLogger("remote")


class Specification(ControlSurfaceSpecification):
    elements_type = Elements


class Spoon(ControlSurface):
    def __init__(self, c_instance):
        self.log_level = "info"
        super().__init__(c_instance=c_instance, specification=Specification)

    def walk_devices(self):
        data = {}  # uri[(plugin_instance, path)]

        def _walk(item, current_path):
            if item.is_loadable:
                data[item.uri] = (item, current_path[:])
            next_path = current_path + [item.name] if item.is_folder else current_path
            for child in item.iter_children:
                _walk(child, next_path)

        _walk(self.application.browser.plugins, [])
        _walk(self.application.browser.audio_effects, ["Audio Effects"])
        _walk(self.application.browser.instruments, ["Instruments"])
        _walk(self.application.browser.midi_effects, ["MIDI Effects"])

        return data

    def dump_plugin_list(self):
        module_path = os.path.dirname(os.path.realpath(__file__))
        data_dir = os.path.join(module_path, "data")
        if not os.path.exists(data_dir):
            os.mkdir(data_dir, 0o755)
        device_data_path = os.path.join(data_dir, "devices.json")

        device_list = []
        for uri, plug in self.devices.items():
            subtext = " - ".join(plug[1])
            device_list.append({"uri": uri, "text": plug[0].name, "subText": subtext})

        with open(device_data_path, "w") as f:
            f.write(json.dumps(device_list))

    def init_api(self):
        with self.component_guard():
            self.handlers = Handlers(self)

    def start_logging(self):
        module_path = os.path.dirname(os.path.realpath(__file__))
        log_dir = os.path.join(module_path, "logs")
        if not os.path.exists(log_dir):
            os.mkdir(log_dir, 0o755)
        log_path = os.path.join(log_dir, "remote.log")

        self.log_file_handler = logging.FileHandler(log_path)
        self.log_file_handler.setLevel(self.log_level.upper())
        formatter = logging.Formatter("(%(asctime)s) [%(levelname)s] %(message)s")
        self.log_file_handler.setFormatter(formatter)

        logger.addHandler(self.log_file_handler)

    def stop_logging(self):
        logger.removeHandler(self.log_file_handler)

    def setup(self):
        try:
            self.start_logging()
            self.server = Server()

            self.schedule_message(0, self.tick)

            self.devices = self.walk_devices()
            self.dump_plugin_list()
            self.init_api()

            self.show_message(f"listening on port {RECV_PORT}")
            logger.info(f"listening on addr {self.server.addr}")
        except OSError as msg:
            self.show_message(f"couldn't bind to port {RECV_PORT} ({msg})")
            logger.info(f"couldn't bind to port {RECV_PORT} ({msg})")

    def tick(self):
        logger.debug("Tick...")
        self.server.process()
        self.schedule_message(1, self.tick)

    def disconnect(self):
        self.show_message("Disconnecting...")
        logger.info("Disconnecting...")
        self.stop_logging()
        self.server.shutdown()
        return super().disconnect()
