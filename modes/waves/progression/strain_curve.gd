class_name StrainCurve
extends Resource
## What the strain should be at each wave, in display units (×10: difficulty and progression
## on 0–100). Strain = how far the wave is above the team (ProgressionRun.strain): below 0
## the team is ahead, above 0 it has to play better than expected. Wave 1 is the easiest and
## the last wave the hardest: a steady line from `first` to `knee_value` at `knee_wave`, then
## the climb keeps that slope and bends upward (`late_power`) to reach `last`, so the late
## waves get harder faster without a sudden step. A wave is on target within `band` either
## way; the room under the top of the band is what later randomness can spend.

@export_range(-100.0, 100.0) var first: float = -30.0
@export_range(1, 255) var knee_wave: int = 16
@export_range(-100.0, 100.0) var knee_value: float = -15.0
@export_range(-100.0, 100.0) var last: float = 20.0
## How the climb bends after the knee: 2 = a parabola, 1 = straight on.
@export_range(1.0, 4.0) var late_power: float = 2.0
@export_range(0.0, 50.0) var band: float = 10.0


func target(wave: int, total_waves: int) -> float:
	var knee: int = clampi(knee_wave, 1, maxi(total_waves, 1))
	var at: int = clampi(wave, 1, maxi(total_waves, 1))
	var slope: float = (knee_value - first) / (knee - 1) if knee > 1 else 0.0
	if at <= knee:
		return first + slope * (at - 1)
	var span: int = total_waves - knee
	var bend: float = (last - knee_value - slope * span) / pow(span, late_power)
	var past: int = at - knee
	return knee_value + slope * past + bend * pow(past, late_power)


## How far `strain` is outside the band (0 = inside; above 0 = too hard, below 0 = too easy).
func miss(strain: float, wave: int, total_waves: int) -> float:
	var gap: float = strain - target(wave, total_waves)
	if absf(gap) <= band:
		return 0.0
	return gap - signf(gap) * band
