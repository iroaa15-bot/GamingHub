# إعداد الحسابات والإدارة — محلي / Staging فقط

## الحالة الفعلية
خدمة Python مستقلة على 127.0.0.1 فقط، SQLite، وجلسات يوم واحد. ليست خدمة إنتاجية ولا تدعم HTTPS مباشرة. لا يتم استيراد سيرفرات اللعبة أو تغييرها. حساب Gaming Hub المحلي يعمل بكلمة مرور؛ البريد غير موثّق ورسائل استعادة كلمة المرور غير متاحة. OAuth غير مُنفذ بمزود حقيقي: واجهات callback محجوبة503 وبنية Federation وحدود الربط فقط موجودة. لا يكفي ملء IDs لتفعيل أزرار Google/Facebook؛ يلزم توصيل SDK رسمي واختبارات tokens/callbacks.

## تشغيل محلي
من جذر المستودع:
`python services/player_portal/service.py --db <PRIVATE_DATA_DIRECTORY>/players.sqlite --port 8879`
ثم افتح `http://127.0.0.1:8879/`.
لا تضع SQLite أو أسرار التشغيل داخل Git. الخدمة لا تستمع على0.0.0.0 ولا تمنح CORS. Cookie محلي HttpOnly/SameSite=Strict؛ يجب Secure/TLS وتحديد origin والمهلات والنسخ الاحتياطي وإدارة الأسرار ومراجعة أمنية قبل أي استضافة خارجية. لا تعرّض خادم HTTP المحلي للإنترنت.

لتجربة Godot المحلي استخدم `-- --player-portal=http://127.0.0.1:8879`، أو نفس الوسيط في تشغيل Android التشخيصي بعد `adb -P 5038 reverse tcp:8879 tcp:8879`. هذا جسر USB محلي مؤقت، وليس نشرًا. الوضع الافتراضي لا يتصل بخدمة الحسابات، والضيف المحلي يعمل كما كان. الجلسة في الذاكرة فقط؛ يلزم تسجيل دخول جديد بعد إغلاق العملية. مزامنة xp/wins/matches/picture_wins شخصية وغير مصنفة؛ ليست نتائج موثوقة من خادم اللعبة ولا مزامنة كاملة لكل الإعدادات والإنجازات. السجل المحلي الأصلي لا يُحذف.

## أول Super Admin
1. أنشئ حساب Gaming Hub محليًا، وسجّل معرفه من /me. تحقق بنفسك من هوية مالكه؛ لا يكفي ادعاء البريد.
2. على جهاز الخدمة وبصلاحية كتابة ملف قاعدة البيانات فقط، بعد إيقافها/أخذ نسخة احتياطية:
`python services/player_portal/service.py --db <PRIVATE_DB> --grant-first-super-admin <EXISTING_REGISTERED_USER_ID> --confirm-first-admin`
3. الأمر لا ينشئ مستخدمًا أو كلمة مرور، ويرفض الضيف أو الحساب الموقوف أو وجود مسؤول سابق. يسجل الإسناد في audit. لا يوجد HTTP endpoint لمنح الدور أو مستخدم إدارة افتراضي.
4. سجّل خروجًا ودخولًا/حدّث /me؛ يظهر مدخل الإدارة داخل اللعبة فقط إذا أعاد الخادم role=super_admin. المتصفح يعيد المصادقة؛ الصلاحية تُفحص في الخادم لكل طلب حتى لو تم تعديل واجهة التطبيق.
لا تم تنفيذ إسناد مسؤول حقيقي هنا؛ الاختبارات تستخدم قواعد مؤقتة وحسابات اختبار فقط. منح صلاحيات الإنتاج يحتاج هوية معتمدة وموافقة منفصلة.

## Google: المعرفات المطلوبة بالضبط
- Android OAuth Client ID للاختبار: package `com.iroaa15.gaminghub` + SHA-1 لشهادة APK التجريبي الحالي.
- Android OAuth Client ID لتوزيع Google Play: نفس package + SHA-1 لشهادة **App Signing** من Play Console، وليس افتراض شهادة Upload Key. توقيع الرفع الأصلي ما زال عائقًا مستقلًا.
- Web Application OAuth Client ID للخادم، في مشروع Google Cloud نفسه، لاستخدامه كـaudience عند التحقق من ID token. Android Client ID لا يستبدل Web Client ID.
- إعداد Branding/Consent، سياسة الخصوصية، الدعم، مستخدمي الاختبار والموافقة المطلوبة لدى Google.
مصادر Google الرسمية: https://codelabs.developers.google.com/sign-in-with-google-android وhttps://developers.google.com/identity/sign-in/android/backend-auth وhttps://developers.google.com/android/guides/client-auth . يجب التحقق بالخادم من التوقيع وaud/iss/exp وعدم الثقة بمعرف مستخدم مرسل من التطبيق؛ استخدم مكتبة Google الرسمية عند توصيل المزود. الربط يعتمد provider+subject موثّقين ولا يدمج حسابين اعتمادًا على البريد وحده.

## HTTPS callbacks المحجوزة للتكامل اللاحق
لم يُعتمد اسم مضيف للحسابات. هذه قوالب وليست روابط منشورة:
- `https://<APPROVED_ACCOUNT_HOST>/oauth/google/callback`
- `https://<APPROVED_ACCOUNT_HOST>/oauth/facebook/callback`
سجل URI النهائي المطابق تمامًا لدى المزود بعد اعتماد المضيف. Google Native ID-token flow لا يحتاج callback متصفح ذاته؛ URI أعلاه لتكامل authorization-code web المقترح، وليس ادعاء أنه يعمل الآن. عند تنفيذه: state/nonce أحادية الاستخدام بمهلة وPKCE والتحقق من issuer/audience/expiry، وعدم إرسال أسرار إلى Android أو حفظ tokens في الروابط/السجلات.

## Facebook
يلزم Meta App ID حقيقي وإعداد Facebook Login للتطبيق، Android package/activity وتوقيعات الاختبار وPlay، وValid OAuth Redirect URI النهائي، وسياسة الخصوصية وحذف البيانات، والمستخدمون الاختباريون/المراجعات التي تتطلبها Meta. App Secret يظل في مخزن أسرار الخادم فقط، لا في APK أو Git أو الدردشة. مرجع رسمي: https://developers.facebook.com/docs/facebook-login/guides/advanced/manual-flow/ (تعذر جلبه أثناء العمل بسببHTTP429؛ تُراجع حقول Meta النهائية قبل التفعيل).

## حدود الإدارة
واجهة عربية متجاوبة للصور الأصلية200، تحرير مسودات photo/category/question/settings، إدارة إيقاف الحسابات، حالة هذه الخدمة وعدّادات حقيقية وسجل تدقيق. الأسئلة تتطلب ترجمة ar/en/tr وخيارات فريدة وصحيحًا واحدًا وaliases لا تصطدم بالمشتتات. كل تعديلات المحتوى داخل SQLite كمسودات فقط؛ لا تغير أصول اللعبة أو مولد اليوميات أو سيرفرات الإنتاج. حسابات الخدمة لا ترتبط بهوية غرف WSS تلقائيًا. دعوة الصديق تخزن الكود ولا تثبت أن الغرفة موجودة أو تتجاوز تحقق سيرفرها. لا يتم الاستعلام عن حالة الإنتاج أو الادعاء بأنها سليمة.
