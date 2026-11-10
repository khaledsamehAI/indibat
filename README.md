# منصة انضباط · INDIBAT

منصة الحضور والسلوك لمدرسة رأس الخيمة الحلقة الثالثة بنين.

- **المنصة:** `index.html` (تعمل بعد إضافة رابط Supabase والمفتاح العام في `ATHAR_CONFIG` أعلى الملف).
- **نسخة العرض:** `demo.html` (بيانات وهمية تُحفظ في المتصفح فقط · الدخول: `admin@moe.sch.ae` / `demo1234`).
- **إعداد قاعدة البيانات:** شغّل `indibat-setup.sql` في Supabase (SQL Editor)، وفعّل Confirm email من Authentication.
- **كود التحقق:** من Authentication ← Email Templates ← Confirm signup، ضع `{{ .Token }}` في نص الرسالة ليصل كود من 6 أرقام.

التسجيل بالبريد الوزاري فقط (`@moe.sch.ae`)، ويوافق مسؤول النظام على كل حساب ويحدد صفته الوظيفية.
