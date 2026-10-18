extends Node

var main_screen: MainScreenModule
var comms_in: CommsInModule
var decoder: DecoderModule
var translator: TranslatorModule
var dialogues: GameDialogues


func _ready() -> void:
    main_screen = MainScreenModule.new()
    main_screen.name = "MainScreenDemo"
    add_child(main_screen)
    
    comms_in = CommsInModule.new()
    comms_in.name = "CommsInDemo"
    add_child(comms_in)
    
    decoder = DecoderModule.new()
    decoder.name = "DecoderDemo"
    add_child(decoder)
    
    translator = TranslatorModule.new()
    translator.name = "TranslatorDemo"
    translator.select_cassette(&"gleep_glorp")
    add_child(translator)
    
    dialogues = GameDialogues.new()
    dialogues.name = "GameDialogues"
    add_child(dialogues)
    
    main_screen.get_output_port(&"power").connect_port(
        comms_in.get_input_port(&"power")
    )
    comms_in.get_output_port(&"data").connect_port(
        decoder.get_input_port(&"power")
    )
    decoder.get_output_port(&"data").connect_port(
        translator.get_input_port(&"power")
    )
    translator.get_output_port(&"data").connect_port(
        main_screen.get_input_port(&"data")
    )
    
    dialogues.demo_gleep_call(comms_in)
    await get_tree().create_timer(2.0).timeout
    comms_in.establish_connection()
