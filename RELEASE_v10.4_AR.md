# Gaming Hub v10.4 — Native Integration Contract

تمت إضافة عقد توصيل واضح للـ Android native adapter، ودالة `get_android_test_ids()`، وفاحص إعدادات مستقل `monetization/verify_v104.py`.

**الحدود:** لم يتم تركيب Google Mobile Ads SDK أو UMP، ولم يتم بناء APK أو اختبار إعلانات على هاتف. الإعلانات معطلة عمدًا، وملفات اللعبة السابقة محفوظة.

التشغيل: `python3 monetization/verify_v104.py`
راجع `monetization/ANDROID_NATIVE_BRIDGE_CONTRACT.md` قبل أي دمج أصلي.
