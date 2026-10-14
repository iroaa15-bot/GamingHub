# Gaming Hub v10.3 — AdMob Diagnostics (تحضير آمن)

## التغييرات الفعلية
- إضافة `integration_diagnostics()` في `scripts/ad_manager.gd` لمعرفة حالة SDK والموافقة والفئة العمرية ووضع الاختبار دون تمكين إعلانات.
- إضافة `monetization/verify_v103.py` لفحص الإعدادات ومنع تشغيل الإعلانات قبل تجهيز SDK.
- تحديث رقم تكامل الإعلانات إلى 10.3. بقية ملفات اللعبة مأخوذة من v10.2.

## طريقة الفحص
`python3 monetization/verify_v103.py`

## ما لم يتم إنجازه
لم يتم تركيب Google Mobile Ads Android SDK أو UMP ولم يتم بناء APK أو اختباره على هاتف. الإعلانات الحقيقية **معطلة**. لتفعيل اختبار Android، يلزم إضافة Godot Android plugin موثوقة ومتوافقة مع نسخة Godot، وتوصيل callback الأصلي، وتجربة UMP وسياسات الأطفال عمليًا. لا تغيّر mode قبل إكمال ذلك.
