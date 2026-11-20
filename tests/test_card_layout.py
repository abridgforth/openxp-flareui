"""Card layout (CardLayout.lua): layout exceptions 8 (card height and
scrolling) and 9 (step blocks per the /oxpfui mock), observed through the
lupa harness with OpenXP's refresh geometry (HARNESS.LayoutCard)."""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402

GAP = 8


def place(env, card_top, tracker_bottom=None, docked=False):
    """Give the card (and the tracker) screen positions."""
    env.run(f"OpenXPCard.GetTop = function() return {card_top} end")
    if tracker_bottom is not None:
        env.run(f"FlareUI_ObjectiveTracker.GetBottom = function() return {tracker_bottom} end")
    env.run(f"OXPFUI.Dock.IsActive = function() return {'true' if docked else 'false'} end")


def refresh(env, **opts):
    args = ", ".join(f"{k} = {v}" for k, v in opts.items())
    env.run(f"HARNESS.LayoutCard({{{args}}}); OXPFUI.Reapply('t')")


def card_height(env):
    return env.run("return OpenXPCard:GetHeight()")


def scrolling(env):
    return env.run("local s = OXPFUI.CardLayout.state[OpenXPCard]; "
                   "return s ~= nil and s.scrolling == true")


class StepBlocks(unittest.TestCase):
    """Exception 9: the mock's step blocks on the real card."""

    def setUp(self):
        self.env = Env()
        self.env.boot()
        refresh(self.env)

    def test_badge_and_number_give_way_to_a_small_icon(self):
        env = self.env
        self.assertEqual(env.run("local b = HARNESS.cardBits.blocks[1]; "
                                 "return b.badge:IsShown(), b.num:IsShown(), "
                                 "b.oxpfuiIcon:IsShown(), b.oxpfuiIcon:GetWidth()"),
                         (False, False, True, 14))

    def test_title_and_lines_reflow_into_the_freed_width(self):
        env = self.env
        x0 = 14 + 14 + 6
        self.assertEqual(env.run("local b = HARNESS.cardBits.blocks[1]; "
                                 "local pt, rel, rpt, x = b.title:GetPoint(1); "
                                 "return pt, rel == b, x"), ("TOPLEFT", True, x0))
        self.assertEqual(env.run("local b = HARNESS.cardBits.blocks[1]; "
                                 "local _, _, _, x = b.lines[1]:GetPoint(1); return x"), x0)
        width = env.run("return HARNESS.cardBits.blocks[1]:GetWidth()")
        self.assertEqual(env.run("return HARNESS.cardBits.blocks[1].title:GetWidth()"),
                         width - x0 - 14)

    def test_blocks_restack_in_the_body(self):
        env = self.env
        self.assertEqual(env.run("""
          local b1, b2 = HARNESS.cardBits.blocks[1], HARNESS.cardBits.blocks[2]
          local _, rel, _, _, y = b2:GetPoint(1)
          return rel == b1:GetParent(), -y == b1:GetHeight()
        """), (True, True))

    def test_separator_is_a_faint_bronze_hairline(self):
        r, g, b, a = self.env.run(
            "return HARNESS.cardBits.blocks[2].sep:GetColorTexture()")
        acc = self.env.run("local c = OXPFUI.theme.C.ACCENT; return c[1], c[2], c[3]")
        self.assertEqual((r, g, b), acc)
        self.assertAlmostEqual(a, 0.25)

    def test_reapplies_are_idempotent(self):
        env = self.env
        before = env.run("return HARNESS.cardBits.blocks[1]:GetHeight()")
        env.run("OXPFUI.Reapply('t'); OXPFUI.Reapply('t')")
        self.assertEqual(env.run("return HARNESS.cardBits.blocks[1]:GetHeight()"), before)


class CardHeight(unittest.TestCase):
    """Exception 8: the card fits between the tracker and the screen bottom."""

    def test_short_content_keeps_its_own_height(self):
        env = Env(flareui=True)
        env.boot()
        place(env, card_top=900)
        refresh(env, blocks=1)
        self.assertFalse(scrolling(env))
        self.assertLessEqual(card_height(env), 900 - GAP)

    def test_expanded_tracker_shrinks_the_card_and_keeps_both_gaps(self):
        env = Env(flareui=True)
        env.boot()
        # Tracker bottom at 300: room = 300 - gap (top) - gap (bottom).
        place(env, card_top=300 - GAP, tracker_bottom=300, docked=True)
        refresh(env, extra=200)
        self.assertEqual(card_height(env), 300 - 2 * GAP)
        self.assertTrue(scrolling(env))
        # The steps moved into the scroll frame; Up Next sits on the toolbar.
        self.assertTrue(env.run("local v = OpenXPCard.oxpfuiViewport; "
                                "return HARNESS.cardBits.body:GetParent() == v.child "
                                "and v:IsShown()"))
        self.assertEqual(env.run("local u = HARNESS.cardBits.upNext; "
                                 "local pt, rel, rpt = u:GetPoint(1); "
                                 "return pt, rel == HARNESS.cardBits.bar, rpt"),
                         ("BOTTOMLEFT", True, "TOPLEFT"))

    def test_minimum_height(self):
        env = Env(flareui=True)
        env.boot()
        place(env, card_top=60, tracker_bottom=60, docked=True)
        refresh(env, extra=200)
        self.assertEqual(card_height(env), 160)

    def test_a_smaller_dragged_height_is_kept(self):
        env = Env(flareui=True)
        env.boot()
        place(env, card_top=900)
        env.run("HARNESS.openxp.card.height = 220")
        refresh(env, extra=100)
        self.assertEqual(card_height(env), 220)
        self.assertTrue(scrolling(env))

    def test_room_again_restores_openxp_layout(self):
        env = Env(flareui=True)
        env.boot()
        place(env, card_top=300 - GAP, tracker_bottom=300, docked=True)
        refresh(env, extra=200)
        self.assertTrue(scrolling(env))
        place(env, card_top=1000 - GAP, tracker_bottom=1000, docked=True)
        refresh(env, blocks=1)
        self.assertFalse(scrolling(env))
        self.assertTrue(env.run("return HARNESS.cardBits.body:GetParent() == OpenXPCard "
                                "and not OpenXPCard.oxpfuiViewport:IsShown()"))
        self.assertEqual(env.run("local u = HARNESS.cardBits.upNext; "
                                 "local pt, rel = u:GetPoint(1); "
                                 "return pt, rel == HARNESS.cardBits.body"),
                         ("TOPLEFT", True))

    def test_tracker_growing_refits_the_card_without_an_openxp_refresh(self):
        env = Env(flareui=True)
        env.boot()
        place(env, card_top=600 - GAP, tracker_bottom=600, docked=True)
        refresh(env, extra=200)
        tall = card_height(env)
        place(env, card_top=250 - GAP, tracker_bottom=250, docked=True)
        env.run("FlareUI_ObjectiveTracker:GetScript('OnSizeChanged')(FlareUI_ObjectiveTracker)")
        self.assertLess(card_height(env), tall)
        self.assertEqual(card_height(env), 250 - 2 * GAP)

    def test_no_resize_while_openxp_is_sizing(self):
        env = Env(flareui=True)
        env.boot()
        place(env, card_top=300 - GAP, tracker_bottom=300, docked=True)
        env.run("HARNESS.openxp.card.sizing = true")
        refresh(env, extra=200)
        self.assertEqual(card_height(env), env.run("return HARNESS.cardContent"))


class Wheel(unittest.TestCase):
    """Option A: the wheel scrolls the steps first, then the history."""

    def setUp(self):
        env = self.env = Env(flareui=True)
        env.boot()
        place(env, card_top=300 - GAP, tracker_bottom=300, docked=True)
        refresh(env, extra=200)

    def wheel(self, delta):
        self.env.run(f"OpenXPCard:GetScript('OnMouseWheel')(OpenXPCard, {delta})")

    def scroll(self):
        return self.env.run("return OXPFUI.CardLayout.state[OpenXPCard].y")

    def history(self):
        return self.env.run("return #HARNESS.histWheel")

    def test_down_scrolls_steps_and_up_returns(self):
        mx = self.env.run("return OXPFUI.CardLayout.state[OpenXPCard].max")
        self.wheel(-1)
        self.assertAlmostEqual(self.scroll(), min(24, mx))
        self.assertGreater(self.scroll(), 0)
        self.assertEqual(self.history(), 0)
        self.wheel(1)
        self.assertEqual(self.scroll(), 0)
        self.assertEqual(self.history(), 0)

    def test_up_at_the_top_opens_history(self):
        self.wheel(1)
        self.assertEqual(self.history(), 1)
        self.assertEqual(self.scroll(), 0)

    def test_with_history_open_down_closes_it_first(self):
        self.wheel(1)  # history open (histOffset 1)
        self.wheel(-1)
        self.assertEqual(self.history(), 2)
        self.assertEqual(self.scroll(), 0)

    def test_scroll_stops_at_the_end(self):
        for _ in range(100):
            self.wheel(-1)
        mx = self.env.run("return OXPFUI.CardLayout.state[OpenXPCard].max")
        self.assertEqual(self.scroll(), mx)
        self.assertGreater(mx, 0)


if __name__ == "__main__":
    unittest.main()
