class_name ExplosiveComponent
extends Node

# Se emite al detonar. 
#`center` está en coordenadas globales,
#`falloff` controla cómo disminuye la fuerza con la distancia y
#`target_height` ajusta el centro usado para medir la distancia a cada jugador.
signal detonated(center: Vector3, radius: float, force: float, falloff: float, target_height: float)

@export var radius: float = 6.0
@export var force: float = 42.0
@export var falloff: float = 2.0
@export var target_height: float = 1.0

func detonate(center: Vector3) -> void:
	detonated.emit(center, radius, force, falloff, target_height)
