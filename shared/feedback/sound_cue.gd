class_name SoundCue
extends Resource
## One kind of sound: what plays (an AudioStreamRandomizer picks a variant and nudges the
## pitch each time), how loud, and how many may play at once.

@export var stream: AudioStream
@export_range(-40.0, 12.0) var volume_db: float = 0.0
## More at once than this are skipped (an SMG hitting a crowd would otherwise be a wall of noise).
@export_range(1, 32) var max_at_once: int = 4
## World sounds: beyond this distance from the camera it is silent (pixels).
@export_range(100.0, 5000.0) var max_distance: float = 1400.0
## Fade it out and stop after this many seconds (0 = play to the end). Keeps a fast gun's
## shots from piling up, or uses only the first shot of a recorded burst.
@export_range(0.0, 5.0) var max_seconds: float = 0.0
