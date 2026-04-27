extends Node
class_name music_library

@onready var music : BlazeMusicManager = %MusicManager  # поправь путь если нужно

func _ready() -> void:
	music.tracks = {
		"MainMenu":{
			"day": [preload("uid://cpju3p3nuruiu")],
			"night" :[preload("uid://cpju3p3nuruiu")]
		},
		"World":{
			"day" : [preload("uid://cthwe46akh770")],
			"night" : [preload("uid://cthwe46akh770")]
		},
		"Cave":{
			"day" : [preload("uid://0ohv8i6n22x3"), 
			preload("uid://cyvu01nuufhrw"), 
			preload("uid://8ls8cyhg4ovm"), 
			preload("uid://di3l1gwt08k6j"), 
			preload("uid://ck7uwgki5a1yg"), 
			preload("uid://dtvl24hfe48py")],
			"night" : [preload("uid://0ohv8i6n22x3"), 
			preload("uid://cyvu01nuufhrw"), 
			preload("uid://8ls8cyhg4ovm"), 
			preload("uid://di3l1gwt08k6j"), 
			preload("uid://ck7uwgki5a1yg"), 
			preload("uid://dtvl24hfe48py")]
		}
		# Новая локация — просто копируй блок:
		# "Desert": {
		#     "day":   [preload("res://audio/music/desert_day.mp3")],
		#     "night": [preload("res://audio/music/desert_night.mp3")]
		# },
	}
