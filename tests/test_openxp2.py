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


class QuestTargets(unittest.TestCase):
    def test_rows_under_the_strip_and_box_taller(self):
        env = boot(db={"frameStyle": "flareui"})
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
        env = boot()
        env.set_combat(True)
        env.run("OXPFUI_NAMESPACE.Reapply('t')")
        env.set_combat(False)
        env.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.run("local _,_,_,_,y = OpenXPTargetButton:GetPoint(1); return y"), -32)


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
