import time
from collections.abc import Callable, Collection, Hashable


class HoldToTalk:
    """Turns raw key events into start/stop/cancel for a hold-to-talk hotkey.

    Pressing any other key while the hotkey is held cancels, so the hotkey keeps working as a
    modifier. Holds shorter than `min_hold_s` also cancel, so a brief tap never pastes noise.
    """

    def __init__(
        self,
        hotkeys: Collection[Hashable],
        on_start: Callable[[], None],
        on_stop: Callable[[], None],
        on_cancel: Callable[[], None],
        min_hold_s: float = 0.3,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._hotkeys = hotkeys
        self._on_start = on_start
        self._on_stop = on_stop
        self._on_cancel = on_cancel
        self._min_hold_s = min_hold_s
        self._clock = clock
        self._held_since: float | None = None

    @property
    def active(self) -> bool:
        return self._held_since is not None

    def press(self, key: Hashable) -> None:
        if key in self._hotkeys:
            if not self.active:
                self._held_since = self._clock()
                self._on_start()
        elif self.active:
            self._held_since = None
            self._on_cancel()

    def release(self, key: Hashable) -> None:
        if key not in self._hotkeys or self._held_since is None:
            return
        held_for = self._clock() - self._held_since
        self._held_since = None
        if held_for < self._min_hold_s:
            self._on_cancel()
        else:
            self._on_stop()
