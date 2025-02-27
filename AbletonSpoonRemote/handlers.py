from __future__ import absolute_import, print_function, unicode_literals

import logging


class Handlers:
    def __init__(self, spoon):
        self.spoon = spoon
        self.server = self.spoon.server
        self.logger = logging.getLogger("remote")
        self.init_api()

    def init_api(self):
        def create_plugin(msg):
            uri = msg[1]
            plug = self.spoon.devices.get(uri, None)
            if plug != None:
                self.spoon.application.browser.load_item(plug[0])

        def toggle_browser():
            app = self.spoon.application
            visible = app.view.is_view_visible("Browser")
            if visible:
                app.view.hide_view("Browser")
            else:
                app.view.show_view("Browser")

        def notify_draw_mode():
            self.server.send_message(f"draw_mode {int(self.spoon.song.view.draw_mode)}")

        self.server.add_handler("create_plugin", create_plugin)
        self.server.add_handler("toggle_browser", toggle_browser)
        # self.server.add_handler("open_instrument", open_instrument)
        self.spoon.song.view.add_draw_mode_listener(notify_draw_mode)
