class_name GameDialogues
extends Dialogue

var gleep_race: AlienRaceData = preload(
    "res://Resources/Comms/Races/gleep_glorp.tres"
)


func gleep(
    text: String,
    message_id: StringName = &""
) -> AlienDialogueMessage:
    return msg(text, message_id).from(gleep_race)


func demo_gleep_call(comms_in: CommsInModule) -> void:
    await (
        gleep(
            "HELLO I AM GLEEP GLORP AND I WANT YOU TO SUBMIT",
            &"demo_gleep_call"
        )
        .buffer(1.0)
        .duration(4.0)
        .send(comms_in)
    )
