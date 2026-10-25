# Gaming Hub — تسليم دمج الصوت Build120

الفرع integration/gaminghub-games-services-20261025؛ البداية2c001c32b5d105051d66653b9bd4503892d4901a. لم يتغيرmain أوالإنتاج أوserver/server.py أوdata/network_config.json أوالصور أوالتوليد اليومي أوmonetization أومعرفاتAdMob.

## DONE / PASS

- إعادة استخدام33ملفًا من إضافة الصوت الأصلية عندef357d9442952d090a753d2bc3ea84f2b1f7d30a، دون إعادة كتابةKotlin أوإعادة بناءAAR. بصمتاDebug/Release مطابقتان للمصدر:b597cf4a7f570440097c0022d0444a1f5b6dc19c61bdd1f0efbd34c503b20fb3. محفوظة معالجةonMainResume وpermission وaudiofocus وAEC/NS/AGC والمخازن والموافقة وتسلسلPCMv2.
- دمج جسرالصوت وواجهةالغرف السابقة بتعديلات منتقاة ومراجعة؛ إصلاح خطأ parsing مؤكد في نوعbridge_ready داخل تشخيص الصوت. الإنتاج لم يُستبدل. server/voice_validation_server.py نسخةfixture معزولة للاختبار من فرعالصوت فقط، وليست مدخل الإنتاج.
- VOICE_RUNTIME_PASS: الإذن والموافقة والحالات غيرالمتزامنة وإيقاف الخلفية ورفضالحزم القديمة وعزل أخطاء اللعبة.
- VOICE_ROOM_RUNTIME_PASS: عميلان منmultiplayer.gd الفعلي +WebSocket محلي حقيقي، صوتPCM مولد ثنائي الاتجاه، إنشاء/انضمام/استعادةtoken وموافقة جديدة ومغادرة. حدAndroid/JNI محاكى؛ ليس سماعًا من ميكروفون هاتف.
- STAGING_SMOKE_PASS علىwss://gaminghub-voice-staging.onrender.com الموجود مسبقًا: اتصالوغرفة وانضمام وموافقة وPCM في الاتجاهين ورفض التكرار وإلغاءالموافقة. لم يُنشر أو يُعدل السيرفر.
- PARTY_MAIN_APP_RUNTIME failures=0: فتحPartyRoom منزر قائمةالألعاب داخلMain الفعلي، ثم إنشاء/انضمام ولعب دور ونتيجة وشات واستعادة. اختبارGodot لواجهة التطبيق الفعلية معWebSocket محلي، وليس تثبيتAPK علىAndroid. اختبارات6لاعبين و15جولة السابقة لم تتكرر لأن محركPartyلم يتغير.
- APK120:package com.iroaa15.gaminghub؛version120/12.0-rc1؛target36/min24/arm64. apksignerV2 ناجح ونفس شهادةDebug119؛ لا مفتاح جديد. DEX يحتويGamingHubVoicePlugin وAndroidVoiceEngine وPoingGodotAdMob وRewardedAd وConsentInformation؛ بصمة مصدرالصوت داخلAPK مطابقة. AAB يحتويكذلك الإضافة.
- AdMob: معرّفات الإنتاج وملفات إعدادالإعلانات لم تتغير. الجسر يتضمن وحدةrewarded اختبارية فقط وحراسة العمر وUMP وإتمامالمكافأة الأصلية. وجودSDKداخلAPK لا يثبت عرضإعلان علىجهاز، ولم تُطلب إعلانات إنتاجية.

## BLOCKED / غير متحقق

- لم يوجد هاتف فيadb. المحاكيMedium_Phone_API37 موجود، لكنaccel-check أعاد6 وعدمجاهزيةWHP؛ لم نغير إعداداتWindows أوبياناتAVD ولم نثبت نجاح تشغيلAPK عليه. واجهةPartyداخلبناءAndroid موجودة وقابلةللوصولحسبتدفقMain، لكن تشغيلها باللمس علىAndroid يحتاج جهازًا.
- يلزم هاتفان: permissionرفض/قبول،onMainResume،حديثمتزامن دونسماعات،الصدىوالمستوىوAEC/NS/AGC الفعلية،Bluetooth والمقاطعات والخلفيةوالشبكةوالاستعادة. إضافاتالصوتالأصليةللعبالثنائي مدمجة؛ لم نبتكر صوتًا جماعيًا جديدًا لPartyRoom.
- endpointالإنتاج لم يتغير. عميلالصوت يحتاجprotocol2؛ ثبت عمله علىstaging، وليس توافقه معكلسيرفرإنتاج. يمكن تحديدعنوانstaging منإعداداتالاتصالالمتقدمة. خدماتPartyوPhotoDuel لم تُنشر تلقائيًا.
- لم يوجد مفتاحرفع أصلي فيمجلداتGamingHub المحلية ونسخDownloads المسماةGamingHub. إعداداتreleaseالموجودة فينسخةv9.3 تحويkeystore/release وrelease_user فارغين. متغيراتGODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD غائبة. الناقص: ملفمفتاحالرفعالأصلي ومساره وalias ومصدرآمن لكلمةمروره. لا كلماتمرورطُلبت أوعُرضت، ولاkeystoreجديدأُنشئ.
- GamingHub-120-unsigned.aab موجود وغيرموقّع؛ ليسAABجاهزًاللنشر. يحتاجالمفتاحالقائم وفحصbundletool/Play والاختباراتالهاتفية. APKDebug ليستحديثًاللنسخةالمنشورة؛ لا تحذفالنسخةأوبياناتها لتثبيته.
- AdMobتهيئةSDK/UMPوعرضإعلانالاختباروالمكافأة علىAndroid مازالتاختباراتجهاز. لا ندعيحل مشكلةصوتأوإعلاناتفعلية دونالدليل.

## استكمال مباشر

ملفاتالأدلة فيrelease/validation_voice120. لا تكرر اختبارات119 أوصور200. بعدتوفرجهازين اختبرAPK120 الحالي. لا تعِدبناءAARالأصلي دونتغييرمصدره. التوقيعالنهائي فقطعندتوفرمفتاحالرفعالقائم؛ ممنوعالنشرأوالدمجدونموافقة.

- GamingHub-120-debug.apk: 186720676 bytes؛ SHA256 `09ba2c8e07e7f689afa35b6f1828106cd6c3ca7acb5f0e2a30321e74caa36014`
- GamingHub-120-unsigned.aab: 130699161 bytes؛ SHA256 `2597737cc5faa853278b43c564fd5fcc49b79275ffb1ca35f941d4641fb0aa1d`
