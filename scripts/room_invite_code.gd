extends RefCounted
## Shared invite parsing; never converts an invitation into authentication.
static func normalize(value: String) -> String:
 var result: String=value.strip_edges().replace(" ","").replace("-","").to_upper()
 for i in range(10):
  result=result.replace("٠١٢٣٤٥٦٧٨٩"[i],str(i)).replace("۰۱۲۳۴۵۶۷۸۹"[i],str(i))
 return result
static func valid(value: String,classic: bool=false) -> bool:
 var pattern=RegEx.new()
 pattern.compile("^[A-Z0-9]{6}$" if classic else "^([0-9]{6}|[A-F0-9]{8})$")
 return pattern.search(normalize(value))!=null
