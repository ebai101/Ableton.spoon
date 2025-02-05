from __future__ import absolute_import, print_function, unicode_literals

from .spoon import Spoon

def create_instance(c_instance):
    return Spoon(c_instance=c_instance)
