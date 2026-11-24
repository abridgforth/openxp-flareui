"""OpenXP 2.x (OpenXP2.lua): the FlareUI look on OpenXP's rewrite, reached
through its named frames only (its addon table is private)."""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402


def boot(**kw):
    env = Env(openxp2=True, **kw)
    env.boot()
    return env


class Detection(unittest.TestCase):
    def test_openxp_2_is_found_and_only_its_skins_run(self):
        env = boot()
        self.assertEqual(env.run("return OXPFUI_NAMESPACE.OpenXPGen()"), 2)
        report = env.run("return OXPFUI_NAMESPACE.DebugReport()")
        self.assertIn("OpenXP 2 card", report)
        self.assertNotIn("guide card", report.split("Skipped")[0].lower().replace("openxp 2 card", ""))
        self.assertIn("2.0.3", report)

    def test_no_version_warning_on_the_tested_version(self):
        env = boot()
        self.assertIsNone(env.run("return OXPFUI_NAMESPACE.VersionMismatch()"))


class Metadata(unittest.TestCase):
    def test_version_read_without_the_old_global(self):
        # The Forever client has only C_AddOns.GetAddOnMetadata.
        env = Env(openxp2=True, load_addon=False)
        env.run("GetAddOnMetadata = nil")
        env.load_addon()
        env.boot()
        self.assertNotEqual(env.run("return OXPFUI_NAMESPACE.version"), "dev")
        self.assertEqual(env.run("return OXPFUI_NAMESPACE.OpenXPGen()"), 2)


class Card(unittest.TestCase):
    def setUp(self):
        self.env = boot(db={"frameStyle": "flareui"})

    def test_flareui_backdrop_and_title_strip(self):
        env = self.env
        bd = env.run("return OpenXPCard:GetBackdrop().edgeFile")
        self.assertNotIn("WHITE8X8", bd)
        self.assertIs(env.run("return OpenXPCard.oxpfuiBands.title.oxpfuiStrip.L:IsShown()"), True)

    def test_header_is_one_row_on_the_strip(self):
        env = self.env
        h = "HARNESS.OXP2.header"
        self.assertEqual(env.run(f"return {h}.zone:GetText()"),
                         "Darkshore |cFF8C8C8C(16–19)|r")
        self.assertEqual(env.run(f"return {h}:GetHeight()"), 30)
        self.assertEqual(env.run(f"return {h}.range:GetAlpha()"), 0)
        self.assertEqual(env.run(f"""
          local pt, rel, rpt, x = {h}.zone:GetPoint(1)
          return pt, rel == OpenXPCard.oxpfuiBands.title, x
        """), ("LEFT", True, 6))
        self.assertEqual(env.run(f"""
          local pt, rel = {h}.step:GetPoint(1)
          return pt, rel == OpenXPCard.oxpfuiBands.title
        """), ("RIGHT", True))

    def test_openxp_refresh_lays_out_under_our_header(self):
        # OpenXP reads the header's height right after setting it, to size
        # the steps' view: it must already see ours.
        env = self.env
        env.run("HARNESS.OXP2.Refresh()")
        self.assertEqual(env.run("return HARNESS.OXP2.headerHeightSeen"), 30)
        self.assertEqual(env.run("return HARNESS.OXP2.header.zone:GetText()"),
                         "Darkshore |cFF8C8C8C(16–19)|r")

    def test_header_follows_the_guide(self):
        env = self.env
        env.run("HARNESS.OXP2.guideName = '20-21 Ashenvale'; HARNESS.OXP2.Refresh()")
        self.assertEqual(env.run("return HARNESS.OXP2.header.zone:GetText()"),
                         "Ashenvale |cFF8C8C8C(20–21)|r")

    def test_flareui_wins_over_an_openxp_repaint(self):
        env = self.env
        env.run("HARNESS.deferTimers = true; HARNESS.OXP2.Repaint(); HARNESS.RunTimers()")
        self.assertNotIn("WHITE8X8", env.run("return OpenXPCard:GetBackdrop().edgeFile"))
        b = env.run("return OXPFUI_NAMESPACE.theme.C.BORDER[1]")
        r = env.run("local r = OpenXPCard:GetBackdropBorderColor(); return r")
        self.assertAlmostEqual(r, b)
        gold = env.run("return OXPFUI_NAMESPACE.theme.C.TITLE[1]")
        self.assertAlmostEqual(env.run("return (HARNESS.OXP2.progress:GetColorTexture())"), gold)
        self.assertAlmostEqual(env.run("return (HARNESS.OXP2.blocks[1].title:GetTextColor())"), gold)

    def test_toolbar_buttons_are_flareui_boxes(self):
        env = self.env
        self.assertTrue(env.run("return HARNESS.OXP2.bar.prev.oxpfuiBox ~= nil"))
        self.assertEqual(env.run("return HARNESS.OXP2.bar.bg:GetAlpha()"), 0)
        self.assertIs(env.run("return HARNESS.OXP2.bar.oxpfuiBands.toolbar.oxpfuiStrip.L:IsShown()"), True)
        # OpenXP tints the icon grey on leave; it stays gold.
        env.run("local b = HARNESS.OXP2.bar.prev; b:GetScript('OnEnter')(b); b:GetScript('OnLeave')(b)")
        gold = env.run("return OXPFUI_NAMESPACE.theme.C.TITLE[2]")
        self.assertAlmostEqual(env.run("local _, g = HARNESS.OXP2.bar.prev.icon:GetVertexColor(); return g"), gold)

    def test_more_button_is_a_flareui_box(self):
        env = self.env
        self.assertTrue(env.run("return HARNESS.OXP2.more.oxpfuiBox ~= nil"))
        self.assertEqual(env.run("return HARNESS.OXP2.more.back:GetAlpha()"), 0)

    def test_step_separators_bronze(self):
        acc = self.env.run("return OXPFUI_NAMESPACE.theme.C.ACCENT[1]")
        r, _, _, a = self.env.run("return HARNESS.OXP2.blocks[2].sep:GetColorTexture()")
        self.assertAlmostEqual(r, acc)
        self.assertAlmostEqual(a, 0.25)


class StepList(unittest.TestCase):
    def test_built_on_first_open_and_skinned(self):
        env = boot(db={"frameStyle": "flareui"})
        self.assertIsNone(env.run("return rawget(_G, 'OpenXPSteps')"))
        env.run("local n = HARNESS.OXP2.header.nav; n:GetScript('OnClick')(n)")
        s = "OpenXPSteps"
        self.assertIs(env.run(f"return {s}.oxpfuiBands.title.oxpfuiStrip.L:IsShown()"), True)
        self.assertEqual(env.run(f"return {s}.title:GetText()"),
                         "Darkshore |cFF8C8C8C(16–19)|r")
        self.assertEqual(env.run(f"return {s}.guide:GetAlpha()"), 0)
        self.assertIs(env.run(f"return {s}.back:IsShown()"), False)
        self.assertEqual(env.run(f"""
          local c = {s}.close
          local pt, rel = c:GetPoint(1)
          return pt, rel == {s}.oxpfuiBands.title, c:GetWidth(), c.icon:GetAlpha()
        """), ("RIGHT", True, 24, 0))


    def _open(self):
        env = boot(db={"frameStyle": "flareui"})
        env.run("local n = HARNESS.OXP2.header.nav; n:GetScript('OnClick')(n)")
        return env

    def test_you_are_here_accents_are_bronze_after_every_paint(self):
        env = self._open()
        acc = env.run("local c = OXPFUI_NAMESPACE.theme.C.ACCENT; return c[1], c[2], c[3]")
        for _ in range(2):  # opening, then a scroll repaints in blue again
            row = "OpenXPSteps.rows[2]"
            self.assertEqual(env.run(f"local r,g,b = {row}.node:GetVertexColor(); return r,g,b"), acc)
            self.assertEqual(env.run(f"local r,g,b = {row}.accent:GetColorTexture(); return r,g,b"), acc)
            self.assertEqual(env.run(f"local r,g,b = {row}.pill.text:GetTextColor(); return r,g,b"), acc)
            self.assertEqual(env.run(f"local r,g,b = {row}.glow:GetVertexColor(); return r,g,b"), acc)
            self.assertEqual(env.run("local r,g,b = OpenXPSteps.rows[1].header:GetTextColor(); return r,g,b"), acc)
            env.run("HARNESS.OXP2.PaintSteps()")
        # other headings keep OpenXP's faint grey
        faint = env.run("return HARNESS.OXP2.C.faint[1]")
        self.assertAlmostEqual(env.run("return (OpenXPSteps.rows[3].header:GetTextColor())"), faint)

    def test_no_second_rule_under_the_header(self):
        env = self._open()
        self.assertIsNone(env.run("return OpenXPSteps.oxpfuiBands.stepsHead"))
        self.assertEqual(env.run("return OpenXPSteps.headLine:GetAlpha()"), 0)

    def test_not_listed_as_skinned_before_it_opens(self):
        env = boot()
        report = env.run("return OXPFUI_NAMESPACE.DebugReport()")
        skinned = [l for l in report.split("\n") if l.startswith("Skinned")][0]
        self.assertNotIn("step list", skinned)


class QuestTargets(unittest.TestCase):
    def test_rows_under_the_strip_and_box_taller(self):
        env = boot(db={"frameStyle": "flareui", "targetsIcons": False})
        self.assertEqual(env.run("return OpenXPTargets.title:GetText()"), "Targets")
        self.assertEqual(env.run("local _,_,_,_,y = OpenXPTargetButton:GetPoint(1); return y"), -32)
        self.assertEqual(env.run("local _,_,_,_,y = OpenXPTargetRow2:GetPoint(1); return y"), -58)
        self.assertEqual(env.run("return OpenXPTargets:GetHeight()"), 20 + 2 * 26 + 14)
        # OpenXP refreshing again: same place, same size
        env.run("HARNESS.OXP2.RefreshTargets(2); HARNESS.OXP2.RefreshTargets(2)")
        self.assertEqual(env.run("return OpenXPTargets:GetHeight()"), 20 + 2 * 26 + 14)
        env.run("HARNESS.OXP2.RefreshTargets(3)")
        self.assertEqual(env.run("return OpenXPTargets:GetHeight()"), 20 + 3 * 26 + 14)
        self.assertEqual(env.run("local _,_,_,_,y = OpenXPTargetRow3:GetPoint(1); return y"), -84)

    def test_waits_for_combat_to_end(self):
        env = boot(db={"targetsIcons": False})
        env.set_combat(True)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        env.set_combat(False)
        env.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.run("local _,_,_,_,y = OpenXPTargetButton:GetPoint(1); return y"), -32)


class TargetIcons(unittest.TestCase):
    """RestedXP-style: a row of icon squares, the names in tooltips."""

    def test_icons_in_a_row_and_box_fits_them(self):
        env = boot()
        self.assertEqual(env.run("return OpenXPTargetButton:GetWidth(), OpenXPTargetButton:GetHeight()"), (30, 30))
        self.assertEqual(env.run("local p,_,_,x,y = OpenXPTargetRow2:GetPoint(1); return p, x, y"), ("TOPLEFT", 34, 0))
        self.assertEqual(env.run("return OpenXPTargets:GetWidth(), OpenXPTargets:GetHeight()"), (64, 30))
        self.assertEqual(env.run("return OpenXPTargetButton.text:GetAlpha(), OpenXPTargets.title:GetAlpha()"), (0, 0))
        self.assertTrue(env.run("return OpenXPTargetButton.oxpfuiRim:IsShown()"))
        self.assertEqual(env.run("return OpenXPTargetButton.oxpfuiKey:GetText()"), "F")
        # no window chrome
        self.assertEqual(env.run("local _,_,_,a = OpenXPTargets:GetBackdropColor(); return a"), 0)

    def test_openxp_refresh_keeps_the_icons(self):
        env = boot()
        env.run("HARNESS.OXP2.RefreshTargets(3)")
        self.assertEqual(env.run("return OpenXPTargets:GetWidth(), OpenXPTargets:GetHeight()"), (98, 30))
        self.assertEqual(env.run("return OpenXPTargetRow3:GetWidth()"), 30)

    def test_item_button_same_size_and_flareui_square(self):
        env = boot()
        self.assertEqual(env.run("return OpenXPItemButton:GetWidth()"), 30)
        box = env.run("return OXPFUI_NAMESPACE.theme.C.BOX[1]")
        env.run("HARNESS.OXP2.Repaint()")
        self.assertAlmostEqual(env.run("return (OpenXPItemButton:GetBackdropBorderColor())"), box)

    def test_switching_back_to_names(self):
        env = boot()
        env.run("OXPFUI_NAMESPACE.Settings.Set('targetsIcons', false)")
        self.assertEqual(env.run("return OpenXPTargets:GetWidth()"), 190)
        self.assertEqual(env.run("return OpenXPTargetButton.text:GetAlpha()"), 1)
        self.assertEqual(env.run("return OpenXPItemButton:GetWidth()"), 36)


def place_card(env, left=600, right=930, top=700, bottom=400):
    env.run(f"""
      OpenXPCard.GetLeft = function() return {left} end
      OpenXPCard.GetRight = function() return {right} end
      OpenXPCard.GetTop = function() return {top} end
      OpenXPCard.GetBottom = function() return {bottom} end
    """)


class PinTargets(unittest.TestCase):
    def test_below_the_guide_item_then_targets(self):
        env = boot(db={"pinTargets": "below"})
        place_card(env)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        self.assertEqual(env.run("local p,_,_,x,y = OpenXPItemButton:GetPoint(1); return p,x,y"),
                         ("TOPRIGHT", 930 - 64 - 4, 392))
        self.assertEqual(env.run("local p,_,_,x,y = OpenXPTargets:GetPoint(1); return p,x,y"),
                         ("TOPRIGHT", 930, 392))

    def test_beside_the_guide_top_aligned_away_from_the_edge(self):
        env = boot(db={"pinTargets": "side"})
        place_card(env)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        self.assertEqual(env.run("local p,_,_,x,y = OpenXPTargets:GetPoint(1); return p,x,y"),
                         ("TOPRIGHT", 600 - 6, 700))
        # card on the left of the screen: the targets go right of it
        place_card(env, left=100, right=430)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        self.assertEqual(env.run("local p,_,_,x,y = OpenXPItemButton:GetPoint(1); return p,x,y"),
                         ("TOPLEFT", 436, 700))
        self.assertEqual(env.run("local p,_,_,x,y = OpenXPTargets:GetPoint(1); return p,x,y"),
                         ("TOPLEFT", 436 + 30 + 4, 700))

    def test_openxp_placing_them_again_is_undone(self):
        env = boot(db={"pinTargets": "below"})
        place_card(env)
        env.run("OXPFUI_NAMESPACE.Reapply('t'); HARNESS.OXP2.Place()")
        self.assertEqual(env.run("local _,_,_,x,y = OpenXPTargets:GetPoint(1); return x,y"), (930, 392))

    def test_drag_suspended_while_pinned_and_off_restores(self):
        env = boot(db={"pinTargets": "below"})
        place_card(env)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        env.run("OpenXPTargets:GetScript('OnDragStart')(OpenXPTargets)")
        self.assertEqual(env.run("return HARNESS.OXP2.calls['box drag'] or 0"), 0)
        env.run("OXPFUI_NAMESPACE.Settings.Set('pinTargets', 'off')")
        self.assertEqual(env.run("local _,_,_,x,y = OpenXPTargets:GetPoint(1); return x,y"), (592, 648))
        env.run("OpenXPTargets:GetScript('OnDragStart')(OpenXPTargets)")
        self.assertEqual(env.run("return HARNESS.OXP2.calls['box drag']"), 1)

    def test_waits_for_combat(self):
        env = boot()
        place_card(env)
        env.set_combat(True)
        env.run("OXPFUI_NAMESPACE.Settings.Set('pinTargets', 'below')")
        self.assertEqual(env.run("local _,_,_,x,y = OpenXPTargets:GetPoint(1); return x,y"), (592, 648))
        env.set_combat(False)
        env.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.run("local _,_,_,x,y = OpenXPTargets:GetPoint(1); return x,y"), (930, 392))

    def test_debug_status(self):
        env = boot(db={"pinTargets": "below"})
        place_card(env)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        self.assertIn("below", env.run("return OXPFUI_NAMESPACE.TargetsDock.Status()"))


class CardWidth(unittest.TestCase):
    def test_width_matched_through_openxps_grip(self):
        env = Env(openxp2=True, flareui=True, db={"matchTrackerWidth": True})
        env.boot()
        tw = env.run("return FlareUI_ObjectiveTracker:GetWidth()")
        self.assertNotEqual(tw, 330)
        self.assertEqual(env.run("return HARNESS.OXP2.width"), tw)   # OpenXP's own saved width
        env.run("HARNESS.OXP2.Refresh()")                            # and it keeps it
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), tw)
        self.assertIn("matched", env.run("return OXPFUI_NAMESPACE.Dock.Status()"))

    def test_locked_frames_leave_the_width(self):
        env = Env(openxp2=True, flareui=True, db={"matchTrackerWidth": True}, load_addon=False)
        env.run("HARNESS.OXP2.locked = true")
        env.load_addon()
        env.boot()
        self.assertEqual(env.run("return HARNESS.OXP2.width"), 330)
        self.assertNotIn("matched", env.run("return OXPFUI_NAMESPACE.Dock.Status()"))


class Popups(unittest.TestCase):
    def test_menu_gets_the_popup_window(self):
        env = boot()
        env.run("local m = HARNESS.OXP2.bar.menu; m:GetScript('OnClick')(m)")
        self.assertNotIn("WHITE8X8", env.run("return OpenXPMenu:GetBackdrop().edgeFile"))


class Dock(unittest.TestCase):
    def test_card_docks_under_flareui_tracker(self):
        env = Env(openxp2=True, flareui=True)
        env.boot()
        self.assertTrue(env.run("return OXPFUI_NAMESPACE.Dock.IsActive()"))
        self.assertTrue(env.run("local _, rel = OpenXPCard:GetPoint(1); "
                                "return rel == FlareUI_ObjectiveTracker"))


if __name__ == "__main__":
    unittest.main()
