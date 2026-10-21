@tool
extends VoxelGeneratorScript

# --- Настройки рельефа ---
var plain_height: float = 20.0          # базовая высота равнины
var seed_world: int = 0

# Сам объект шума
var noise_plato := FastNoiseLite.new()
var noise_messa := FastNoiseLite.new()
var noise_canyon := FastNoiseLite.new()
var noise_canyon_h := FastNoiseLite.new()

func _init() -> void:
	#Плато/Равнина
	noise_plato.seed = seed_world                    # сид — от него зависит весь рисунок шума
	noise_plato.noise_type = FastNoiseLite.TYPE_PERLIN   # тип шума
	noise_plato.frequency = 0.01               # частота (насколько "крупный" рельеф)
	noise_plato.fractal_octaves = 3             # сколько слоёв деталей
	noise_plato.fractal_gain = 0.5              # сила каждого следующего слоя
	
	#Месса
	noise_messa.seed = seed_world + 1                    # сид — от него зависит весь рисунок шума
	noise_messa.noise_type = FastNoiseLite.TYPE_VALUE   # тип шума
	noise_messa.frequency = 0.005               # частота гор
	noise_messa.fractal_octaves = 8             # сколько слоёв деталей
	noise_messa.fractal_gain = 0.5              # сила каждого следующего слоя
	noise_messa.fractal_lacunarity = 2
	
	#Каньон
	noise_canyon.seed = seed_world + 2                    # сид — от него зависит весь рисунок шума
	noise_canyon.noise_type = FastNoiseLite.TYPE_SIMPLEX   # тип шума
	noise_canyon.frequency = 0.0005               # частота каньона
	noise_canyon.fractal_octaves = 5             # сколько слоёв деталей
	noise_canyon.fractal_gain = 0.5              # сила каждого следующего слоя
	noise_canyon.fractal_lacunarity = 2

	noise_canyon_h.seed = seed_world + 3                    # сид — от него зависит весь рисунок шума
	noise_canyon_h.noise_type = FastNoiseLite.TYPE_SIMPLEX   # тип шума
	noise_canyon_h.frequency = 0.0005               # частота каньона
	noise_canyon_h.fractal_octaves = 5             # сколько слоёв деталей
	noise_canyon_h.fractal_gain = 0.5              # сила каждого следующего слоя
	noise_canyon_h.fractal_lacunarity = 2


#region подготовка для создания карты
# Канал, который мы заполняем (SDF = smooth-террейн)
const CHANNEL := VoxelBuffer.CHANNEL_SDF


func _get_used_channels_mask() -> int:
	# Говорим движку: «я работаю только с SDF»
	return 1 << CHANNEL


func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	var size := out_buffer.get_size()
	var step := 1 << lod   # на lod 0 = 1, на lod 1 = 2 и т.д.

	for lz in size.z:
		for lx in size.x:
			# Переводим локальные координаты буфера → мировые
			var world_x := origin_in_voxels.x + (lx << lod)
			var world_z := origin_in_voxels.z + (lz << lod)
#endregion
			# Самая простая формула поверхности:
			# ниже plain_height → земля (отрицательный SDF)
			# выше → воздух (положительный SDF)
			var value_plato := noise_plato.get_noise_2d(world_x, world_z)
			var value_messa := noise_messa.get_noise_2d(world_x, world_z)
			var value_canyon := noise_canyon.get_noise_2d(world_x, world_z)
			var value_canyon_h := noise_canyon_h.get_noise_2d(world_x, world_z) * 1.2
			
			# Превращаем его в высоту
			var hill_amplitude: float = 6.0 # насколько сильно холмы могут подниматься/опускаться
			var a := 5 # коефицент роста месс
			var b := 75 # коефицент глубины каньонов
			
			value_plato = plain_height + value_plato * hill_amplitude
			value_messa = (smoothstep(0.3, 0.6, value_messa) * a * value_plato)
			value_canyon = pow(1.0 - abs(value_canyon), 2)
			value_canyon = smoothstep(0.7, 0.95, value_canyon * (0.7 + 0.3 * value_canyon_h)) * b
			var height := value_messa + value_plato - value_canyon
			
			for ly in size.y:
				var world_y := origin_in_voxels.y + (ly << lod)
				var sdf := float(world_y) - height
				out_buffer.set_voxel_f(sdf, lx, ly, lz, CHANNEL)
