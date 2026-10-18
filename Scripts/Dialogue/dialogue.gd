class_name Dialogue
extends Node


func msg(text: String, message_id: StringName = &"") -> AlienDialogueMessage:
    return AlienDialogueMessage.new(text, message_id)


func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout


func show(module: ShipModule) -> void:
    print("showing ui for %s" % module.module_name)


func show_idle() -> void:
    print("showing idle ui")


func anim(
    animation_player: AnimationPlayer,
    animation_name: StringName
) -> void:
    animation_player.play(animation_name)
    await animation_player.animation_finished


func sound(
    audio_player: AudioStreamPlayer,
    stream: AudioStream
) -> void:
    audio_player.stream = stream
    audio_player.play()
    await audio_player.finished


