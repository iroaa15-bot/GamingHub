extends VBoxContainer
## Adapts the existing comma-separated field without changing local game setup.
var target: LineEdit
var fields: Array[LineEdit]=[]
var count := 3
var syncing := false
var remove_button: Button
var add_button: Button
func bind_field(source: LineEdit) -> void:
 target=source
 var grid:=GridContainer.new();grid.columns=2
 grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);add_child(grid)
 for i in range(6):
  var field:=LineEdit.new();field.placeholder_text="اللاعب %d" % (i+1)
  field.custom_minimum_size=Vector2(0,52);field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  field.max_length=24;field.text_changed.connect(func(_text: String):write_names())
  fields.append(field);grid.add_child(field)
 var actions:=HBoxContainer.new();add_child(actions)
 add_button=Button.new();add_button.text="+ لاعب";add_button.custom_minimum_size.y=48
 add_button.pressed.connect(func():if count<6:count+=1;refresh_rows();write_names())
 remove_button=Button.new();remove_button.text="− لاعب";remove_button.custom_minimum_size.y=48
 remove_button.pressed.connect(func():if count>2:count-=1;refresh_rows();write_names())
 actions.add_child(add_button);actions.add_child(remove_button)
 source.text_changed.connect(read_names)
 read_names(source.text);source.hide()
func read_names(value: String) -> void:
 if syncing:return
 syncing=true
 var names: PackedStringArray=value.replace("،",",").split(",",false)
 count=clampi(names.size(),2,6)
 for i in range(fields.size()):fields[i].text=names[i].strip_edges() if i<names.size() else ""
 refresh_rows()
 syncing=false
func refresh_rows() -> void:
 for i in range(fields.size()):fields[i].visible=i<count
 add_button.disabled=count>=6;remove_button.disabled=count<=2
func write_names() -> void:
 if syncing:return
 syncing=true
 var names: PackedStringArray=[]
 for i in range(count):names.append(fields[i].text.replace(","," ").replace("،"," ").strip_edges())
 target.text=", ".join(names)
 syncing=false
