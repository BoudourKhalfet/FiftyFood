// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'FiftyFood';

  @override
  String get welcome => 'مرحباً بكم في FiftyFood';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get french => 'الفرنسية';

  @override
  String get arabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get btnGetStarted => 'ابدأ الآن';

  @override
  String get btnSignIn => 'تسجيل الدخول';

  @override
  String get signInWelcome => 'مرحباً بعودتك';

  @override
  String get signInSubtitle => 'سجل دخولك للاستمرار في توفير الوجبات اللذيذة';

  @override
  String get labelEmail => 'البريد الإلكتروني';

  @override
  String get labelPassword => 'كلمة المرور';

  @override
  String get btnForgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get labelOrContinueWith => 'أو المتابعة باستخدام';

  @override
  String get btnGoogle => 'جوجل';

  @override
  String get errorRequired => 'مطلوب';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.';

  @override
  String get infoVerificationSent => 'تم إعادة إرسال بريد التحقق.';

  @override
  String get btnResendVerification => 'إعادة إرسال بريد التحقق';

  @override
  String get btnJoinAsClient => 'انضم كعميل';

  @override
  String get signupTitle => 'إنشاء حسابك';

  @override
  String get signupSubtitle => 'ابدأ في توفير الطعام والمال في دقائق';

  @override
  String get labelConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get errorPasswordLength => 'يجب أن تكون 8 أحرف على الأقل';

  @override
  String get labelAgreedTerms => 'أوافق على شروط الخدمة وسياسة الخصوصية';

  @override
  String get btnContinue => 'متابعة';

  @override
  String get titleAvailableOffers => 'العروض المتاحة';

  @override
  String get hintSearchOffers => 'البحث عن مطاعم أو أطباق.';

  @override
  String get infoLoadingOffers => 'جاري تحميل العروض...';

  @override
  String get errorLoadOffers => 'فشل تحميل العروض. حاول مرة أخرى.';

  @override
  String get infoNoOrders => 'لا توجد طلبات بعد.';

  @override
  String get btnTrackDelivery => 'تتبع الشحنة';

  @override
  String get btnJoinAsPartner => 'انضم كشريك';

  @override
  String get labelVerifiedRestaurants => 'مطاعم موثوقة';

  @override
  String get roleOwner => 'صاحب العمل';

  @override
  String get roleManager => 'مدير';

  @override
  String get btnSaveFinish => 'حفظ وإنهاء';

  @override
  String get btnSkip => 'تخطي الآن';

  @override
  String get titleScanQR => 'التحقق من رمز QR للعميل';

  @override
  String get btnPublishOffer => 'نشر عرض';

  @override
  String get labelPickupTime => 'وقت الاستلام';

  @override
  String get labelCategories => 'الفئات';

  @override
  String get btnJoinAsDeliverer => 'انضم كعامل توصيل';

  @override
  String get btnBackToHome => '← العودة للرئيسية';

  @override
  String get errorEmailNotVerified =>
      'يجب التحقق من بريدك الإلكتروني قبل المتابعة. يرجى مراجعة صندوق الوارد (والبريد المزعج) والتحقق من بريدك.';

  @override
  String get errorUnauthorized =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.';

  @override
  String get errorForbidden =>
      'لا يُسمح لهذا الحساب بتسجيل الدخول بعد. يرجى التواصل مع الدعم.';

  @override
  String get errorAccountDoesNotExist => 'هذا الحساب غير موجود.';

  @override
  String get errorAccountSuspended => 'تم تعليق حسابك.';

  @override
  String get errorNetwork => 'خطأ في الشبكة. يرجى المحاولة مرة أخرى لاحقاً.';

  @override
  String errorRoleMismatch(String role, String targetRole) {
    return 'هذا البريد الإلكتروني مسجل كـ $role، وليس كـ $targetRole. يرجى تسجيل الدخول من البوابة الصحيحة أو إنشاء حساب جديد.';
  }

  @override
  String get errorOnboardingNeeded =>
      'الحساب يحتاج إلى إعداد. يرجى إكمال ملف تعريف التسجيل.';

  @override
  String get errorLoginNoToken => 'فشل تسجيل الدخول: لم يتم إرجاع أي رمز.';

  @override
  String get infoVerificationResent =>
      'تم إعادة إرسال بريد التحقق! يرجى مراجعة صندوق الوارد (والبريد المزعج).';

  @override
  String get errorResendFailed => 'تعذّر إعادة إرسال بريد التحقق.';

  @override
  String errorResendException(String error) {
    return 'خطأ في إعادة إرسال البريد: $error';
  }

  @override
  String get labelAlreadyHaveAccount => 'لديك حساب بالفعل؟ ';

  @override
  String get btnSignUp => 'إنشاء حساب';

  @override
  String get labelNoAccount => 'ليس لديك حساب؟ ';

  @override
  String get dialogAlmostThere => 'على وشك الانتهاء!';

  @override
  String get infoRegistrationSuccess =>
      'تم التسجيل بنجاح.\n\nيرجى مراجعة صندوق الوارد (والبريد المزعج) والتحقق من بريدك الإلكتروني للمتابعة.';

  @override
  String get btnOkay => 'حسناً';

  @override
  String errorRegistrationFailed(String error) {
    return 'فشل التسجيل (استثناء): $error';
  }

  @override
  String get errorAgreeTerms => 'يجب الموافقة على شروط الخدمة.';

  @override
  String get errorInvalidEmail => 'صيغة البريد الإلكتروني غير صحيحة';

  @override
  String get errorPasswordsNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get btnFacebook => 'فيسبوك';

  @override
  String get labelAlreadyAccount => 'لديك حساب بالفعل؟ ';

  @override
  String get btnSignInSmall => 'تسجيل الدخول';

  @override
  String get labelDescription => 'الوصف';

  @override
  String get hintDescription =>
      'مثال: كيس مفاجئات من المعكرونة، تحديد الشيف...';

  @override
  String get btnSelectCategories => 'حدد الفئات';

  @override
  String get labelOriginalPrice => 'السعر الأصلي (€)';

  @override
  String get labelDiscountedPrice => 'السعر المخفض (€)';

  @override
  String get labelQuantity => 'الكمية';

  @override
  String get labelVisibility => 'الرؤية';

  @override
  String get labelDeliveryAvailable => 'التوصيل متاح';

  @override
  String get btnCreateOffer => 'إنشاء عرض';

  @override
  String get btnPublish => 'نشر';
}
