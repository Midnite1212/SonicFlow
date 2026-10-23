import pytest

from sonicflow.hotkey import HoldToTalk


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def setup():
    clock = FakeClock()
    events: list[str] = []
    hold = HoldToTalk(
        {"option"},
        on_start=lambda: events.append("start"),
        on_stop=lambda: events.append("stop"),
        on_cancel=lambda: events.append("cancel"),
        clock=clock,
    )
    return hold, clock, events


def test_hold_and_release_stops(setup):
    hold, clock, events = setup
    hold.press("option")
    clock.now = 1.0
    hold.release("option")
    assert events == ["start", "stop"]


def test_short_tap_cancels(setup):
    hold, clock, events = setup
    hold.press("option")
    clock.now = 0.1
    hold.release("option")
    assert events == ["start", "cancel"]


def test_option_used_as_modifier_cancels_once(setup):
    hold, clock, events = setup
    hold.press("option")
    hold.press("left")
    clock.now = 1.0
    hold.release("option")
    assert events == ["start", "cancel"]


def test_key_repeat_does_not_restart(setup):
    hold, clock, events = setup
    hold.press("option")
    hold.press("option")
    clock.now = 1.0
    hold.release("option")
    assert events == ["start", "stop"]


def test_other_keys_alone_do_nothing(setup):
    hold, _, events = setup
    hold.press("a")
    hold.release("a")
    assert events == []
