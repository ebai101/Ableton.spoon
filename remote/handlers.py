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
            plug = self.spoon.plugins.get(uri, None)
            if plug != None:
                self.spoon.application.browser.load_item(plug)

        def toggle_browser():
            app = self.spoon.application
            visible = app.view.is_view_visible("Browser")
            if visible:
                app.view.hide_view("Browser")
            else:
                app.view.show_view("Browser")
            # for view in app.view.available_main_views():
            #     self.logger.info(view)

        self.server.add_handler("create_plugin", create_plugin)
        self.server.add_handler("toggle_browser", toggle_browser)
