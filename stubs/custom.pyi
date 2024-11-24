from typing import Any
from enum import IntEnum
from typing import Protocol
from .types import *

class DCGCallable0(Protocol):
    def __call__(self, **kwargs) -> None:
        ...

class DCGCallable1(Protocol):
    def __call__(self, sender : baseHandler | uiItem, **kwargs) -> None:
        ...

class DCGCallable2(Protocol):
    def __call__(self,
                 sender : baseHandler | uiItem,
                 target : baseItem,
                 **kwargs) -> None:
        ...

class DCGCallable3(Protocol):
    def __call__(self,
                 sender : baseHandler | uiItem,
                 target : baseItem,
                 value : Any,
                 **kwargs) -> None:
        ...

DCGCallable = DCGCallable0 | DCGCallable1 | DCGCallable2 | DCGCallable3


class wrap_mutex:
    def __init__(self, target) -> None:
        ...
    
    def __enter__(self): # -> None:
        ...
    
    def __exit__(self, exc_type, exc_value, traceback): # -> Literal[False]:
        ...
    


class wrap_this_and_parents_mutex:
    def __init__(self, target) -> None:
        ...
    
    def __enter__(self): # -> None:
        ...
    
    def __exit__(self, exc_type, exc_value, traceback): # -> Literal[False]:
        ...
