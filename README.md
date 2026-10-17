# دفتر الديون — مشروع Flutter

تطبيق أندرويد لإدارة الديون: الرئيسية، تسجيل المشتريات، كشف حساب الدائن (مع PDF ومشاركة)، والمزيد (نسخ احتياطي، مظهر فاتح/داكن، تفريغ البيانات).
البيانات تُحفظ على الهاتف فقط (SharedPreferences).

## التشغيل

1. ثبّت Flutter (3.22 أو أحدث).
2. داخل مجلد المشروع شغّل هذا الأمر مرة واحدة لتوليد مجلدات أندرويد:

   flutter create --platforms=android --project-name debt_book --org com.example .

   (لن يستبدل ملفات `lib/` أو `pubspec.yaml` الموجودة.)
3. أضف صلاحية الإنترنت إلى `android/app/src/main/AndroidManifest.xml` قبل وسم `<application`:

   <uses-permission android:name="android.permission.INTERNET"/>

   (مطلوبة لتحميل خط Cairo أول مرة في الواجهة وفي ملف PDF.)
4. `flutter pub get`
5. `flutter run`
6. للحصول على ملف APK: `flutter build apk --release` (الناتج في `build/app/outputs/flutter-apk/`).

## الهيكل

- `lib/models.dart` — الدائن والمشتريات والدفعات + دوال الأرقام.
- `lib/store.dart` — الحالة والحفظ المحلي والنسخ الاحتياطي.
- `lib/ui.dart` — الألوان والمظهر والمكونات المشتركة.
- `lib/report.dart` — إنشاء تقرير PDF.
- `lib/pages/` — الصفحات الأربع.

## ملاحظات

- العملة ثابتة في `kCurrency` داخل `models.dart` (حاليًا «ج.س»).
- النسخة الاحتياطية ملف JSON يُشارك عبر قائمة المشاركة لتخزينه خارج الهاتف، والاستعادة تختار هذا الملف.
- لم يُشغَّل المشروع في بيئة الإنشاء (Flutter غير متوفر فيها)؛ إن ظهر خطأ عند البناء أرسله لي.
