extends Node

var nickname = "Guest"
var game: Node
var menu: CanvasLayer
var name_input: LineEdit
var address_input: LineEdit
var message: Label
var port = 28115
var cli: Dictionary = {}

func _ready():
    get_window().title = "Frontline | 方塊前線"
    var args = OS.get_cmdline_user_args()
    for i in args.size():
        if args[i].begins_with("--"):
            cli[args[i]] = args[i + 1] if i + 1 < args.size() and not args[i + 1].begins_with("--") else "true"
    if cli.has("--port"):
        port = int(cli["--port"])
    var settings = ConfigFile.new()
    if settings.load("user://settings.cfg") == OK:
        nickname = settings.get_value("player", "nickname", "Guest")
    if cli.has("--name"):
        nickname = cli["--name"]
    _show_menu()
    if cli.has("--host") or cli.has("--server"):
        call_deferred("_start", 2)
    elif cli.has("--join"):
        address_input.text = cli["--join"]
        call_deferred("_start", 1)
    elif cli.has("--play"):
        call_deferred("_start", 0)

func _style(color: Color) -> StyleBoxFlat:
    var box = StyleBoxFlat.new()
    box.bg_color = color
    box.set_corner_radius_all(8)
    box.set_content_margin_all(12)
    return box

func _show_menu():
    menu = CanvasLayer.new()
    menu.layer = 30
    add_child(menu)
    var background = ColorRect.new()
    background.color = Color(0.025, 0.05, 0.075, 0.96)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(background)
    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(center)
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(520, 0)
    panel.add_theme_stylebox_override("panel", _style(Color("#162631")))
    center.add_child(panel)
    var layout = VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    panel.add_child(layout)
    var title = Label.new()
    title.text = "FRONTLINE\n方塊前線"
    title.add_theme_font_size_override("font_size", 34)
    layout.add_child(title)
    var subtitle = Label.new()
    subtitle.text = "離線單人 · 區網合作 · 玩家對戰"
    subtitle.modulate = Color("#b1c8d4")
    layout.add_child(subtitle)
    var player_label = Label.new()
    player_label.text = "玩家暱稱"
    layout.add_child(player_label)
    name_input = LineEdit.new()
    name_input.text = nickname
    name_input.max_length = 20
    name_input.custom_minimum_size.y = 40
    layout.add_child(name_input)
    var host_label = Label.new()
    host_label.text = "朋友主機的 IP 位址"
    layout.add_child(host_label)
    address_input = LineEdit.new()
    address_input.text = "127.0.0.1"
    address_input.custom_minimum_size.y = 40
    layout.add_child(address_input)
    if game != null:
        _button(layout, "繼續遊戲", _resume)
        _button(layout, "返回主選單", _leave)
    else:
        _button(layout, "單人開始", _start.bind(0))
        _button(layout, "開啟合作房間", _start.bind(2))
        _button(layout, "加入朋友的房間", _start.bind(1))
    message = Label.new()
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.custom_minimum_size.x = 470
    message.modulate = Color("#a7b9c6")
    message.text = "不需註冊。主機開房後，朋友輸入其區網 IP 即可加入。"
    layout.add_child(message)
    _button(layout, "離開遊戲", _quit)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _button(parent: Node, text: String, callback: Callable):
    var button = Button.new()
    button.text = text
    button.custom_minimum_size.y = 43
    button.add_theme_font_size_override("font_size", 19)
    button.add_theme_stylebox_override("normal", _style(Color("#284251")))
    button.add_theme_stylebox_override("hover", _style(Color("#3b6070")))
    button.add_theme_stylebox_override("pressed", _style(Color("#bc653d")))
    button.pressed.connect(callback)
    parent.add_child(button)

func _start(network_mode: int):
    nickname = name_input.text.strip_edges()
    if nickname.is_empty():
        nickname = "Guest"
    var address = address_input.text.strip_edges()
    if network_mode == 1 and address.is_empty():
        message.text = "請輸入朋友主機的 IP 位址。"
        return
    var settings = ConfigFile.new()
    settings.set_value("player", "nickname", nickname)
    if not cli.has("--qa"):
        settings.save("user://settings.cfg")
    menu.queue_free()
    menu = null
    game = load("res://blocky_game/blocky_game.tscn").instantiate()
    game.set_script(load("res://frontline/game.gd"))
    game.name = "Game"
    game.set_network_mode(network_mode)
    game.set_port(port)
    game.set_ip(address)
    add_child(game)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    print("FRONTLINE_STANDALONE_READY mode=", network_mode, " port=", port)
    if cli.has("--capture"):
        _capture()

func _capture():
    await get_tree().create_timer(8.0).timeout
    var image = get_viewport().get_texture().get_image()
    image.save_png(cli["--capture"])
    print("FRONTLINE_CAPTURE_SAVED")
    if cli.has("--capture-quit"):
        _quit()

func _input(event):
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and game != null:
        if menu == null:
            _show_menu()
        else:
            _resume()
        get_viewport().set_input_as_handled()

func _resume():
    if menu != null:
        menu.queue_free()
        menu = null
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _leave():
    if game != null:
        game._save_world()
        game.queue_free()
        game = null
    multiplayer.multiplayer_peer = null
    if menu != null:
        menu.queue_free()
    call_deferred("_show_menu")

func _quit():
    if game != null:
        game._save_world()
    get_tree().quit()
