#!/usr/bin/env python3
import datetime, hashlib, json, pathlib, re, sys
def validate(folder):
    folder=pathlib.Path(folder)
    data=json.loads((folder/"daily.json").read_text(encoding="utf-8"))
    keys={"schema","date","image","sha256","status","answer_verified","choices_en","choices_ar","correct_index","xp","title_en","title_ar"}
    assert keys<=data.keys(), "missing required fields"
    assert data["schema"]==1 and data["status"]=="approved" and data["answer_verified"] is True
    assert datetime.date.fromisoformat(data["date"]).isoformat()==data["date"]
    assert data.get("provider")!="demo", "demo content forbidden"
    assert re.fullmatch(r"daily-\d{4}-\d{2}-\d{2}\.png",data["image"])
    assert data["image"]=="daily-"+data["date"]+".png"
    assert all(isinstance(data[k],list) and len(data[k])==3 and all(isinstance(s,str) and s.strip() for s in data[k]) for k in ("choices_en","choices_ar"))
    assert type(data["correct_index"]) is int and 0<=data["correct_index"]<3
    assert type(data["xp"]) is int and 0<=data["xp"]<=100
    image=(folder/data["image"]).read_bytes()
    assert image.startswith(b"\x89PNG\r\n\x1a\n") and len(image)<=3000000
    assert hashlib.sha256(image).hexdigest()==data["sha256"]
    print("Validated approved puzzle:",data["date"])
if __name__=="__main__":
    try:validate(sys.argv[1])
    except (AssertionError,ValueError,KeyError,OSError,IndexError) as e:
        print("Rejected:",e,file=sys.stderr);sys.exit(1)
