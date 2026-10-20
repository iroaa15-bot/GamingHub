# تسليم Gaming Hub Voice Staging — 20 أكتوبر 2026

العمل محصور في `iroaa15-bot/GamingHub` على `fix/android-voice-root-cause`. لم يتغير `main` ولا ملفات إعداد الإنتاج. هذا تحديث لتقرير المرحلة السابقة: تم الآن بناء APK فعليًا محليًا بعد نجاح الفحوص البرمجية، وليس بواسطة GitHub Actions.

## الحزمة والتشغيل

اسم الملف: `GamingHub-Voice-Staging-11.7.apk`، الاسم داخل الهاتف `Gaming Hub Voice Test`، والحزمة `com.iroaa15.gaminghub.voicestaging`. توقيع Debug مخصص للاختبار؛ الحزمة مستقلة عن نسخة الإنتاج. Android 7/API 24 فأحدث، target API 36، ARM32 وARM64. الاتصال المحدد داخل APK هو `wss://gaminghub-voice-staging.onrender.com`؛ إعداد الإنتاج لم يُستبدل.

ثبّت نفس APK على هاتفين. افتح الأونلاين، أنشئ غرفة وانضم إليها من الهاتف الثاني، ثم فعّل الصوت واسمح بالميكروفون على الطرفين. لا تُشترط سماعات رأس. موافقة الصوت مطلوبة من الطرفين؛ بعد إعادة الاتصال يجب تفعيل الصوت مجددًا. حجم APK النهائي 101,407,491 بايت (96.7 MiB)، SHA-256: `cbb30bace2843fc29a477a0f9702014e0005a112a627a085481cff20d77b5035`. الملف متاح للتنزيل في رسالة التسليم. تفاصيل الحجم وSHA-256 والتوقيع والبصمة موجودة في [نتيجة فحص APK](staging_apk_validation/apk-verification.json).

## ما تم إصلاحه والتحقق منه

تمت مراجعة الإصلاحات السابقة المتصلة باللعبة: مشروع الإضافة الأصلي وAAR وتسجيل Godot؛ صلاحيات الميكروفون وإدارة audio focus والمسار مع MODE_IN_COMMUNICATION؛ تفعيل AEC/NS/AGC عند توفر دعم الجهاز وإبلاغ القدرات؛ مخازن تسجيل وتشغيل محدودة؛ PCM v2 مع epoch/seq؛ موافقة الطرفين؛ نقل الصوت بين الغرف وإسقاط المكرر والقديم؛ وقف الميكروفون عند الخلفية أو الفصل، واستعادة الغرفة مع موافقة جديدة. التفاصيل التصميمية في [التقرير السابق](ANDROID_VOICE_HANDOFF_AR.md).

في هذا التسليم أضيف دعم ARM32 إلى نسخة staging المعزولة، وضغط مكتباتها الأصلية، وفاحص للحزمة النهائية يقرأ تعريفات DEX الفعلية والـManifest والتوقيع وملف staging المضمّن وبصمة مصدر المحرك. أضيف اختبار Godot يثبت أن multiplayer يختار staging في النسخة المعزولة. لم تتغير ملفات Kotlin أو السيرفر في هذا التسليم؛ يستخدم APK الإصلاح الأصلي المبني والمتحقق من بصمته.

## نتائج هذه الجلسة

| الفحص | النتيجة | الدليل |
|---|---|---|
| Python offline/server/ai_daily | 218 +75 +3 =296 ناجحًا | [السجل](staging_apk_validation/python-tests.log) |
| Kotlin `testDebugUnitTest` | 14 ناجحًا، صفر فشل/تجاهل | [JUnit](staging_apk_validation/native-junit.xml)، [Gradle](staging_apk_validation/native-tests.log) |
| بصمة AAR Debug/Release | مطابق للمصدر | [السجل](staging_apk_validation/aar-verification.log) |
| Godot voice runtime | ناجح؛ حد JNI محاكى | [السجل](staging_apk_validation/voice-runtime.log) |
| عميلان Godot + سيرفر WebSocket حقيقي | ناجح: PCM وموافقة وفصل واستعادة | [السجل](staging_apk_validation/voice-room-runtime.log) |
| Godot smoke وrelease runtime | ناجحان | [smoke](staging_apk_validation/godot-smoke.log)، [release](staging_apk_validation/release-runtime.log) |
| اختيار staging وقت تشغيل Godot | ناجح | [السجل](staging_apk_validation/staging-profile.log) |
| سيرفر staging المنشور | نجح النقل ثنائي الاتجاه ورفض التكرار وإلغاء الموافقة | [السجل](staging_apk_validation/staging-smoke.log) |
| بناء Android APK / Godot 4.5.1 / JDK17 / SDK36 | نجاح التصدير | [السجل](staging_apk_validation/android-export.log) |
| الحزمة النهائية | توقيع صحيح، صلاحيات، Plugin وDEX وبصمة مصدر، staging، ARM32/64 وZIP سليمة | [JSON](staging_apk_validation/apk-verification.json)، [التوقيع](staging_apk_validation/apk-signature.txt) |

[اختبار GitHub Actions السابق الناجح لسيرفر staging](https://github.com/iroaa15-bot/GamingHub/actions/runs/39325348601) يخص commit `d2575ae` ولا يمثل بناء APK الحالي. لم يتم تشغيل Actions إضافية لهذه الجلسة. نشر commit التسليم يحمل `[skip ci] [skip render]` لتجنب بناء أو نشر غير لازم.

حُلت في بيئة البناء المحلية مشكلة تركيب Android SDK داخل مجلد متداخل. ظهرت أيضًا مشكلة metadata في مخزن Gradle عند إعادة البناء؛ أُعيد إنشاء مخزن النسخة والمشروع. سجل التصدير يتضمن رسالة adb بعدم وجود daemon؛ لا يمنع ذلك تصدير APK، لكنه لا يمثل تثبيتًا على جهاز. المرجع هو فحص الحزمة النهائية وسجل التصدير النهائي، وليس المحاولات الوسيطة.

## ما لا يزال يحتاج هاتفين Android حقيقيين

لم يتصل جهاز Android حقيقي بهذه البيئة؛ لم يتم اختبار الميكروفون أو السماعة أو تقدير جودة الصدى فعليًا. اختبارات PCM السابقة مولدة؛ وجود AEC/NS/AGC في الكود لا يضمن أن كل جهاز ينفذها بجودة كافية.

يجب اختبار: منح/رفض الإذن وإعادة منحه؛ حديث متزامن باتجاهين عبر سماعة الهاتف بلا سماعات رأس مع تقييم الصدى والصفير؛ تسجيل القدرات الفعلية لكل جهاز؛ مستويات الصوت ومسار Bluetooth/السلكي عند تغييره؛ خلفية التطبيق وقفل الشاشة والمقاطعات وفقد audio focus؛ Wi‑Fi/شبكة هاتف وضعف الشبكة والعودة وإلغاء الموافقة؛ التثبيت والتشغيل على ARM32 وARM64. التأخير والتقطيع وجودة AEC تحتاج قياسًا واستماعًا على الأجهزة قبل اعتماد إصدار نهائي.

## نص جاهز لاستكمال العمل في ChatGPT

> المشروع iroaa15-bot/GamingHub، الفرع الوحيد المسموح fix/android-voice-root-cause؛ ممنوع تعديل main. تم تجهيز إصلاح Android native المتصل بـGodot، مع صلاحيات ومسارات الصوت وAEC/NS/AGC حسب دعم الجهاز، PCM v2 وموافقة الطرفين والاستعادة. تم بناء وتسليم GamingHub-Voice-Staging-11.7.apk بحزمة com.iroaa15.gaminghub.voicestaging مستقلة، متصلة بـwss://gaminghub-voice-staging.onrender.com. نجح 296 اختبار Python و14 Kotlin، واختبارات Godot وعميلين WebSocket وفحص APK النهائي؛ سجلاتها في docs/staging_apk_validation والتقرير docs/STAGING_APK_DELIVERY_AR.md. لم تُختبر هواتف حقيقية. الخطوة التالية تثبيت APK نفسه على هاتفين واختبار الصدى بلا سماعات والتحدث المتزامن والمسارات والمقاطعات والشبكة؛ اجمع طراز الجهاز وإصدار Android وسجل VOICE_CAPABILITIES والأعطال. لا تعتبر نجاح الاختبارات المولدة دليل جودة صوت فعلية ولا تُنشر نسخة إنتاج قبل اختبار الأجهزة.

## سجل commits السابقة لهذه المهمة

- [30d78c5](https://github.com/iroaa15-bot/GamingHub/commit/30d78c53381c77301fbd1b9e37e07a2a2fe6d803) — fix(voice): connect native Android audio, consent and room recovery [skip ci]
- [f564a4e](https://github.com/iroaa15-bot/GamingHub/commit/f564a4e26007552654e6a579855fdbccdb02a7a1) — test: add isolated staging WebSocket voice consent smoke test [skip ci]
- [f7672c8](https://github.com/iroaa15-bot/GamingHub/commit/f7672c85fe59a720f47b214376c025ed841af6e7) — test: verify staging PCM v2 relay and duplicate suppression [skip ci]
- [0b52b0f](https://github.com/iroaa15-bot/GamingHub/commit/0b52b0f25686092d23423a98b0a96384ff5b2552) — test: exercise bidirectional staging voice and opt-out enforcement [skip ci]
- [e83a5b1](https://github.com/iroaa15-bot/GamingHub/commit/e83a5b1e8142b76d46d1ae6e38f0fb294a72ac44) — feat(voice): allow explicitly opted-in staging endpoint without changing production URL [skip ci]
- [f5d37da](https://github.com/iroaa15-bot/GamingHub/commit/f5d37daaae7bf37423868a1d6a0cff191b88909d) — docs: add opt-in staging voice endpoint example [skip ci]
- [459aec3](https://github.com/iroaa15-bot/GamingHub/commit/459aec3bba536bc4684afbf0d984000f8d71e566) — build: prepare isolated staging Godot source without changing production config [skip ci]
- [1e8c574](https://github.com/iroaa15-bot/GamingHub/commit/1e8c574ff3e0f348d3e36eb4267bfac1114f1478) — fix(staging): isolate Android application ID and label to protect installed production app [skip ci]
- [393519c](https://github.com/iroaa15-bot/GamingHub/commit/393519cd025de8671015f195ca80e512219c49d8) — test: verify staging build isolation and production safety [skip ci]
- [2aba3b3](https://github.com/iroaa15-bot/GamingHub/commit/2aba3b3c5724a0d9f1a511632474706d11ef7905) — ci: add manual-only bounded voice staging verification workflow [skip ci]
- [d2575ae](https://github.com/iroaa15-bot/GamingHub/commit/d2575ae301cb0e190eafd23f74c88a9879186f95) — ci(voice): run existing staging smoke once on workflow update, no main or release changes
