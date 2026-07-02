extends Resource
class_name BiomeSpawnTable

# ═══════════════════════════════════════════════════════════════════════════
#  BiomeSpawnTable — таблица существ одного биома
# ───────────────────────────────────────────────────────────────────────────
#  Один .tres на биом, например:
#  res://data/spawn_tables/forest.tres
#  res://data/spawn_tables/desert.tres
#  res://data/spawn_tables/thundra.tres
#  res://data/spawn_tables/deep.tres  (Шахта/Бездна — используй tier-фильтр
#                                       внутри одной таблицы, либо раздели
#                                       на deep_mine.tres / deep_abyss.tres)
# ═══════════════════════════════════════════════════════════════════════════

## Должно совпадать со значением GameManager.biome ("Desert","Forest","Thundra","Deep")
@export_enum("Desert","Forest","Thundra","Deep") var biome: String = "Forest"

@export var entries: Array[CreatureSpawnEntry] = []

## Существ на условную площадь 1000×1000 px зоны. Подбирается на глаз в редакторе
@export var density_per_1000px: float = 1.5

## Жёсткий потолок одновременно живых существ от этой таблицы в одной зоне —
## главный рычаг оптимизации, не даёт зоне-переростку заспавнить сотню мобов
@export var max_concurrent: int = 8


## Взвешенный случайный выбор с учётом тира/подземелья/заражения текущей локации,
## а также текущей фазы дня (DayNightCycle.Phase) и текущей погоды (строка из WeatherSystem).
## tier_cap — ограничение сверху (напр. "безопасная" зона леса не должна давать тир 4).
func pick_random(rng: RandomNumberGenerator, tier_cap: int, corruption: int, is_underground: bool,
		current_phase: int = -1, current_weather: String = "") -> CreatureSpawnEntry:
	var pool: Array[CreatureSpawnEntry] = []
	var total_weight := 0.0

	for e in entries:
		if e.tier > tier_cap:
			continue
		if e.min_corruption > corruption:
			continue
		if e.underground_only and not is_underground:
			continue
		if current_phase >= 0 and not e.can_spawn_in_phase(current_phase):
			continue
		if not current_weather.is_empty() and not e.can_spawn_in_weather(current_weather):
			continue
		pool.append(e)
		total_weight += e.weight

	if pool.is_empty() or total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	var acc := 0.0
	for e in pool:
		acc += e.weight
		if roll <= acc:
			return e
	return pool.back()
