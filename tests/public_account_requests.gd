extends SceneTree
class Fixture:
 extends Node
 var server:=TCPServer.new()
 var peers: Array=[]
 func _ready() -> void:assert(server.listen(18943,"127.0.0.1")==OK)
 func _process(_delta: float) -> void:
  while server.is_connection_available():peers.append({"socket":server.take_connection(),"request":"","answered":false})
  for peer in peers:
   var socket: StreamPeerTCP=peer.socket
   socket.poll()
   if peer.answered or socket.get_available_bytes()==0:continue
   peer.request+=socket.get_utf8_string(socket.get_available_bytes())
   if "\r\n\r\n" in peer.request:
    peer.answered=true
    socket.put_data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: keep-alive\r\n\r\n{}".to_utf8_buffer())
 func _exit_tree() -> void:
  server.stop()
  for peer in peers:peer.socket.disconnect_from_host()
class BrokenRefresh:
 extends "res://scripts/network/gaminghub_auth.gd"
 var renewals:=0
 func _ready() -> void:pass
 func refresh_session() -> Dictionary:
  renewals+=1
  return {"ok":false,"status":401}
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(20).timeout.connect(func():push_error("Public account request timeout");quit(1))
 root.get_node("PublishedContent").busy=true
 var fixture:=Fixture.new();root.add_child(fixture)
 var auth:=BrokenRefresh.new();root.add_child(auth)
 auth.api_base="http://127.0.0.1:18943/api" # Loopback fixture only; production configure still requires HTTPS.
 auth.refresh_token="expired-fixture-session";auth.refresh_after=0
 for path in ["/auth/providers","/auth/login","/auth/register","/auth/guest"]:
  var response: Dictionary=await auth._call(path,HTTPClient.METHOD_GET if path=="/auth/providers" else HTTPClient.METHOD_POST)
  assert(response.ok and response.status==200 and auth.renewals==0)
 var protected: Dictionary=await auth._call("/me",HTTPClient.METHOD_GET)
 assert(not protected.ok and auth.renewals==1)
 auth.queue_free();fixture.queue_free();await process_frame
 print("PUBLIC_ACCOUNT_REQUESTS_PASS — actual HTTP calls bypass broken refresh only for public auth endpoints")
 quit(0)
