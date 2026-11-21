class_name LatencyBudget
extends Resource
## The latency goals, one per stage of the delay chain. The rule: keep every stage as short
## as possible and add delay only where smoothing needs it. Checked by
## tests/shared/network/test_latency_budget.gd (settings and config) and smoke scenario G
## (tests/net/latency.gd, measured). Real values live in shared/network/latency_budget.tres.
## Lower a number when we get faster; never raise one without saying why in the PR.

const DEFAULT_PATH: String = "res://shared/network/latency_budget.tres"

@export_group("Your own player")
## Physics ticks from an input to your own player moving (prediction: should be 1).
@export_range(0, 10) var own_input_response_ticks: int = 0
## Your own player is drawn a tick of motion ahead (PlayerData.draw_ahead).
@export var own_draw_ahead: bool = false

@export_group("Other players and enemies")
## A client draws remote objects (one-way latency + a smoothing buffer) behind the host. The
## latency is the connection's; the buffer is ours. Buffer on a clean connection (ms, p95):
@export_range(0.0, 500.0) var remote_smoothing_clean_ms: float = 0.0
## The buffer with 80 ms ± 10 ms simulated latency and 2% loss (ms, p95).
@export_range(0.0, 1000.0) var remote_smoothing_lagged_ms: float = 0.0
## Smoothness: how often drawing may run out of snapshots (a visible hitch), per minute.
@export_range(0.0, 600.0) var ran_dry_clean_per_minute: float = 0.0
@export_range(0.0, 600.0) var ran_dry_lagged_per_minute: float = 0.0
## How far behind the simulation the host draws everyone but itself (ms).
@export_range(0.0, 200.0) var host_view_delay_ms: float = 0.0

@export_group("Inputs reaching the host")
## Commands the host holds back for a player on a clean connection (p95 over the test).
@export_range(0, 8) var host_input_buffer_clean_ticks: int = 0
## The most the host may ever hold back for a player (NetworkConfig.max_input_buffer_ticks).
@export_range(0, 8) var max_input_buffer_ticks: int = 0


static func load_default() -> LatencyBudget:
	return load(DEFAULT_PATH)
