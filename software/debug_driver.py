import time
from pynq import Overlay

class DebugDriver:
    def __init__(self, overlay_path: str, base_addr: int, start: bool = False) -> None:
        self._ol = Overlay(overlay_path)

        self.gpio_rstn = self._ol.gpio_debug.channel1
        self.gpio_end = self._ol.gpio_debug.channel2
        self.gpio_addr = self._ol.gpio_addr_ctrl.channel1

        self.rstn = False
        self._base = base_addr
        self.base_addr = base_addr

        if start:
            self.start()

    @property
    def rstn(self) -> bool:
        return bool(self.gpio_rstn.read())
    
    @rstn.setter
    def rstn(self, data: bool) -> None:
        self.gpio_rstn.write(data, 0x01)

    @property
    def end(self) -> bool:
        return bool(self.gpio_end.read())
    
    @property
    def base_addr(self) -> int:
        return self.gpio_addr.read()
    
    @base_addr.setter
    def base_addr(self, data: int) -> None:
        self._base = data
        self.gpio_addr.write(data, 0xFF)

    def start(self) -> None:
        self.rstn = True

    def reset_stop(self) -> None:
        self.rstn = False
    
    def reset(self, base_addr: int | None = None) -> None:
        self.rstn = False
        self.base_addr = self._base if base_addr is None else base_addr
        time.sleep(0.01)
        self.rstn = True
