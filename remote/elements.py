from __future__ import absolute_import, print_function, unicode_literals

from ableton.v3.control_surface import ElementsBase


class Elements(ElementsBase):
    def __init__(self, *a, **k):
        super().__init__(*a, **k)
