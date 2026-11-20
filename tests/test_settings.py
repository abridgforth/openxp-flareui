"""Settings registry, Save + automatic reload, and following FlareUI's style.

User stories:
  * Settings are changed in a Blizzard-style window and saved with Save.
  * Save reloads the UI automatically when — and only when — a changed
    setting needs a reload to show.
  * Engineers declare every setting (with its reload rule) in Settings.lua;
    nothing can be added without that decision.
"""

from __future__ import annotations

import unittest

from harness.env import Env, _lua_literal

FLARE_THICK = "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Thick.tga"


def open_panel(**kw) -> Env:
    env = Env(**kw)
    env.boot()
    env.slash("/oxpfui")
    return env


class Registry(unittest.TestCase):
    def test_every_saved_key_is_declared_with_a_reload_rule(self):
        env = Env()
        env.boot()
        undeclared = env.run("""
          local missing = {}
          local function walk(t, prefix)
            for k, v in pairs(t) do
              local key = prefix and (prefix .. '.' .. k) or k
              if type(v) == 'table' then walk(v, key)
              elseif not OXPFUI.Settings.Get(key) then missing[#missing + 1] = key end
            end
          end
          walk(OXPFUIDB, nil)
          table.sort(missing)
          return table.concat(missing, ',')
        """)
        self.assertEqual(undeclared, "")
        self.assertTrue(env.run("""
          for _, def in ipairs(OXPFUI.Settings.defs) do
            local r = def.reload
            if not (r == true or r == false or type(r) == 'function') then return false end
          end
          return #OXPFUI.Settings.defs > 0
        """))

    def test_a_setting_without_a_reload_rule_is_rejected_at_load(self):
        env = Env()
        ok, err = env.run("""
          return pcall(OXPFUI.Settings.Define,
            { key = 'newFeature', kind = 'toggle', default = true })
        """)
        self.assertIs(ok, False)
        self.assertIn("reload", err)

    def test_defaults_are_unchanged_for_existing_users(self):
        env = Env()
        env.boot()
        for key, value in (("enabled", True), ("font", "Friz Quadrata"), ("opacity", 0.6),
                           ("borderStyle", "Frames"), ("attachTracker", True),
                           ("attachSide", "bottom"), ("attachPadding", 8),
                           ("matchTrackerWidth", False), ("windows.arrow", True),
                           ("windows.tooltips", True)):
            self.assertEqual(env.run(f"return OXPFUI.Settings.Read(OXPFUIDB, {key!r})"), value, key)

    def test_saved_values_are_kept_and_new_keys_are_filled(self):
        env = Env(db={"font": "Fira Condensed", "windows": {"arrow": False}})
        env.boot()
        self.assertEqual(env.run("return OXPFUIDB.font"), "Fira Condensed")
        self.assertEqual(env.run("return OXPFUIDB.windows.arrow"), False)
        self.assertEqual(env.run("return OXPFUIDB.windows.card"), True)
        self.assertEqual(env.run("return OXPFUIDB.followFlareUI"), True)


class AutoReload(unittest.TestCase):
    def test_master_switch_reloads_both_ways(self):
        env = open_panel()
        env.run("OXPFUIPanel.masterBtn:Click(); OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.enabled"), False)
        self.assertEqual(env.run("return HARNESS.reloads"), 1)
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.masterBtn:Click(); OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.enabled"), True)
        self.assertEqual(env.run("return HARNESS.reloads"), 2)

    def test_window_off_reloads_but_on_is_live(self):
        env = open_panel()
        env.run("OXPFUIPanel.windowBtns.arrow:Click(); OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return HARNESS.reloads"), 1)
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.windowBtns.arrow:Click(); OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.windows.arrow"), True)
        self.assertEqual(env.run("return HARNESS.reloads"), 1)

    def test_live_settings_never_reload(self):
        env = open_panel(flareui=True)
        env.run("""
          OXPFUIPanel.followBtn:Click() -- off: unlocks the appearance controls
          HARNESS.PickDropdown(OXPFUIPanel.borderDropdown, 'Thin')
          OXPFUIPanel.windowBtns.tooltips:Click()
          OXPFUIPanel.attachBtn:Click()
          OXPFUIPanel.saveBtn:Click()
        """)
        self.assertEqual(env.run("return OXPFUIDB.borderStyle"), "Thin")
        self.assertEqual(env.run("return HARNESS.reloads"), 0)

    def test_mixed_changes_save_everything_then_reload_once(self):
        env = open_panel()
        env.run("""
          HARNESS.PickDropdown(OXPFUIPanel.fontDropdown, 'Roboto Condensed')
          OXPFUIPanel.windowBtns.card:Click()
          OXPFUIPanel.windowBtns.arrow:Click()
          OXPFUIPanel.saveBtn:Click()
        """)
        self.assertEqual(env.run("return OXPFUIDB.font"), "Roboto Condensed")
        self.assertEqual(env.run("return OXPFUIDB.windows.card"), False)
        self.assertEqual(env.run("return OXPFUIDB.windows.arrow"), False)
        self.assertEqual(env.run("return HARNESS.reloads"), 1)

    def test_panel_says_when_save_will_reload(self):
        env = open_panel()
        L = lambda k: env.run(f"return OXPFUI.L.{k}")  # noqa: E731
        self.assertEqual(env.run("return OXPFUIPanel.saveBtn:GetText()"), L("saveButton"))
        self.assertEqual(env.run("return OXPFUIPanel.reloadNote:IsShown()"), False)
        env.run("OXPFUIPanel.windowBtns.talents:Click()")
        self.assertEqual(env.run("return OXPFUIPanel.saveBtn:GetText()"), L("saveReloadButton"))
        self.assertEqual(env.run("return OXPFUIPanel.reloadNote:IsShown()"), True)
        self.assertIn(env.run("return OXPFUI.L.windows.talents"),
                      env.run("return OXPFUIPanel.reloadNote:GetText()"))
        env.run("OXPFUIPanel.windowBtns.talents:Click()")  # undo
        self.assertEqual(env.run("return OXPFUIPanel.saveBtn:GetText()"), L("saveButton"))
        self.assertEqual(env.run("return OXPFUIPanel.reloadNote:IsShown()"), False)

    def test_cancel_never_reloads(self):
        env = open_panel()
        env.run("OXPFUIPanel.masterBtn:Click(); OXPFUIPanel.cancelBtn:Click()")
        self.assertEqual(env.run("return HARNESS.reloads"), 0)
        self.assertEqual(env.run("return OXPFUIDB.enabled"), True)

    def test_saving_unchanged_settings_does_nothing(self):
        env = Env()
        env.boot()
        changes, reloaded = env.run("""
          local c, r = OXPFUI.Settings.Commit(OXPFUI.Settings.NewDraft())
          return #c, r
        """)
        self.assertEqual((changes, reloaded), (0, False))
        self.assertEqual(env.run("return HARNESS.reloads"), 0)

    def test_new_settings_follow_their_declared_rule(self):
        # The engineer contract: declare reload as a predicate and Commit
        # honours it without any panel or feature-specific code.
        env = Env()
        env.run("""
          OXPFUI.Settings.Define { key = 'experimental.level', kind = 'range',
            default = 1, min = 1, max = 5, step = 1,
            reload = function(old, new) return new > 3 end }
        """)
        env.boot()
        env.run("""
          local d = OXPFUI.Settings.NewDraft(); d['experimental.level'] = 3
          OXPFUI.Settings.Commit(d)
        """)
        self.assertEqual(env.run("return HARNESS.reloads"), 0)
        env.run("""
          local d = OXPFUI.Settings.NewDraft(); d['experimental.level'] = 4
          OXPFUI.Settings.Commit(d)
        """)
        self.assertEqual(env.run("return OXPFUIDB.experimental.level"), 4)
        self.assertEqual(env.run("return HARNESS.reloads"), 1)


class LivePreview(unittest.TestCase):
    """Changes that need no reload show while the user adjusts them."""

    CARD_ALPHA = "local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"

    def test_slider_changes_show_immediately_without_saving(self):
        env = open_panel()
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.25)")
        self.assertEqual(env.run(self.CARD_ALPHA), 0.25)
        env.run("HARNESS.PickDropdown(OXPFUIPanel.borderDropdown, 'Thick')")
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), FLARE_THICK)
        # Nothing saved yet: the SavedVariables table is untouched.
        self.assertEqual(env.run("return OXPFUIDB.opacity"), 0.6)
        self.assertEqual(env.run("return OXPFUIDB.borderStyle"), "Frames")
        self.assertEqual(env.run("return HARNESS.reloads"), 0)

    def test_cancel_close_and_escape_restore_the_saved_look(self):
        for closer in ("OXPFUIPanel.cancelBtn:Click()", "OXPFUIPanel.CloseButton:Click()",
                       "OXPFUIPanel:Hide()"):
            with self.subTest(closer=closer):
                env = open_panel()
                env.run("OXPFUIPanel.opacitySlider:SetValue(0.25)")
                env.run(closer)
                self.assertEqual(env.run(self.CARD_ALPHA), 0.6)
                self.assertEqual(env.run("return OXPFUI.db == OXPFUIDB"), True)

    def test_save_keeps_the_previewed_look(self):
        env = open_panel()
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.25)")
        env.run("OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.opacity"), 0.25)
        self.assertEqual(env.run(self.CARD_ALPHA), 0.25)
        self.assertEqual(env.run("return OXPFUI.db == OXPFUIDB"), True)
        self.assertEqual(env.run("return HARNESS.reloads"), 0)

    def test_dock_changes_move_the_card_live(self):
        env = Env(flareui=True)
        env.boot()
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.matchBtn:Click()")
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 250)
        self.assertEqual(env.run("return OXPFUIDB.matchTrackerWidth"), False)

    def test_reload_settings_are_not_previewed(self):
        env = open_panel()
        env.run("OXPFUIPanel.windowBtns.card:Click()")  # off: needs a reload
        self.assertEqual(env.run("return OXPFUI.db.windows.card"), True)
        self.assertEqual(env.run("return OXPFUI.Settings.IsPreviewing()"), False)
        env.run("OXPFUIPanel.masterBtn:Click()")
        self.assertEqual(env.run("return OXPFUI.db.enabled"), True)

    def test_undoing_the_last_live_change_ends_the_preview(self):
        env = open_panel()
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.25)")
        self.assertEqual(env.run("return OXPFUI.Settings.IsPreviewing()"), True)
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.6)")
        self.assertEqual(env.run("return OXPFUI.Settings.IsPreviewing()"), False)
        self.assertEqual(env.run(self.CARD_ALPHA), 0.6)

    def test_mixed_save_writes_previewed_and_reload_settings_then_reloads(self):
        env = open_panel()
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.25)")
        env.run("OXPFUIPanel.windowBtns.card:Click()")
        env.run("OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.opacity"), 0.25)
        self.assertEqual(env.run("return OXPFUIDB.windows.card"), False)
        self.assertEqual(env.run("return HARNESS.reloads"), 1)


def flare_env(tracker=None, follow=True, font_path=None, player="Smiter Sogood") -> Env:
    """Env with FlareUI installed and a saved FlareUI2_DB like a real one."""
    env = Env(flareui=True, load_addon=False, db={"followFlareUI": follow})
    # Default: this user's saved FlareUI tracker (Blizzard frame style).
    ot = tracker if tracker is not None else {"frameStyle": "blizzard", "opacity": 0,
                                               "borderTexture": "None", "width": 270}
    env.run(f"HARNESS.units.player = {{ name = {player!r} }}")
    env.run("FlareUI2_DB = { profileKeys = { ['Smiter Sogood'] = 'Default', ['Stabyo Az'] = 'Default' },"
            " profiles = { Default = { objectivetracker = {} } } }")
    for k, v in ot.items():
        env.run(f"FlareUI2_DB.profiles.Default.objectivetracker[{k!r}] = {_lua_literal(v)}")
    if font_path:
        env.run(f"""
          local fs = FlareUI_ObjectiveTracker:CreateFontString(nil, 'OVERLAY')
          fs:SetFont({font_path!r}, 13, '')
        """)
    env.load_addon()
    env.boot()
    return env


class FollowFlareUI(unittest.TestCase):
    def test_card_takes_the_trackers_opacity_and_no_border(self):
        env = flare_env()
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0)
        self.assertIsNone(env.run("return OpenXPCard.backdrop.edgeFile"))

    def test_frame_styles_follow_flareuis_rules(self):
        # FlareUI style: always its Thick border, at the chosen opacity.
        env = flare_env({"frameStyle": "flareui", "opacity": 0.4, "borderTexture": "None"})
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), FLARE_THICK)
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.4)
        # Custom: the chosen border; FlareUI's defaults for what was never changed.
        env2 = flare_env({"frameStyle": "custom", "borderTexture": "FlareUI Thick"})
        self.assertEqual(env2.run("return OpenXPCard.backdrop.edgeFile"), FLARE_THICK)
        self.assertEqual(env2.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.75)
        # Nothing saved at all: FlareUI's defaults (Custom, FlareUI Frames, 75%).
        env3 = flare_env({})
        self.assertIn("FlareUI-Frames.tga", env3.run("return OpenXPCard.backdrop.edgeFile"))
        self.assertEqual(env3.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.75)
        # Unknown border art keeps the OXP-FUI border.
        env4 = flare_env({"frameStyle": "custom", "borderTexture": "Something New"})
        self.assertIn("FlareUI-Frames.tga", env4.run("return OpenXPCard.backdrop.edgeFile"))

    def test_text_uses_the_trackers_font(self):
        env = flare_env(font_path="Fonts\\ARIALN.TTF")
        fonts = env.run("""
          local out = {}
          local function walk(f)
            for _, r in ipairs({f:GetRegions()}) do
              if r:GetObjectType() == 'FontString' and r.__font then out[r.__font[1]] = true end
            end
            for _, c in ipairs({f:GetChildren()}) do walk(c) end
          end
          walk(OpenXPCard)
          local list = {}
          for k in pairs(out) do list[#list + 1] = k end
          table.sort(list)
          return table.concat(list, '|')
        """)
        self.assertEqual(fonts, "Fonts\\ARIALN.TTF")

    def test_switch_off_uses_oxpfui_settings(self):
        env = flare_env(follow=False)
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.6)
        self.assertIn("FlareUI-Frames.tga", env.run("return OpenXPCard.backdrop.edgeFile"))

    def test_toggling_follow_in_the_panel_is_live(self):
        env = flare_env()
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.followBtn:Click(); OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.6)
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.followBtn:Click(); OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0)
        self.assertEqual(env.run("return HARNESS.reloads"), 0)

    def test_appearance_controls_lock_while_following(self):
        env = flare_env()
        env.slash("/oxpfui")
        for w in ("fontDropdown", "borderDropdown", "opacitySlider"):
            self.assertEqual(env.run(f"return OXPFUIPanel.{w}:IsEnabled()"), False, w)
        self.assertEqual(env.run("return OXPFUIPanel.styleNote:GetText()"),
                         env.run("return OXPFUI.L.followActiveNote"))
        env.run("OXPFUIPanel.followBtn:Click()")  # draft only: unlocks at once
        for w in ("fontDropdown", "borderDropdown", "opacitySlider"):
            self.assertEqual(env.run(f"return OXPFUIPanel.{w}:IsEnabled()"), True, w)

    def test_without_flareui_the_switch_changes_nothing(self):
        env = open_panel()  # no FlareUI at all
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.6)
        self.assertEqual(env.run("return OXPFUIPanel.fontDropdown:IsEnabled()"), True)
        self.assertEqual(env.run("return OXPFUIPanel.styleNote:GetText()"),
                         env.run("return OXPFUI.L.flareMissingNote"))

    def test_profile_falls_back_when_the_character_is_not_listed(self):
        env = flare_env(player="Someone Else")  # only one profile in use
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0)

    def test_debug_report_shows_what_was_read(self):
        env = flare_env()
        env.slash("/oxpfui debug")
        chat = "\n".join(env.chat())
        self.assertIn("FlareUI style: on — frame style blizzard, opacity 0%, border None, "
                      "colours blizzard, separators on", chat)

    def test_flareui_saved_variables_are_never_written(self):
        env = flare_env()
        before = env.run("local n = 0; for _ in pairs(FlareUI2_DB.profiles.Default.objectivetracker) do n = n + 1 end; return n")
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.followBtn:Click(); OXPFUIPanel.saveBtn:Click()")
        env.run("OXPFUI.Reapply('test')")
        after = env.run("local n = 0; for _ in pairs(FlareUI2_DB.profiles.Default.objectivetracker) do n = n + 1 end; return n")
        self.assertEqual(before, after)
        self.assertEqual(env.run("return FlareUI2_DB.profiles.Default.objectivetracker.opacity"), 0)


GOLD = (1.0, 0.82, 0.0, 1.0)
BRONZE4 = (0.8, 0.6, 0.34, 1.0)
BRONZE5 = (0.85, 0.68, 0.47, 1.0)


def text_color(env, expr):
    return tuple(round(v, 2) for v in env.run(f"local r,g,b,a = {expr}:GetTextColor(); return r,g,b,a"))


class ColourSchemes(unittest.TestCase):
    ZONE = "HARNESS.openxp.card.header.zone"

    def _zone_expr(self, env):
        return "OXPFUI_ZONE"

    def setUp(self):
        self.find_zone = """
          for _, c in ipairs({OpenXPCard:GetChildren()}) do
            if c.step and c.dot then OXPFUI_ZONE = c.zone; OXPFUI_DOT = c.dot end
          end
        """

    def test_blizzard_style_uses_blizzards_gold(self):
        env = flare_env()
        env.run(self.find_zone)
        self.assertEqual(text_color(env, "OXPFUI_ZONE"), GOLD)

    def test_flareui_scheme_uses_the_bronze_palette(self):
        env = flare_env({"frameStyle": "flareui"})
        env.run(self.find_zone)
        self.assertEqual(text_color(env, "OXPFUI_ZONE"), BRONZE5)
        # Objectives in FlareUI's softer tone of Blizzard's 0.85 grey.
        r, g, b = env.run("return OXPFUI.theme.C.OBJECTIVE[1], OXPFUI.theme.C.OBJECTIVE[2], OXPFUI.theme.C.OBJECTIVE[3]")
        self.assertAlmostEqual(r, 0.85 * 0.75 + 0.85 * 0.25)
        self.assertAlmostEqual(b, 0.85 * 0.75 + 0.50 * 0.25)

    def test_custom_style_can_choose_blizzard_colours(self):
        env = flare_env({"frameStyle": "custom", "colorScheme": "blizzard"})
        env.run(self.find_zone)
        self.assertEqual(text_color(env, "OXPFUI_ZONE"), GOLD)

    def test_not_following_keeps_oxpfui_colours(self):
        env = flare_env(follow=False)
        env.run(self.find_zone)
        self.assertEqual(text_color(env, "OXPFUI_ZONE"), BRONZE4)

    def test_switching_follow_off_restores_colours_live(self):
        env = flare_env()
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.followBtn:Click()")
        env.run(self.find_zone)
        self.assertEqual(text_color(env, "OXPFUI_ZONE"), BRONZE4)
        env.run("OXPFUIPanel.cancelBtn:Click()")
        self.assertEqual(text_color(env, "OXPFUI_ZONE"), GOLD)

    def test_accent_chrome_stays_bronze_in_every_scheme(self):
        env = flare_env()
        env.run(self.find_zone)
        self.assertEqual(tuple(round(v, 2) for v in env.run(
            "local r,g,b,a = OXPFUI_DOT:GetVertexColor(); return r,g,b,a")), BRONZE4)

    def test_text_sizes_follow_the_tracker_fonts(self):
        env = flare_env({"frameStyle": "blizzard", "headerFont": {"size": 15},
                         "titleFont": {"size": 13}})
        env.run(self.find_zone)
        self.assertEqual(env.run("local _, s = OXPFUI_ZONE:GetFont(); return s"), 15)
        env2 = flare_env()
        env2.run(self.find_zone)
        self.assertEqual(env2.run("local _, s = OXPFUI_ZONE:GetFont(); return s"), 12)


def strip_shown(env, host_expr, key):
    return env.run(f"""
      local host = {host_expr}
      local band = host.oxpfuiBands and host.oxpfuiBands[{key!r}]
      local s = band and band.oxpfuiStrip
      return s ~= nil and s.L:IsShown() and s.M:IsShown() and s.R:IsShown()
    """)


class Separators(unittest.TestCase):
    TITLE_ART = "ui-questtracker-primary-objective-header"

    def _card_parts(self, env):
        env.run("""
          for _, c in ipairs({OpenXPCard:GetChildren()}) do
            if c.label and c.lines and c.sep then OXPFUI_UPNEXT = c end
          end
          OXPFUI_HIST = HARNESS.openxp.card.hist
        """)

    def test_borderless_blizzard_style_draws_header_and_section_strips(self):
        env = flare_env()
        self._card_parts(env)
        self.assertIs(strip_shown(env, "OpenXPCard", "title"), True)
        self.assertIs(strip_shown(env, "OXPFUI_UPNEXT", "upnext"), True)
        self.assertIs(strip_shown(env, "OXPFUI_HIST", "history"), True)
        # No border to sit on: no bottom strip; OpenXP's own divider steps aside.
        self.assertIs(strip_shown(env, "OpenXPCard", "foot"), False)
        self.assertEqual(env.run("return OpenXPCard.oxpfuiDivider:IsShown()"), False)
        self.assertEqual(env.run("return OXPFUI_UPNEXT.sep:GetAlpha()"), 0)
        self.assertEqual(env.run("return OpenXPCard.oxpfuiBands.title.oxpfuiStrip.L:GetTexture()"),
                         "Interface\\QuestFrame\\ObjectiveTracker")

    def test_bordered_flareui_style_adds_the_bottom_strip(self):
        env = flare_env({"frameStyle": "flareui"})
        self.assertIs(strip_shown(env, "OpenXPCard", "title"), True)
        self.assertIs(strip_shown(env, "OpenXPCard", "foot"), True)

    def test_custom_style_has_no_strips(self):
        env = flare_env({"frameStyle": "custom"})
        self._card_parts(env)
        self.assertIs(strip_shown(env, "OpenXPCard", "title"), False)
        self.assertIs(strip_shown(env, "OXPFUI_UPNEXT", "upnext"), False)
        self.assertEqual(env.run("return OpenXPCard.oxpfuiDivider:IsShown()"), True)
        self.assertEqual(env.run("return OXPFUI_UPNEXT.sep:GetAlpha()"), 1)

    def test_own_setting_when_not_following(self):
        env = flare_env(follow=False)
        self.assertIs(strip_shown(env, "OpenXPCard", "title"), True)  # default on
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.separatorsBtn:Click()")  # live preview
        self.assertIs(strip_shown(env, "OpenXPCard", "title"), False)
        env.run("OXPFUIPanel.saveBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.separators"), False)
        self.assertEqual(env.run("return HARNESS.reloads"), 0)

    def test_separator_switch_locks_while_following(self):
        env = flare_env()
        env.slash("/oxpfui")
        self.assertEqual(env.run("return OXPFUIPanel.separatorsBtn:IsEnabled()"), False)

    def test_strips_are_skipped_quietly_without_atlas_info(self):
        env = Env(flareui=True, load_addon=False, db={"followFlareUI": False})
        env.run("HARNESS.atlases = {}")
        env.load_addon()
        env.boot()
        self.assertIs(strip_shown(env, "OpenXPCard", "title"), False)
        self.assertEqual(env.run("return OpenXPCard.oxpfuiDivider:IsShown()"), True)
        self.assertEqual(env.chat(), [])

    def test_strips_never_move_openxp_frames(self):
        env = flare_env({"frameStyle": "flareui"})
        for frame in ("OpenXPCard",):
            for m in ("SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight"):
                before = env.calls_made_on(frame, m)
                env.run("OXPFUI.Reapply('test')")
                self.assertEqual(env.calls_made_on(frame, m), before, m)


if __name__ == "__main__":
    unittest.main()
