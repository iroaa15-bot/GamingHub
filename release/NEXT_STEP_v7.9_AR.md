# Gaming Hub v7.9 — مرحلة بناء Android

## تم تنفيذه
- إضافة أوامر بناء فعلية لويندوز `release/build_android.ps1` ولينكس/ماك `release/build_android.sh`.
- أوامر البناء توقف العملية عند فشل اختبار Python أو استيراد Godot أو تشغيل المشهد.
- فحص بنية APK/AAB وعدم اعتبار ملف فارغ أو مزيف إصدارًا جاهزًا.
- تغيير معرف الحزمة من `com.gaminghub.prototype` إلى `com.iroaa15.gaminghub` **مبدئيًا**. راجع معرف الحزمة قبل أول رفع إلى Google Play، لأنه يصبح ثابتًا للتطبيق.
- منع إدراج ملفات مفاتيح التوقيع والنسخ المبنية في Git.
- لا يتم استخدام بيانات اعتماد افتراضية أو إنشاء مفاتيح توقيع نيابة عن المستخدم.

## تنفيذ على ويندوز
1. ثبّت Godot 4.5.1 + Android export templates، وAndroid SDK وJava JDK كما توضح وثائق Godot.
2. افتح PowerShell في مجلد المشروع وشغّل `./release/build_android.ps1 -Mode debug -Godot "C:/path/to/Godot_v4.5.1-stable_win64_console.exe"`.
3. إذا نجح الأمر ستحصل على `build/GamingHub-debug.apk`.
4. ثبّت APK على هاتفين واختبر الأونلاين وشاشة البداية، وسجّل الأخطاء والـ FPS.
5. ملف AAB الموقّع يحتاج مفاتيح إصدار خاصة بك؛ لا ترفع كلمة المرور إلى GitHub.

## موانع النشر
لم يُختبر تشغيل Godot/Android في بيئة البناء الحالية لعدم توفر Godot أو Android SDK. ولا توجد إعلانات AdMob حقيقية بعد. سياسة الخصوصية وتصنيف الأعمار ومراجعة Google Play لازمة قبل الإطلاق.

- تم تجهيز preset منفصل باسم `Android Release` لإخراج AAB عبر Gradle. يلزم تثبيت Gradle build template داخل Godot قبل بناء الإصدار.
