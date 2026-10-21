# تشغيل التجربة المعزولة

لا يتطلب التشغيل GitHub Actions أو خدمة مدفوعة أو تعديل Render.

من جذر المستودع على حاسوبك:

```sh
python -m pip install -r server/requirements.txt
cd experiments/colyseus-room-poc
npm ci --ignore-scripts
npm run preflight
npm test
npm run start:android:lan
```

الأمر الأخير يشغّل Python على `127.0.0.1:8765` وColyseus على منفذ loopback
داخلي، وبوابة الهاتف على `0.0.0.0:2568/gaminghub`. استخدمه فقط على Wi-Fi خاص
موثوق، واسمح بالمنفذ 2568 في جدار الحماية للشبكة الخاصة. لا تستخدم port forwarding.
التشغيل دون `--lan`، باستخدام `npm run start:android`، يبقى على loopback.

على الهاتفين: افتح نسخة `Gaming Hub Colyseus Test`، ثم «العب مع صديق»، ثم
«إعدادات الاتصال (متقدمة)». اكتب على الاثنين `ws://عنوان-الحاسوب:2568/gaminghub`
واضغط الاتصال اليدوي. يجب أن يكون الحاسوب والهاتفان على الشبكة نفسها.
أنشئ غرفة على الأول وانضم بكودها على الثاني؛ واختبر «منافس عشوائي» بصورة منفصلة.

الاتصال الافتراضي في APK يستخدم خدمة `gaminghub-voice-staging` الحالية، وهي
خادم Python السابق؛ اختبار Colyseus يتطلب تغيير العنوان إلى البوابة المحلية.
المحتوى اليومي في APK التجريبي موجّه إلى staging أيضًا. النسخة الأصلية وبياناتها منفصلتان.

لإعادة الاختبارات الإضافية من جذر المستودع بعد تثبيت Godot 4.5.1 وaiortc:

```sh
python -m pip install aiortc numpy
python tests/run_colyseus_runtime.py --godot /path/to/godot --output /tmp/colyseus-results
python tools/run_godot_gate.py --godot /path/to/godot --project . --script tests/recovery_runtime.gd --marker RECOVERY_RUNTIME_PASS --log /tmp/recovery.log
python tests/run_checks.py
```

`test:offline` يستخدم Room مقلّدًا؛ لا يعتبر إثبات WebSocket. اختبارات `npm test`
و`run_colyseus_runtime.py` تشغّل اتصالات حقيقية. اختبار Godot يقلّد JNI فقط؛ اختبار
aiortc ينقل صوتًا مولّدًا فعليًا عبر UDP، ولا يقيس ميكروفون الهاتف أو مستوى سماعته.

إذا عاد `EAI_AGAIN`، تحقق من DNS ومن إعدادات proxy الخاصة ببيئتك ثم أعد
`npm ci --ignore-scripts`. لا تغيّر TLS ولا تستخدم Actions لتجاوز المشكلة.
