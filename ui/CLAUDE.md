# ui/: menus and HUD

Owner: **Yusuf**. Everything here **only shows things and asks for things**. It never decides
gameplay.

## Where the UI gets its data
| Data | From |
|---|---|
| Phase, wave, timers, shop open, winner | EventBus `match_state_changed` (a `MatchNetState`) |
| Your health, ammo, reload, credits | `Player.find_local(tree).hud_stats()` (`Player.HudStats`) |
| Scores | Players' replicated `ScoreComponent`s, through `Scoreboard.ranked_players` (`Scoreboard.Row`) |
| Being hit, ready state, spectating | EventBus `local_player_hurt`, `local_ready_changed`, `spectating_changed` |
| Connection | `NetworkManager` (signals, `stats`, `clock`) |

## Key files
| File | Job |
|---|---|
| `main_menu.gd` | Name, mode (`MODES`), bots, Host / Join |
| `hud.gd`, `gun_game_hud_text.gd` | In-match HUD. Text is built in static functions so it can be tested |
| `scoreboard.gd` | Tab board and the results board, ranked by `Scoreboard.Row.ranks_above` |
| `shop_panel.gd` | Emits EventBus `shop_purchase_requested`; the mode turns it into a request the host checks |
| `results_screen.gd`, `game_menu.gd`, `hurt_indicator.gd`, `net_overlay.gd` (F3) | |
| `fullscreen_check.gd`, `ui_scale_option.gd` | Display choices in both menus (`GameSettings`) |
| `view_mask.gd` | Bars over the world outside the fair view box (`player/fair_view.gd`), under the rest of the UI |

## Rules that aren't obvious
- **Asking for something = an EventBus signal or a mode request.** Never change gameplay state
  from UI code, even on the host.
- **Never check which mode is running** (rule 7). Use `MatchNetState.mode_kind` only to choose
  a layout.
- Put text and formatting in static functions and test them (see `tests/ui/test_hud_text.gd`).
- **Every panel must work from a 768x432 canvas (huge UI scale) to 21:9 and 4:3.** Anchor to
  the window's edges or center, let lists scroll (`ScrollContainer` with expand) instead of fixed
  heights, and run `tests/ui/test_ui_layout.gd`: it lays out every panel at those sizes and fails
  on anything off screen or overlapping. A new panel goes in its `SCENES` list.
- Keep `.tscn` diffs small. Use unique names (`%Name`) for nodes scripts reach.

## Tests
`tests/ui/`. Smoke scenarios C and E check the results screen and scoreboard over the network.
