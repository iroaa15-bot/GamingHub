extends TextureRect
var _url := ""

func show_avatar(value: String,origin: String) -> void:
 if value.begins_with("/api/avatars/") and origin.begins_with("https://"):value=origin+value
 if not value.begins_with("https://") or "@" in value:value=""
 if value==_url:return
 _url=value
 texture=load("res://scripts/visual_skin.gd").menu_icon("player")
 if value.is_empty():return
 var request:=HTTPRequest.new();request.timeout=8;request.body_size_limit=1048576;add_child(request)
 if request.request(value)!=OK:request.queue_free();return
 var response: Array=await request.request_completed
 request.queue_free()
 if not is_inside_tree() or value!=_url or response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200:return
 var data: PackedByteArray=response[3]
 var image:=Image.new();var result: Error=ERR_INVALID_DATA
 if data.size()>12:
  if data[0]==0xff:result=image.load_jpg_from_buffer(data)
  elif data[0]==0x89:result=image.load_png_from_buffer(data)
  elif data.slice(0,4).get_string_from_ascii()=="RIFF":result=image.load_webp_from_buffer(data)
 if result==OK and image.get_width()<=2048 and image.get_height()<=2048:texture=ImageTexture.create_from_image(image)
