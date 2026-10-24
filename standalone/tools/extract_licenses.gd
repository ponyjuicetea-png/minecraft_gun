extends SceneTree

func _initialize():
    var directory = ProjectSettings.globalize_path("res://../licenses")
    DirAccess.make_dir_recursive_absolute(directory)
    var file = FileAccess.open(directory.path_join("Godot-MIT.txt"), FileAccess.WRITE)
    file.store_string(Engine.get_license_text())
    file.close()
    file = FileAccess.open(directory.path_join("Engine-Third-Party.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({
        "copyright": Engine.get_copyright_info(),
        "licenses": Engine.get_license_info()
    }, "  "))
    file.close()
    quit()
