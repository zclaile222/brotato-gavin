class_name RunEconomy
extends Node

signal materials_changed(materials: int)
signal material_bag_changed(material_bag: int)

var materials: int = 0
var wave_start_materials: int = 0
var material_bag: int = 0

func reset(starting_materials: int = 0):
	materials = max(0, starting_materials)
	wave_start_materials = materials
	material_bag = 0
	materials_changed.emit(materials)
	material_bag_changed.emit(material_bag)

func begin_wave_snapshot():
	wave_start_materials = materials

func gain_materials(amount: int) -> int:
	var gained = max(0, amount)
	materials += gained
	materials_changed.emit(materials)
	return gained

func spend_materials(amount: int) -> bool:
	var cost = max(0, amount)
	if materials < cost:
		return false
	materials -= cost
	materials_changed.emit(materials)
	return true

func add_to_bag(amount: int):
	var gained = max(0, amount)
	material_bag += gained
	material_bag_changed.emit(material_bag)

func consume_bag_for_drop(base_value: int) -> int:
	var value = max(0, base_value)
	if material_bag <= 0:
		return value
	var bag_value = material_bag
	material_bag = 0
	material_bag_changed.emit(material_bag)
	return value + bag_value

func get_wave_material_gain() -> int:
	return materials - wave_start_materials
