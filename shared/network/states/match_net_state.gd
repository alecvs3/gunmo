class_name MatchNetState
extends NetState
## The match as every peer sees it: which mode, the phase, the wave, when the current phase
## ends, how many enemies are left, how many players are in, alive and ready, whether the
## shop is open, the Gun Game ladder's shape and who won. Phase values are GameMode.Phase.
## Clients always use the newest one (no interpolation).

## Which layout the HUD, scoreboard and results screen use.
enum ModeKind { WAVES, GUN_GAME }

const FLAG_SHOP_OPEN: int = 1
const FLAG_CALL_OPEN: int = 2
const FLAG_FORECAST: int = 1
const FLAG_FORECAST_BOSS: int = 2
## Waves: axis scores the forecast carries (DifficultyModel's five axes; adding an axis changes
## the network format).
const FORECAST_AXES: int = 5
## u8 mode + 3 x u8 + f64 + u16 + 3 x u8 + u8 modifier mask + u8 flags + i32 winner
## + 3 x u8 ladder + u8 call votes + forecast (u8 flags + u8 modifier mask + 5 x u8 scores).
const SIZE: int = 34

var mode_kind: int = ModeKind.WAVES
var phase: int = 0
var wave: int = 0
var total_waves: int = 0
## Host tick the current phase ends on (-1 = no timer running).
var phase_end_tick: float = -1.0
var enemies_left: int = 0
var ready_count: int = 0
var player_count: int = 0
var living_count: int = 0
## The current wave's modifiers (bit i = ModifierCatalog index i).
var modifier_mask: int = 0
var shop_open: bool = false
## Waves: the next wave may be called early now, and how many have voted for it.
var call_open: bool = false
var call_votes: int = 0
## Waves, in the lobby and breaks: the next wave (WaveForecast), when `forecast` is set.
var forecast: bool = false
var forecast_boss: bool = false
var forecast_modifier_mask: int = 0
## One byte per axis (WaveForecast.to_byte).
var forecast_scores := PackedByteArray()
## Gun Game: the player who finished the ladder (0 = nobody yet).
var winner_id: int = 0
## Gun Game: how many guns the ladder has, kills needed per gun, and on the last gun.
var ladder_length: int = 0
var kills_per_tier: int = 0
var final_tier_kills: int = 0


func _init() -> void:
	forecast_scores.resize(FORECAST_AXES)


func encode(buffer: StreamPeerBuffer) -> void:
	buffer.put_u8(mode_kind)
	buffer.put_u8(phase)
	buffer.put_u8(clampi(wave, 0, 255))
	buffer.put_u8(clampi(total_waves, 0, 255))
	buffer.put_double(phase_end_tick)
	buffer.put_u16(clampi(enemies_left, 0, 65535))
	buffer.put_u8(clampi(ready_count, 0, 255))
	buffer.put_u8(clampi(player_count, 0, 255))
	buffer.put_u8(clampi(living_count, 0, 255))
	buffer.put_u8(modifier_mask & 0xFF)
	buffer.put_u8((FLAG_SHOP_OPEN if shop_open else 0) | (FLAG_CALL_OPEN if call_open else 0))
	buffer.put_32(winner_id)
	buffer.put_u8(clampi(ladder_length, 0, 255))
	buffer.put_u8(clampi(kills_per_tier, 0, 255))
	buffer.put_u8(clampi(final_tier_kills, 0, 255))
	buffer.put_u8(clampi(call_votes, 0, 255))
	buffer.put_u8((FLAG_FORECAST if forecast else 0) | (FLAG_FORECAST_BOSS if forecast_boss else 0))
	buffer.put_u8(forecast_modifier_mask & 0xFF)
	for i in FORECAST_AXES:
		buffer.put_u8(forecast_scores[i] if i < forecast_scores.size() else 0)


func decode(buffer: StreamPeerBuffer) -> void:
	mode_kind = buffer.get_u8()
	phase = buffer.get_u8()
	wave = buffer.get_u8()
	total_waves = buffer.get_u8()
	phase_end_tick = buffer.get_double()
	enemies_left = buffer.get_u16()
	ready_count = buffer.get_u8()
	player_count = buffer.get_u8()
	living_count = buffer.get_u8()
	modifier_mask = buffer.get_u8()
	var flags: int = buffer.get_u8()
	shop_open = flags & FLAG_SHOP_OPEN != 0
	call_open = flags & FLAG_CALL_OPEN != 0
	winner_id = buffer.get_32()
	ladder_length = buffer.get_u8()
	kills_per_tier = buffer.get_u8()
	final_tier_kills = buffer.get_u8()
	call_votes = buffer.get_u8()
	var forecast_flags: int = buffer.get_u8()
	forecast = forecast_flags & FLAG_FORECAST != 0
	forecast_boss = forecast_flags & FLAG_FORECAST_BOSS != 0
	forecast_modifier_mask = buffer.get_u8()
	for i in FORECAST_AXES:
		forecast_scores[i] = buffer.get_u8()


func byte_size() -> int:
	return SIZE


## Waves: the forecast's axis scores back as numbers (WaveForecast.from_byte).
func forecast_axis_scores() -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for value in forecast_scores:
		found.append(WaveForecast.from_byte(value))
	return found


## Waves: carries `next` (or clears the forecast when it is null).
func set_forecast(next: WaveForecast) -> void:
	forecast = next != null
	forecast_boss = next != null and next.boss
	forecast_modifier_mask = next.modifier_mask if next != null else 0
	forecast_scores = PackedByteArray()
	forecast_scores.resize(FORECAST_AXES)
	if next != null:
		for i in mini(next.scores.size(), FORECAST_AXES):
			forecast_scores[i] = WaveForecast.to_byte(next.scores[i])


## Seconds until the phase ends, seen from `now_tick` (-1 when there is no timer).
func seconds_left(now_tick: float) -> float:
	if phase_end_tick < 0.0:
		return -1.0
	return maxf((phase_end_tick - now_tick) * NetClock.tick_delta(), 0.0)


## Gun Game: kills needed to leave `tier` (the last tier needs final_tier_kills).
func kills_needed(tier: int) -> int:
	return final_tier_kills if tier >= ladder_length - 1 else kills_per_tier


func is_over() -> bool:
	return phase == GameMode.Phase.VICTORY or phase == GameMode.Phase.DEFEAT


func equals(other: MatchNetState) -> bool:
	var buffer := StreamPeerBuffer.new()
	encode(buffer)
	var other_buffer := StreamPeerBuffer.new()
	other.encode(other_buffer)
	return buffer.data_array == other_buffer.data_array


func copy() -> MatchNetState:
	var buffer := StreamPeerBuffer.new()
	encode(buffer)
	buffer.seek(0)
	var duplicate := MatchNetState.new()
	duplicate.decode(buffer)
	return duplicate
