# نتائج نشر staging والتحقق اللاحق

نُشر commit `e10537da4205673ea2cecb3c1c3957b485f63766` على الخدمة القائمة `gaminghub-voice-staging` فقط، بمعرّف `srv-dbb7i1dg1s2s738gccbg`. النشر `dep-dbbtffgm7kps73d6n4o0` بلغ `live` بعد 28.5 ثانية. وقت الانتهاء المسجل من Render: `2026-10-20T21:06:35.288998Z`، الموافق 21 أكتوبر بتوقيت القاهرة. لا تمثل ساعة العرض PDT في Dashboard توقيت المستخدم.

[صفحة النشر](https://dashboard.render.com/web/srv-dbb7i1dg1s2s738gccbg/deploys/dep-dbbtffgm7kps73d6n4o0)

استُخدم Manual Deploy → Deploy a specific commit؛ لم يلزم تغيير فرع الخدمة. بقي `autoDeploy=no` والخطة `free`. لم يُستخدم GitHub Actions أو يُنشأ أي سيرفر. لم تُنشر تغييرات السجلات والاختبار المضافة بعد e10537d على Render.

## اختبارات فعلية بعد حالة live

| الأمر | النتيجة المؤكدة |
| --- | --- |
| `python tests/smoke_voice_staging.py` | PASS: ping، إنشاء غرفة والانضمام، موافقة الطرفين، PCM مولد في الاتجاهين، رفض duplicate، إلغاء الصوت مع استمرار heartbeat. |
| `python tests/webrtc_media_integration.py --staging` | PASS: إشارات SDP عبر staging الفعلية، وصوت Opus/SRTP على loopback UDP محليًا؛ 30 إطارًا غير صامت في كل اتجاه. رفض ICE تالف بخطأ scope=voice مع استمرار ping. |
| `python tests/staging_recovery_transport.py` | PASS: SDP وICE في الاتجاهين، إرسال 501 ICE ثم ping وحركة سؤال حقيقية وبقاء الغرفة. استعادة الغرفة والتاريخ والدور باستخدام resume token، رفض token خاطئ وتدوير token الصحيح، منع الصوت حتى تجديد موافقة الطرفين، epoch جديد، opt-out ومغادرة سليمة. |

في تجربة burst كانت المدة من بدء إرسال 501 ICE حتى استقبال pong تساوي 0.215 ثانية. هذه عينة اختبار واحدة عبر بيئة الاختبار، وليست ضمانًا لزمن استجابة هاتف أو شبكة أخرى. dropping أو تأجيل بعض ICE أثناء الاندفاع مسموح؛ الفحص لا يدعي توصيل جميع الإشارات الـ501، بل يثبت بقاء اتصال اللعب وحركة السؤال.

السجلات الخام في الملفات الثلاثة المجاورة. لا تحتوي resume tokens أو كلمات مرور أو بيانات TURN السرية. اختبارات WebSocket أنشأت غرفًا تجريبية ثم غادرتها؛ لا اختبار على غرف إنتاجية. سكربت `staging_recovery_transport.py` محصور بعنوان staging ولا يدخل ضمن اكتشاف اختبارات unittest تلقائيًا.

## المشكلات والحدود الباقية

- `turn_configured=false` في الرد الفعلي. لم يُختبر TURN أو اجتياز NAT بين شبكتين فعليتين؛ بعض شبكات المحمول قد تمنع الاتصال المباشر.
- لم يتوفر أي هاتف Android حقيقي؛ جودة الميكروفون والسماعة والصدى وAEC/NS/AGC، JNI، تغيير شبكة الهاتف، أداء OPPO A31 والبطارية **غير معتمدة**. نجاح إشارات السيرفر وmedia المحلية لا يساوي نجاح الصوت بين هاتفين.
- سجل النشر يعرض `unsupported HTTP method; expected GET; got HEAD` و`missing Connection header` ثم `InvalidMessage/InvalidUpgrade`. المؤكد أن السيرفر يرفض HTTP/طلبات لا تطلب WebSocket Upgrade؛ مصدر هذه الطلبات لم يُثبت. النشر بقي live واختبارات WebSocket والغرف أعلاه نجحت. هذه مشكلة توافق/ضجيج سجلات متبقية؛ لم يُغيّر كود e10537d أو تُخفَ الرسائل أو يُنشر patch إضافي تحت تفويض نشر commit محدد.
- اختبار peer بطيء فعليًا عبر شبكة هاتف، مدة جلسة طويلة، وAndroid background/audio focus ما زال يحتاج أجهزة؛ الاختبار المحلي السابق للـslow-peer يبقى محليًا.

## حماية النسخة الحالية والرجوع

أُعيد التحقق للقراءة فقط: main ما زال `39162256ccbea20151b6bb66a129baad1fd0bd42`. إعدادات خدمة الإنتاج `gaminghub-multiplayer` لم تتغير (`updatedAt=2026-10-19T08:00:39.127287Z`). metadata في `deployment.json`.

checkpoint النشر السابق للرجوع عند الحاجة هو `2aba3b3c5724a0d9f1a511632474706d11ef7905`، النشر `dep-dbb8bd0u01pc73dmv47g`. لا تنفذ rollback تلقائيًا ولا تنقل إلى main. لا حاجة لبناء APK جديد بسبب نشر نفس السيرفر المتوافق؛ APK التجريبي السابق يشير بالفعل إلى خدمة staging القائمة. اترك حزمة الإنتاج مثبتة.

الخطوة التالية: اختبار النسخة التجريبية السابقة على هاتفين Android بدون سماعات: اللعب والصور أولًا والصوت مغلق، ثم إذن الميكروفون وموافقة الطرفين، ثم كلام في الاتجاهين ومتزامن، ثم Wi-Fi/mobile وbackground/foreground وإلغاء الصوت. سجّل model/Android وlogcat والأعراض، ولا تعتبر نجاح الغرفة دليلًا على نجاح الصوت.
