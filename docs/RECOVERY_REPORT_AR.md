# Gaming Hub — استعادة اللعب وربط صوت Android

الفرع الوحيد المستخدم `recovery/android-gameplay-voice-20261020`. أصله `main` عند `39162256ccbea20151b6bb66a129baad1fd0bd42`، ثم احتُفظ بتعديلات استعادة اللعب المنشورة حتى `3c5ee360dd7eb70b933f7a6b1174338817d0b5ff`. لم يُعدل main، ولم يحدث merge من فرع الصوت السابق. نُقلت ملفات محددة بعد مراجعتها وإصلاح عيوبها.

## تشخيص رسالة الصورة والأسباب المؤكدة

- رسالة «الصوت غير متاح في هذه النسخة» تأتي من عدم ارتباط الجسر بـsingleton `GamingHubVoice` صالح. لا تثبت مشكلة ميكروفون أو مستوى صوت. فرع recovery قبل هذا التحديث لم يكن يحتوي الإضافة الأصلية؛ أصبحت الإضافة الآن مسجلة عبر Godot v2 وManifest وEditorExportPlugin، مع فحص DEX وJNI في APK النهائي. لا يمكن حسم هوية APK المثبت من صورة الشاشة وحدها.
- APK التشخيصي السابق احتوى `var bridge_ready := ...is_available()`؛ فشل استنتاج النوع لنداء ديناميكي وأنتج Parse Error في Multiplayer. صُرح بالنوع bool. تحميل PackedScene وحده لا يكشف هذا النوع من الفشل، لذا أضيف اختبار التنقل الفعلي واختبار موارد APK المجمعة.
- `clear_ui()` كان يجعل الواجهة alpha=0 ويعتمد على Tween. تعديلات recovery السابقة أبقت الواجهة ظاهرة فورًا؛ احتُفظ بها. هذا يثبت إزالة الاعتماد على animation، ولا يثبت وجود عيب GPU معين على OPPO.
- اختبار اللعب كشف توقف `advance_rival()` بسبب إسناد Array إلى Array[Dictionary]. أصبح نوع remaining مطابقًا، دون تغيير قواعد اللعبة أو البطاقات.
- إشارات ICE كانت تُحسب كطلبات لعب، وإرسال SDP إلى peer بطيء كان يحجز process. فشل اختبارا العزل قبل الإصلاح؛ أضيفت ميزانية صوت منفصلة وطابور signaling محدود مستقل. الفحص بعد الإصلاح يشمل 501 ICE packet ثم ping لعب.

## الصوت

المسار الافتراضي هو `io.github.webrtc-sdk:android:144.7559.15` بإصدار مثبت. يستخدم `JavaAudioDeviceModule` مع AudioRecord/AudioTrack وVOICE_COMMUNICATION، ومعالجة WebRTC البرمجية AEC وNS وAGC، وصوت mono عبر Opus/SRTP دون فيديو. لا يمر PCM في خيط Godot في هذا المسار. بقي API 2 ومسار PCM القديم للتوافق والرجوع، ولا يُشغل fallback خفيًا عند فشل WebRTC.

البدء والإغلاق على executor، مع استبعاد callbacks القديمة، وطابور ICE محدود، ومحاولات ICE restart محدودة. يحتفظ العميل برغبة المستخدم الذي فعّل الصوت لاستئنافه بعد استعادة الغرفة أو العودة للواجهة، مع إذن وموافقة سيرفر متجددة للطرفين. الرفض أو إلغاء الصوت أو المغادرة أو نهاية المباراة يلغي الاستئناف. تبقى حركات اللعب والغرف مستقلة عن media.

المراجع التقنية: [WebRTC AudioDeviceModule](https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/android/api/org/webrtc/audio/JavaAudioDeviceModule.java)، [توزيع Android](https://github.com/webrtc-sdk/android)، [TURN](https://webrtc.org/getting-started/turn-server).

## الحفاظ والحدود

تُقارن بصمات 615 ملفًا من الصور والمشاهد والمحتوى اليومي وAdMob وإعدادات الخدمات بملفات نسخة البداية. لا تعديل للقوائم أو تصميم الألعاب أو حذف محتوى. APK التجريبي له حزمة مستقلة `com.iroaa15.gaminghub.recoverystaging`، فلا يستبدل اللعبة الأصلية أو تقدمها أو نسخة staging السابقة.

Android 10 ضمن نطاق API المدعوم، مع ARM32 وARM64 وحراسة استدعاءات APIs الحديثة؛ ذلك ليس اختبار OPPO A31 فعليًا. لم يتوفر هاتف Android حقيقي. اختبارات JVM تخص مخازن PCM السابقة، وليست دليل جودة AEC. اختبار aiortc يستخدم صوتًا مولدًا وloopback UDP؛ يثبت Opus/SRTP وتبادل الإشارات، ولا يثبت جودة الميكروفون أو اجتياز NAT الهاتف.

المهمة غير معتمدة نهائيًا للصوت قبل اختبار الهاتفين والتحقق من TURN. تفاصيل الاختبارات وحدود التسليم أدناه.

## الإصلاحات الإضافية المؤكدة

- `claim_treasure()` كان يشغل feedback ثم يستدعي `show_round()`، الذي يزيل AudioStreamPlayer فورًا. عُكس الترتيب حتى لا يُقطع صوت المكافأة. تحقق اختبار Godot بعد تصحيح الترتيب.
- أخطاء الصوت ذات `scope=voice` لم تعد تلغي حركة اللعب المعلقة. رفض إذن الميكروفون، callbacks قديمة، أو إلغاء الموافقة لا توقف التنقل أو تخرج اللاعب من غرفته في اختبارات العميل/السيرفر المحلية.

## نتائج قابلة لإعادة التنفيذ

السجلات الأصلية في [docs/recovery/evidence](recovery/evidence). هذه نتائج تنفيذ محلي بتاريخ 2026-10-20، وليست نتائج GitHub Actions أو اختبار هاتف:

| الفحص | النتيجة والحدود |
| --- | --- |
| `python tests/run_checks.py` | 299 اختبارًا ناجحًا: 219 مشروع، 77 سيرفر، 3 توليد يومي؛ مع project_preflight. |
| `test_recovery_preservation.py` | بصمات 615 ملفًا محفوظة من main؛ تشمل الصور والمشاهد وAdMob ومكونات التوليد اليومي وإعداد الإنتاج. |
| `tests/recovery_runtime.gd` | تنقل حقيقي بإشارات الأزرار، ظهور فوري، textures، دور الكمبيوتر، 10 ألعاب ×3 مستويات، نقاط وحفظ/إعادة تحميل. |
| `tests/godot_smoke.gd` | مشهدا اللعب offline/friend ظاهران دون SCRIPT ERROR أو ERROR. |
| `tests/activities.gd` | 45 لوحة ذاكرة، deduction، reward-once، timers، order وأربعة لاعبين. |
| `tests/expansion.gd` | البطاقات المضمنة، أساليب اللعب، aliases، gallery، feedback والمفضلة. |
| `tests/release_runtime.gd` | دمج المحتوى اليومي في المقدمة دون حذف، deduplication، consent والمكافآت؛ adapter الإعلان محاكى ولا اتصال AdMob إنتاجي. |
| `tests/webrtc_bridge_runtime.gd` | موافقة/رفض الإذن/إلغاء/إشارات قديمة، وعدم polling لـPCM؛ native محاكى. |
| `tests/run_voice_room_runtime.py --script res://tests/webrtc_room_runtime.gd` | عميلان Godot وسيرفر حقيقي محليًا: عزل خطأ الصوت، استعادة الغرفة والموافقة، foreground/background؛ JNI محاكى. |
| `server/test_webrtc_isolation.py` | فشل اختبارا burst وslow-peer قبل التعديل؛ نجحا بعده. 501 ICE ثم ping يبقي اللعب متصلًا محليًا. |
| `tests/smoke_voice_staging.py` | نجح على staging الموجودة: ping/room/join/consent/PCM في الاتجاهين ومنع duplicate وإلغاء الموافقة. PCM مولد، ليس تسجيل ميكروفون. |
| `tests/webrtc_media_integration.py` و`--staging` | نجح محليًا وبإشارات staging: 30 إطارًا غير صامت في كل اتجاه عبر Opus/SRTP loopback UDP؛ لا إثبات لمسار هاتف/NAT. |
| `VoiceBuffersTest` | 14 اختبار JVM، صفر failures/errors/skips؛ تخص buffers وPCM القديم فقط. |
| Android lint | Debug دون مشاكل؛ Release صفر أخطاء وتحذير تحديث AGP، دون تغيير الإصدار خارج النطاق. |

### اختبارات فاشلة يجب عدم إخفائها

`tests/smoke.gd` و`tests/journeys.gd` و`tests/languages.gd` القديمة تفشل في فرع recovery وفي نسخة منفصلة من main نفسه. أعيد تشغيل المقارنة؛ توقف كل اختبار عند Assertion ثم timeout بعد 5 ثوانٍ. الأول يفترض وجود audience حرفيًا في كل سؤال بينما المحتوى الحالي يستخدم `all`؛ الثاني يفرض صورة ≤768 بينما الصور الأصلية أكبر؛ الثالث يتوقع عقد اختيار اللغة التركي القديم. لم تُحذف الصور أو تُغيّر قواعد اللعبة لإرضاء هذه الافتراضات. راجع `legacy-comparison.json` والسجلات الستة. اختبارات regression الحديثة أعلاه ناجحة لكن هذا لا يجعل المجموعة القديمة ناجحة.

أول تشغيل لفحوص inventory بعد تغيير عنوان staging اكتشف بصمات قديمة؛ أُعيد توليد `release/source_manifest.json` ثم نجحت الفحوص كاملة. APK التشخيصي السابق فشل فعلًا في اختبار موارده بـParse Error، محفوظ في `broken-apk/`، ولم يُسلّم باعتباره ناجحًا.

## staging وحالة النشر

- APK مخصص للعنوان القائم `wss://gaminghub-voice-staging.onrender.com`، وليس عنوان الإنتاج. إعداد `data/network_config.json` الأصلي محفوظ؛ override موجود في نسخة البناء فقط.
- الخدمة القائمة `srv-dbb7i1dg1s2s738gccbg` ما زالت على `fix/android-voice-root-cause` وautoDeploy مغلق. لم ننشر تعديل السيرفر الجديد عليها، لذلك لا تنسب نتيجة عزل 501 ICE المحلية إلى staging الحالية.
- السيرفر الحالي يمرر SDP/ICE بنجاح؛ أعاد الاختبار `turn_configured=false`. الاتصال عبر بعض شبكات المحمول وsymmetric NAT غير مضمون دون TURN قائم وتفويض إعداد بياناته؛ لم تُنشأ خدمة مدفوعة أو حساب خارجي.
- لم يُمس production Render، ولم تُنشأ خدمة عامة جديدة. رفضت المراجعة الآلية محاولة إنشاء خدمة recovery عامة، لأن التفويض لا يشمل إنشاء خدمة إضافية وإتاحة مصدر المستودع لها. البديل هو الخدمة التجريبية القائمة.
- نشر commit محدد على staging يحتاج تغيير branch/commit في Dashboard؛ أداة Render الحالية لا توفر ذلك. لا يكفي `trigger_deploy` لأنها ستنشر فرع الصوت القديم مجددًا. يلزم السماح باستخدام Dashboard لهذه الخدمة فقط لاستكمال التحقق من السيرفر المنشور.

## APK الذي اجتاز الفحص

- الملف: `GamingHub-Recovery-Staging-11.7.apk`، حزمة `com.iroaa15.gaminghub.recoverystaging` باسم `Gaming Hub Recovery Test`.
- الحجم: 112007262 bytes (106.82 MiB). SHA-256: `99721911d8956f5bf7105037b7c9d5eb66fc6844df78a08d358d2abdc070081e`.
- `STAGING_APK_VERIFIED`: توقيع apksigner صحيح، minSDK=24 وtargetSDK=36، صلاحيات الميكروفون والشبكة، Manifest يسجل Godot v2 plugin، وتعريفات DEX للإضافة وWebRTC ومكتبات JNI على ARM32/ARM64. بصمة المصدر الأصلي تطابق AAR وAPK.
- `APK_RUNTIME_PASS`: شُغلت موارد APK المجمعة نفسها في Godot 4.5.1 headless؛ نجح التنقل والكمبيوتر والموارد والنقاط والحفظ. لم تُشغل Android Activity أو JNI أو الميكروفون في هذا الاختبار.
- راجع `apk-verification.json` و`apk-runtime.json` و`apk-gameplay-runtime.log` و`apk-signature.txt`. بُني APK من الكود التنفيذي في e086 مع تصحيح عنوان staging إلى الخدمة القائمة في commit تسليم الأدلة؛ تغييرات التقرير والسجلات اللاحقة لا تغيّر التطبيق.
- هذا APK تجريبي؛ ليس إصدارًا إنتاجيًا أو اعتمادًا نهائيًا للصوت. لا تستبدل أو تحذف اللعبة الأصلية بسببه.

## بيئة البناء وإعادة الاختبار

Godot 4.5.1 stable، JDK 17.0.20، Gradle 8.11.1، Android Build Tools 36.0.0. بُنيت الإضافة عبر `./gradlew --no-daemon --max-workers=2 testDebugUnitTest lintDebug lintRelease installPlugin`. للتحقق من المصدر: `python tests/run_checks.py` ثم `python tools/verify_voice_aar.py`. لتجهيز نسخة مستقلة: `python tools/prepare_voice_staging.py --output /path/outside/repo` ثم import وAndroid debug export من Godot مع SDK وقوالب التصدير.

فشل إعادة تصدير محلي بسبب تنافس Gradle على journal cache؛ لم يكن خطأ لعبة. احتُفظ بسجل الفشل، ثم أُعيد البناء بالتسلسل مع cache نظيف. لا يُعتد بعلامة `[DONE] export` وحدها: يُشترط exit=0 وفحص التوقيع والحزمة وDEX/JNI واختبار الموارد المجمعة. تحذيرات UID من إضافة AdMob تستخدم text resource fallback صحيحًا، وغياب adb يعني عدم وجود جهاز؛ لم تُغيّر الإضافة بسببها.

## اختبار هاتفين حقيقيين

1. اترك اللعبة الأصلية مثبتة. ثبّت `Gaming Hub Recovery Test` على الهاتفين؛ حزمته مستقلة، وتقدمه منفصل. اختبر أولًا «ضد الكمبيوتر» ثم الرجوع، ثم غرفة صديق والصور والأسئلة والشات مع الصوت مغلقًا.
2. على الجهازين سجّل model/Android/version، وشغّل جلسة `adb logcat` إن توفر كمبيوتر. مثال: `adb logcat -c` ثم `adb logcat -v threadtime > gaminghub-phone-A.log` قبل فتح اللعبة. لا تنشر السجل علنًا دون تنقيح معلوماته الشخصية.
3. أنشئ غرفة من هاتف وانضم من الآخر. اختبر رفض الميكروفون أولًا: يجب استمرار الأسئلة والشات. فعّل الصوت وامنح الإذن على الجهازين، دون سماعات، وابدأ بهما على مسافة مترين. عدّل مستوى صوت المكالمة أثناء الجلسة. اختبر كل اتجاه ثم كلامًا متزامنًا لمدة دقيقتين.
4. انتقل إلى غرفتين منفصلتين واختبر الصدى، ثم جرّب 25% و50% و75% من مستوى الصوت؛ دوّن مستوى الاستماع، الصدى، التقطيع وزمن الاستجابة. لا يمكن إثبات AEC من بيانات build أو علامات capabilities وحدها.
5. اختبر Wi-Fi واحدًا، ثم شبكتين مختلفتين، ثم Wi-Fi مقابل mobile data. بدّل Wi-Fi/mobile وأبقِ غرفة اللعب فعالة؛ تحقق من voice reconnect، ثم background لمدة 10 ثوانٍ وforeground، ثم انقطاع أقل من 90 ثانية واستعادة الغرفة.
6. ألغِ الصوت من طرف، غادر الغرفة وأعد الدخول: لا تسجيل أو إرسال دون موافقة جديدة. اختبر مكالمة هاتفية/فقد audio focus، قفل الشاشة، وسماعة سلكية اختيارية لضمان استعادة المسار.
7. كرّر على Android 10 وOPPO A31 CPH2015. شغّل 15 دقيقة وراقب ANR/crash وحرارة الجهاز والبطارية وRAM/CPU عبر Android profiler أو `adb shell dumpsys meminfo com.iroaa15.gaminghub.recoverystaging`. لم تُقَس هذه المؤشرات هنا.

## الرجوع والاستكمال في محادثة أخرى

لا تعدّل main ولا تدمج الفرع تلقائيًا. checkpoint قبل أعمال هذا التنفيذ هو `3c5ee360dd7eb70b933f7a6b1174338817d0b5ff`؛ إلغاء تثبيت حزمة recovery يرجع إلى اللعبة الأصلية دون المساس ببياناتها. commit التنفيذ الأساسي:

https://github.com/iroaa15-bot/GamingHub/commit/e086c801b6b52202620e093e8fb72248ba9d0646

المتبقي: نشر السيرفر المختبر على staging القائمة، ثم اختبار isolation عبرها، توفير TURN مناسب إن أريد دعم موثوق لشبكات NAT المقيدة، وتجربة JNI/ميكروفون/مسار السماعة/AEC/NS/AGC/إعادة الاتصال والأداء على هاتفين. لا تعتبر المشروع مكتملًا أو صالحًا للنشر الإنتاجي قبل هذه الخطوات.

## قائمة الملفات المتغيرة عن checkpoint

- `.gitignore`
- `addons/gaminghub_voice/bin/gaminghub-voice-debug.aar`
- `addons/gaminghub_voice/bin/gaminghub-voice-release.aar`
- `addons/gaminghub_voice/export_plugin.gd`
- `addons/gaminghub_voice/export_plugin.gd.uid`
- `addons/gaminghub_voice/plugin.cfg`
- `addons/gaminghub_voice/plugin.gd`
- `addons/gaminghub_voice/plugin.gd.uid`
- `docs/RECOVERY_REPORT_AR.md`
- `docs/recovery/baseline-preservation.json`
- `export_presets.cfg`
- `native/android-voice/README.md`
- `native/android-voice/build.gradle.kts`
- `native/android-voice/consumer-rules.pro`
- `native/android-voice/gradle.properties`
- `native/android-voice/gradle/wrapper/gradle-wrapper.jar`
- `native/android-voice/gradle/wrapper/gradle-wrapper.properties`
- `native/android-voice/gradlew`
- `native/android-voice/gradlew.bat`
- `native/android-voice/settings.gradle.kts`
- `native/android-voice/src/main/AndroidManifest.xml`
- `native/android-voice/src/main/java/com/gaminghub/voice/AndroidVoiceEngine.kt`
- `native/android-voice/src/main/java/com/gaminghub/voice/CapturedFrames.kt`
- `native/android-voice/src/main/java/com/gaminghub/voice/GamingHubVoicePlugin.kt`
- `native/android-voice/src/main/java/com/gaminghub/voice/Pcm16Normalizer.kt`
- `native/android-voice/src/main/java/com/gaminghub/voice/VoiceJitterBuffer.kt`
- `native/android-voice/src/main/java/com/gaminghub/voice/WebRtcVoiceEngine.kt`
- `native/android-voice/src/test/java/com/gaminghub/voice/VoiceBuffersTest.kt`
- `project.godot`
- `release/source_manifest.json`
- `release/source_manifest.py`
- `scripts/android_voice_bridge.gd`
- `scripts/android_voice_bridge.gd.uid`
- `scripts/main.gd`
- `scripts/multiplayer.gd`
- `server/server.py`
- `server/test_voice_signaling.py`
- `server/test_voice_transport.py`
- `server/test_webrtc_isolation.py`
- `tests/godot_smoke.gd`
- `tests/recovery_runtime.gd`
- `tests/recovery_runtime.gd.uid`
- `tests/run_voice_room_runtime.py`
- `tests/smoke_voice_staging.py`
- `tests/test_connection_contract.py`
- `tests/test_feedback_accessibility_v82.py`
- `tests/test_online_recovery_v86.py`
- `tests/test_prepare_voice_staging.py`
- `tests/test_recovery_preservation.py`
- `tests/test_release_v77.py`
- `tests/test_voice_preflight.py`
- `tests/voice_room_runtime.gd`
- `tests/voice_room_runtime.gd.uid`
- `tests/voice_runtime.gd`
- `tests/voice_runtime.gd.uid`
- `tests/voice_staging_profile.gd`
- `tests/voice_staging_profile.gd.uid`
- `tests/webrtc_bridge_runtime.gd`
- `tests/webrtc_bridge_runtime.gd.uid`
- `tests/webrtc_media_integration.py`
- `tests/webrtc_room_runtime.gd`
- `tests/webrtc_room_runtime.gd.uid`
- `tools/prepare_voice_staging.py`
- `tools/run_godot_gate.py`
- `tools/verify_apk_runtime.py`
- `tools/verify_staging_apk.py`
- `tools/verify_voice_aar.py`

ملفات السجلات المضافة في commit التسليم مدرجة بالكامل داخل `docs/recovery/evidence/`؛ لا تتضمن مفاتيح التوقيع الخاصة.

حفظ ملف APK الدائم تعذر بخطأ HTTP 403 في مرحلة اتصال الحفظ قبل نقل الملف. الملف المحلي المبني والمتحقق منه باقٍ في `artifacts/GamingHub-Recovery-Staging-11.7.apk` خارج المستودع، ولم يُرفع مفتاح التوقيع. يجب تنزيل APK من رابط المرفق الحالي أو إعادة حفظه لاحقًا.
