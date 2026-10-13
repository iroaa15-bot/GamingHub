# Gaming Hub v9.3 — Full Source Upload (staging)

This branch is a staging branch for the complete Godot 4.5.1 source package. It is **NOT** a playable Android build.

**Important:** the full project is not in this branch yet. The source archive was tested locally: 185 files, 198 Python tests passed. Those results do **not** mean Godot runtime or Android export has passed.

To finish the source upload:
1. Extract `GamingHub_v9.3_GitHub_Source.zip` from the ChatGPT attachment.
2. Upload the **contents of the extracted folder** (not the ZIP) to this branch, preserving folder paths and all 185 files.
3. The GitHub Actions workflow must run `release/verify_project_upload.py` and `release/verify_archive_runtime.py` before Android export.
4. Review the Godot validation job, Android export logs and signed debug APK artifact.
5. Do not merge this branch into main until source checks and Android debug build pass.

## العربية
الفرع ده للتحضير لرفع ملفات اللعبة كاملة. لسه الملفات الأساسية مش كلها موجودة على GitHub. افك ملف ZIP وارفع محتوياته كاملة على الفرع، وبعدها نراجع نتائج GitHub Actions. لا ترفع مفاتيح توقيع Android أو أي كلمات مرور.

Source archive: GamingHub_v9.3_GitHub_Source.zip
