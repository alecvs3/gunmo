class_name MatchNetState
extends NetState
## The match as every peer sees it: the phase, the wave, when the current phase ends, how many
## enemies are left, and how many players are in, alive and ready. Phase values are
## GameMode.Phase. Clients always use the newest one (no interpolation).

## 3 x u8 + f64 + u16 + 3 x u8 + u8 modifier mask.
const SIZE: int = 17

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


func encode(buffer: StreamPeerBuffer) -> void:
	buffer.put_u8(phase)
	buffer.put_u8(clampi(wave, 0, 255))
	buffer.put_u8(clampi(total_waves, 0, 255))
	buffer.put_double(phase_end_tick)
	buffer.put_u16(clampi(enemies_left, 0, 65535))
	buffer.put_u8(clampi(ready_count, 0, 255))
	buffer.put_u8(clampi(player_count, 0, 255))
	buffer.put_u8(clampi(living_count, 0, 255))
	buffer.put_u8(modifier_mask & 0xFF)


func decode(buffer: StreamPeerBuffer) -> void:
	phase = buffer.get_u8()
	wave = buffer.get_u8()
	total_waves = buffer.get_u8()
	phase_end_tick = buffer.get_double()
	enemies_left = buffer.get_u16()
	ready_count = buffer.get_u8()
	player_count = buffer.get_u8()
	living_count = buffer.get_u8()
	modifier_mask = buffer.get_u8()


func byte_size() -> int:
	return SIZE


## Seconds until the phase ends, seen from `now_tick` (-1 when there is no timer).
func seconds_left(now_tick: float) -> float:
	if phase_end_tick < 0.0:
		return -1.0
	return maxf((phase_end_tick - now_tick) * NetClock.tick_delta(), 0.0)


func equals(other: MatchNetState) -> bool:
	return (
		phase == other.phase
		and wave == other.wave
		and total_waves == other.total_waves
		and phase_end_tick == other.phase_end_tick
		and enemies_left == other.enemies_left
		and ready_count == other.ready_count
		and player_count == other.player_count
		and living_count == other.living_count
		and modifier_mask == other.modifier_mask
	)


func copy() -> MatchNetState:
	var duplicate := MatchNetState.new()
	duplicate.phase = phase
	duplicate.wave = wave
	duplicate.total_waves = total_waves
	duplicate.phase_end_tick = phase_end_tick
	duplicate.enemies_left = enemies_left
	duplicate.ready_count = ready_count
	duplicate.player_count = player_count
	duplicate.living_count = living_count
	duplicate.modifier_mask = modifier_mask
	return duplicate
