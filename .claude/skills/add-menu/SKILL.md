---
name: add-menu
description: Add a pop-up menu over the game (like the Shop, Pets or Path window) that opens with a key and shows a hint in the bottom right. Use when asked to add, create or design an in-match menu, window or panel.
---

# Add a pop-up menu

Area: `ui/` (Yusuf's). Every pop-up menu extends `HudMenu` (`ui/hud_menu.gd`), so they all look
the same and only one is open at a time. Never build a menu's own hint, dim or window style.

1. **Input action:** add one for the key in Project Settings → Input Map (it lives in
   `project.godot`, so ask before editing it). Pick a key no other menu uses.
2. **Script `ui/<name>_panel.gd`:** `class_name <Name>Panel`, `extends HudMenu`. Override:
   - `_action()`: the input action (`&"pets"`).
   - `_hint_text()`: `"<Key>: <Name>"`, like `"P: Pets"`.
   - `_hint_slot()`: the next free number (Shop 0, Pets 1, Path 2, ...): the hint's line in the
     bottom-right stack, counted up from the corner.
   - `_build_content(into)`: add the window's content to `into`. Use `HudMenu.label()`,
     `HudMenu.box()`, `GOLD` and `MUTED` so text and buttons match the other menus. Start with a
     header (title 24 px white, your currency 20 px gold) and end with a 12 px muted footer
     ("<Key> or Esc to close · ...").
   - `_refresh(player)`: show the local player's replicated state (called every frame while open).
   - Optional: `_on_opened(player)`, or `_make_window()` when the content is laid out in the
     `.tscn` under a `PanelContainer` (see `ui/shop_panel.gd`).
   The base handles the hint, the dim, the window, opening with the key, closing with the key,
   Esc or a click outside, sounds, closing when a new phase starts and closing the other menus.
3. **Scene `ui/<name>_panel.tscn`:** a full-rect `Control` with the script. Instance it under
   `UI` in `main.tscn`, next to `ShopPanel`, `PetPanel` and `PathPanel` (both developers review
   `main.tscn`).
4. **Asking for things:** buttons only emit an EventBus signal or a mode request; the host checks
   it (recipe `add-client-request`). Never change gameplay state from the menu.
5. **Tests:**
   - Add the scene to `SCENES` in `tests/ui/test_ui_layout.gd` (it must fit from 768x432 to 21:9).
   - Add the file to `KNOWN` in `tests/ui/test_hud_menus.gd`. That test already checks every
     menu in `ui/` for the same hint and window look, a free hint slot, and one menu at a time.
   - Text built in static functions gets its own test (see `tests/ui/test_path_text.gd`).
6. **Guides:** add the files to the table in `ui/CLAUDE.md`.
