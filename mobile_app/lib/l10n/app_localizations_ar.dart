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
      'You must verify your email before you can continue. Please check your inbox (and spam) and verify your email.';

  @override
  String get errorUnauthorized =>
      'Invalid email or password. Please try again.';

  @override
  String get errorForbidden =>
      'This account is not allowed to login yet. Please contact support.';

  @override
  String get errorNetwork => 'Network error. Please try again later.';

  @override
  String errorRoleMismatch(String role, String targetRole) {
    return 'This email is registered as a $role, not a $targetRole. Please sign in from the correct portal or register a new account.';
  }

  @override
  String get errorOnboardingNeeded =>
      'Account needs onboarding. Please complete your registration profile.';

  @override
  String get errorLoginNoToken => 'Login failed: No token returned.';

  @override
  String get infoVerificationResent =>
      'Verification email resent! Please check your inbox (and spam).';

  @override
  String get errorResendFailed => 'Couldn\'t resend verification email.';

  @override
  String errorResendException(String error) {
    return 'Error resending email: $error';
  }

  @override
  String get labelAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get btnSignUp => 'Sign up';

  @override
  String get labelNoAccount => 'Don\'t have an account? ';

  @override
  String get dialogAlmostThere => 'Almost there!';

  @override
  String get infoRegistrationSuccess =>
      'Registration successful.\n\nPlease check your email inbox (and spam) and verify your email to continue.';

  @override
  String get btnOkay => 'Okay';

  @override
  String errorRegistrationFailed(String error) {
    return 'Registration failed (exception): $error';
  }

  @override
  String get errorAgreeTerms => 'You must agree to terms of service.';

  @override
  String get errorInvalidEmail => 'Invalid email format';

  @override
  String get errorPasswordsNotMatch => 'Passwords do not match';

  @override
  String get btnFacebook => 'Facebook';

  @override
  String get labelAlreadyAccount => 'Already have an account? ';

  @override
  String get btnSignInSmall => 'Sign in';

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
