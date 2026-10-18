class_name AlienRaceData
extends Resource

@export var race_id: StringName
@export var display_name: String
@export var language: GleepGlorpLanguages.Language

@export var default_glyph_fonts: Array[Font] = []
@export var default_voice_clips: Array[AudioStream] = []

@export var target_frequency := 100.0
@export var frequency_variance := 5.0
@export var target_amplitude := 0.5
@export var amplitude_variance := 0.1
@export var default_connection_buffer := 2.0

@export var cassette_id: StringName
