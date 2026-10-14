# Gaming Hub v11.5 — إصدار تجريبي للتحقق من جاهزية Google Play

افتح `project.godot` باستخدام Godot 4.5.1. **هذه الحزمة مصدر لعبة قابل للتعديل، وليست APK أو AAB.**

- للتثبيت الآمن لإضافة AdMob التجريبية عبر PowerShell: `release/install_admob_windows.ps1 -EnableTestAds` (يتطلب الإنترنت وملفات Poing الأصلية، دون تفعيل إعلانات إنتاجية).
- بناء النسخة التجريبية بعد تنزيل SDK/JDK وقالب Android: `release/build_android.ps1 -Mode debug`.
- بيانات المتجر، وخطوات التوقيع والخصوصية والمتطلبات المتبقية: `release/PLAY_PUBLICATION_BLOCKERS_AR.md`.
- المحتوى اليومي التراكمي محفوظ ولا يستبدل القديم؛ الأرشيف أقدم الأيام قابل للاسترجاع.
- **لم يتم اختبار Godot أو أجهزة Android أو إعلانات AdMob الفعلية هنا، لذا لا تنشر الحزمة في المتجر قبل الاختبار.**
Gaming Hub v11.3 — Daily Picture Challenges

افتح project.godot في Godot 4.5.1.
تجديد الصور يومي من نفس السيرفر: https://gaminghub-multiplayer.onrender.com/ai_daily/daily.json
كل يوم 6 ألغاز صور برسومات أصلية و4 اختيارات.
نظام الأسئلة النصية يظل منفصلًا على /content/daily.json.
لا تُنشر صور المشاهير تلقائيًا حتى تتوفر صور مرخّصة ومراجعة.
راجع RELEASE_v11.3_AR.md للتفاصيل.


## v11.3 — تخمين الصور
افتح المشروع باستخدام Godot 4.5.1 ثم اختار «خمن الصورة • 6 ألغاز جديدة يوميًا». يحتاج اتصالًا بالسيرفر لأحدث ألغاز الصور. صور الأشخاص الحقيقية ليست منشورة آليًا.


## v11.4
افتح project.godot في Godot 4.5.1. السيرفر يقدم /content/history.json و /ai_daily/history.json. المحتوى اليومي يضاف ولا يستبدل المحتوى القديم. ملف AdMob الأصلي لم يُركّب بعد.
