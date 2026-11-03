extends SceneTree

func _initialize() -> void:
    var script_resource: Script = load("res://scripts/network/gaminghub_auth.gd")
    if script_resource == null or not script_resource.can_instantiate():
        push_error("AUTH_CLIENT_LOAD_FAIL")
        quit(1)
        return
    var client: Node = script_resource.new()
    root.add_child(client)
    if client.configure("http://insecure.example"):
        push_error("AUTH_CLIENT_ACCEPTED_INSECURE_URL")
        quit(1)
        return
    if not client.configure("https://example.test"):
        push_error("AUTH_CLIENT_HTTPS_REJECTED")
        quit(1)
        return
    if client.api_base != "https://example.test/api":
        push_error("AUTH_CLIENT_API_BASE_INVALID")
        quit(1)
        return
    print("AUTH_CLIENT_SMOKE_PASS")
    quit(0)
