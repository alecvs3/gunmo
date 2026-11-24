class_name PlayerNetState
extends NetState
## What clients need about a player: where it is and how it is moving (also everything the
## owner's prediction rewinds to), weapon timers, health, the last command the host ran, its
## loadout and credits, its team and its score.

const FLAG_ALIVE: int = 1
const FLAG_PROTECTED: int = 2
## 3 vectors (24) + f64 aim + u16 health + u16 ammo + 2 x f64 timers + u8 flags + u8 teleports
## + u32 last command + u8 weapon index + u32 credits + 16 upgrade levels + i32 team
## + 2 x u16 kills/deaths + 2 x u8 tier/tier kills + u16 max health + 2 x u8 downed
## + 2 x u8 pet.
const SIZE: int = 95
## The public form, for everyone but the player's owner: f32 position + f32 aim + u16 health
## + u16 max health + u8 flags + u8 teleports + u8 weapon + i32 team + 2 x u16 + 2 x u8 score
## + 2 x u8 downed + 2 x u8 pet. Not sent to others: velocities, ammo, weapon timers, last
## command, credits, upgrades.
const PUBLIC_SIZE: int = 33

var position: Vector2 = Vector2.ZERO
var move_velocity: Vector2 = Vector2.ZERO
var knockback: Vector2 = Vector2.ZERO
var aim: float = 0.0
var health: int = 0
## Max health with upgrades (others can't work it out: they don't get the upgrade levels).
var max_health: int = 0
var ammo: int = 0
var cooldown_left: float = 0.0
var reload_left: float = 0.0
var alive: bool = true
## Spawn protection: can't be damaged.
var protected: bool = false
## Bumped on every teleport (respawn) so receivers snap instead of sliding across the map.
var teleport_count: int = 0
## Sequence of the last input command the host simulated (-1 = none yet).
var last_command: int = -1
## Index into the ShopCatalog's weapons.
var weapon_index: int = 0
var credits: int = 0
## One byte per catalog upgrade (ShopCatalog.MAX_UPGRADES).
var upgrade_levels := PackedByteArray()
## 0 = the co-op team; otherwise a team of its own (HitboxComponent.team_for).
var team_id: int = 0
var kills: int = 0
var deaths: int = 0
var tier: int = 0
var tier_kills: int = 0
## Co-op downed: bleed-out time left as a share (1..255; 0 = not downed), and how full a
## teammate's revive is (0..255).
var down_left: int = 0
var revive_progress: int = 0
## Waves: the pet (PetCatalog index + 1, 0 = none) and its tier (everyone sees your pet).
var pet: int = 0
var pet_tier: int = 0


func _init() -> void:
	upgrade_levels.resize(ShopCatalog.MAX_UPGRADES)


func encode(buffer: StreamPeerBuffer) -> void:
	NetCodec.put_vector2(buffer, position)
	NetCodec.put_vector2(buffer, move_velocity)
	NetCodec.put_vector2(buffer, knockback)
	buffer.put_double(aim)
	buffer.put_u16(clampi(health, 0, 65535))
	buffer.put_u16(clampi(ammo, 0, 65535))
	buffer.put_double(cooldown_left)
	buffer.put_double(reload_left)
	buffer.put_u8((FLAG_ALIVE if alive else 0) | (FLAG_PROTECTED if protected else 0))
	buffer.put_u8(teleport_count & 0xFF)
	buffer.put_u32(last_command + 1)
	buffer.put_u8(clampi(weapon_index, 0, 255))
	buffer.put_u32(maxi(credits, 0))
	var fixed: PackedByteArray = upgrade_levels.duplicate()
	fixed.resize(ShopCatalog.MAX_UPGRADES)
	buffer.put_data(fixed)
	buffer.put_32(team_id)
	buffer.put_u16(clampi(kills, 0, 65535))
	buffer.put_u16(clampi(deaths, 0, 65535))
	buffer.put_u8(clampi(tier, 0, 255))
	buffer.put_u8(clampi(tier_kills, 0, 255))
	buffer.put_u16(clampi(max_health, 0, 65535))
	buffer.put_u8(clampi(down_left, 0, 255))
	buffer.put_u8(clampi(revive_progress, 0, 255))
	buffer.put_u8(clampi(pet, 0, 255))
	buffer.put_u8(clampi(pet_tier, 0, 255))


func decode(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_vector2(buffer)
	move_velocity = NetCodec.get_vector2(buffer)
	knockback = NetCodec.get_vector2(buffer)
	aim = buffer.get_double()
	health = buffer.get_u16()
	ammo = buffer.get_u16()
	cooldown_left = buffer.get_double()
	reload_left = buffer.get_double()
	var flags: int = buffer.get_u8()
	alive = flags & FLAG_ALIVE != 0
	protected = flags & FLAG_PROTECTED != 0
	teleport_count = buffer.get_u8()
	last_command = buffer.get_u32() - 1
	weapon_index = buffer.get_u8()
	credits = buffer.get_u32()
	upgrade_levels = buffer.get_data(ShopCatalog.MAX_UPGRADES)[1]
	team_id = buffer.get_32()
	kills = buffer.get_u16()
	deaths = buffer.get_u16()
	tier = buffer.get_u8()
	tier_kills = buffer.get_u8()
	max_health = buffer.get_u16()
	down_left = buffer.get_u8()
	revive_progress = buffer.get_u8()
	pet = buffer.get_u8()
	pet_tier = buffer.get_u8()


func byte_size() -> int:
	return SIZE


func encode_public(buffer: StreamPeerBuffer) -> void:
	NetCodec.put_vector2(buffer, position)
	buffer.put_float(aim)
	buffer.put_u16(clampi(health, 0, 65535))
	buffer.put_u16(clampi(max_health, 0, 65535))
	buffer.put_u8((FLAG_ALIVE if alive else 0) | (FLAG_PROTECTED if protected else 0))
	buffer.put_u8(teleport_count & 0xFF)
	buffer.put_u8(clampi(weapon_index, 0, 255))
	buffer.put_32(team_id)
	buffer.put_u16(clampi(kills, 0, 65535))
	buffer.put_u16(clampi(deaths, 0, 65535))
	buffer.put_u8(clampi(tier, 0, 255))
	buffer.put_u8(clampi(tier_kills, 0, 255))
	buffer.put_u8(clampi(down_left, 0, 255))
	buffer.put_u8(clampi(revive_progress, 0, 255))
	buffer.put_u8(clampi(pet, 0, 255))
	buffer.put_u8(clampi(pet_tier, 0, 255))


func decode_public(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_vector2(buffer)
	aim = buffer.get_float()
	health = buffer.get_u16()
	max_health = buffer.get_u16()
	var flags: int = buffer.get_u8()
	alive = flags & FLAG_ALIVE != 0
	protected = flags & FLAG_PROTECTED != 0
	teleport_count = buffer.get_u8()
	weapon_index = buffer.get_u8()
	team_id = buffer.get_32()
	kills = buffer.get_u16()
	deaths = buffer.get_u16()
	tier = buffer.get_u8()
	tier_kills = buffer.get_u8()
	down_left = buffer.get_u8()
	revive_progress = buffer.get_u8()
	pet = buffer.get_u8()
	pet_tier = buffer.get_u8()


func public_byte_size() -> int:
	return PUBLIC_SIZE


## Position and aim blend; everything else comes from the nearer state. Across a teleport
## nothing blends, so the player jumps instead of sliding.
func interpolated(to: NetState, weight: float) -> NetState:
	var other := to as PlayerNetState
	if other == null or other.teleport_count != teleport_count:
		return super(to, weight)
	var blended: PlayerNetState = (self if weight < 0.5 else other).copy()
	blended.position = position.lerp(other.position, weight)
	blended.aim = lerp_angle(aim, other.aim, weight)
	return blended


func copy() -> PlayerNetState:
	var duplicate := PlayerNetState.new()
	duplicate.position = position
	duplicate.move_velocity = move_velocity
	duplicate.knockback = knockback
	duplicate.aim = aim
	duplicate.health = health
	duplicate.max_health = max_health
	duplicate.ammo = ammo
	duplicate.cooldown_left = cooldown_left
	duplicate.reload_left = reload_left
	duplicate.alive = alive
	duplicate.protected = protected
	duplicate.teleport_count = teleport_count
	duplicate.last_command = last_command
	duplicate.weapon_index = weapon_index
	duplicate.credits = credits
	duplicate.upgrade_levels = upgrade_levels.duplicate()
	duplicate.team_id = team_id
	duplicate.kills = kills
	duplicate.deaths = deaths
	duplicate.tier = tier
	duplicate.tier_kills = tier_kills
	duplicate.down_left = down_left
	duplicate.revive_progress = revive_progress
	duplicate.pet = pet
	duplicate.pet_tier = pet_tier
	return duplicate
