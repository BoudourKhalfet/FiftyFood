// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FiftyFood';

  @override
  String get welcome => 'Welcome to FiftyFood';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get arabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get btnGetStarted => 'Get Started';

  @override
  String get btnSignIn => 'Sign In';

  @override
  String get signInWelcome => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue saving delicious meals';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelPassword => 'Password';

  @override
  String get btnForgotPassword => 'Forgot password?';

  @override
  String get labelOrContinueWith => 'OR CONTINUE WITH';

  @override
  String get btnGoogle => 'Google';

  @override
  String get errorRequired => 'Required';

  @override
  String get errorInvalidCredentials =>
      'Invalid email or password. Please try again.';

  @override
  String get infoVerificationSent => 'Verification email resent.';

  @override
  String get btnResendVerification => 'Resend Verification Email';

  @override
  String get btnJoinAsClient => 'Join as Client';

  @override
  String get signupTitle => 'Create your account';

  @override
  String get signupSubtitle => 'Start saving food and money in minutes';

  @override
  String get labelConfirmPassword => 'Confirm password';

  @override
  String get errorPasswordLength => 'Must be at least 8 characters';

  @override
  String get labelAgreedTerms =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get btnContinue => 'Continue';

  @override
  String get titleAvailableOffers => 'Available Offers';

  @override
  String get hintSearchOffers => 'Search restaurants or dishes.';

  @override
  String get infoLoadingOffers => 'Loading offers...';

  @override
  String get errorLoadOffers => 'Failed to load offers. Try again.';

  @override
  String get infoNoOrders => 'No orders yet.';

  @override
  String get btnTrackDelivery => 'Track Delivery';

  @override
  String get btnJoinAsPartner => 'Join as Partner';

  @override
  String get labelVerifiedRestaurants => 'Verified Restaurants';

  @override
  String get roleOwner => 'OWNER';

  @override
  String get roleManager => 'MANAGER';

  @override
  String get btnSaveFinish => 'Save & Finish';

  @override
  String get btnSkip => 'Skip for now';

  @override
  String get titleScanQR => 'Validate Customer QR Code';

  @override
  String get btnPublishOffer => 'Publish Offer';

  @override
  String get labelPickupTime => 'Pickup Time';

  @override
  String get labelCategories => 'Categories';

  @override
  String get btnJoinAsDeliverer => 'Join as Deliverer';

  @override
  String get btnBackToHome => '← Back to Home';

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
  String get labelDescription => 'Description';

  @override
  String get hintDescription => 'e.g. Surprise pasta bag, Chef\'s selection...';

  @override
  String get btnSelectCategories => 'Select categories';

  @override
  String get labelOriginalPrice => 'Original Price (€)';

  @override
  String get labelDiscountedPrice => 'Discounted Price (€)';

  @override
  String get labelQuantity => 'Quantity';

  @override
  String get labelVisibility => 'Visibility';

  @override
  String get labelDeliveryAvailable => 'Delivery Available';

  @override
  String get btnCreateOffer => 'Create Offer';

  @override
  String get btnPublish => 'Publish';
}
