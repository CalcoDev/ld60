class_name GameDialogues
extends Dialogue

var gleep_race: AlienRaceData = preload(
    "res://Resources/Comms/Races/gleep_glorp.tres"
)
var purple_race: AlienRaceData = preload(
    "res://Resources/Comms/Races/purple_planet.tres"
)
var red_race: AlienRaceData = preload(
    "res://Resources/Comms/Races/red_planet.tres"
)
var orange_race: AlienRaceData = preload(
    "res://Resources/Comms/Races/orange_planet.tres"
)
var edge_race: AlienRaceData = preload(
    "res://Resources/Comms/Races/universe_edge.tres"
)

const EDGE_MESSAGES := [
    "hello traveller. it appears you reached the end of the known universe. there is no restaurant here. maybe try the other side...",
    "Greeting, traveler. nothin here but the edge of the world.. Maybe try another place.",
    "Goodbye traveler. Go anywhere but here for more data,",
    "I'm sorry little one... Goodbye.",
]


func gleep(
    text: String,
    message_id: StringName = &""
) -> AlienDialogueMessage:
    return msg(text, message_id).from(gleep_race)


func blue_planet_intro(comms_in: CommsInModule) -> void:
    await (
        gleep(
            "Greetings fellowest space pilgrimth! My brand est Stellah Rys, howevere allies calleth moi Allamere. Alloweth moi to explaineth to thou the power of grapefruitte. The Spacenish, verily, they hath descendeth upon moi land and acquired the grapefruitte. No longereth est it with me",
            &"blue_planet_intro"
        )
        .send(comms_in)
    )


func blue_planet_outro(comms_in: CommsInModule) -> void:
    await gleep("ok byebye", &"blue_planet_outro").send(comms_in)


func purple_planet_intro(comms_in: CommsInModule) -> void:
    await (
        msg(
            "Yo. IBP here. Dont mind the chanting, its a celebration. That hologram couple, we're really into it. By the way, NO FEDORAS ALLOWED.\n(signed, man)",
            &"purple_planet_intro"
        )
        .from(purple_race)
        .send(comms_in)
    )


func purple_planet_outro(comms_in: CommsInModule) -> void:
    await (
        msg("btw bramblestar rules", &"purple_planet_outro")
        .from(purple_race)
        .send(comms_in)
    )


func orange_planet_intro(comms_in: CommsInModule) -> void:
    await (
        msg(
            "Yooo lil space dude, welcome to da planet! It’s da bomb right here! Where everything happens, cuz it’s da bomb right here! Wait...are you IBP? You better not be IBP, cuz this planet is da bomb! Anyone welcome if not police, we da bomb! 100…99…98…97…",
            &"orange_planet_intro"
        )
        .from(orange_race)
        .send(comms_in)
    )


func universe_edge(
    comms_in: CommsInModule,
    side: StringName
) -> void:
    await (
        msg(EDGE_MESSAGES.pick_random(), StringName("edge_%s" % side))
        .from(edge_race)
        .send(comms_in)
    )
