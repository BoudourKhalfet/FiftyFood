import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'FiftyFood'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FiftyFood'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @btnGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get btnGetStarted;

  /// No description provided for @btnSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get btnSignIn;

  /// No description provided for @signInWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInWelcome;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue saving delicious meals'**
  String get signInSubtitle;

  /// No description provided for @labelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// No description provided for @labelPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get labelPassword;

  /// No description provided for @btnForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get btnForgotPassword;

  /// No description provided for @labelOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'OR CONTINUE WITH'**
  String get labelOrContinueWith;

  /// No description provided for @btnGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get btnGoogle;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get errorRequired;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please try again.'**
  String get errorInvalidCredentials;

  /// No description provided for @infoVerificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent.'**
  String get infoVerificationSent;

  /// No description provided for @btnResendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend Verification Email'**
  String get btnResendVerification;

  /// No description provided for @btnJoinAsClient.
  ///
  /// In en, this message translates to:
  /// **'Join as Client'**
  String get btnJoinAsClient;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start saving food and money in minutes'**
  String get signupSubtitle;

  /// No description provided for @labelConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get labelConfirmPassword;

  /// No description provided for @errorPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters'**
  String get errorPasswordLength;

  /// No description provided for @labelAgreedTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy'**
  String get labelAgreedTerms;

  /// No description provided for @btnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btnContinue;

  /// No description provided for @titleAvailableOffers.
  ///
  /// In en, this message translates to:
  /// **'Available Offers'**
  String get titleAvailableOffers;

  /// No description provided for @hintSearchOffers.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants or dishes.'**
  String get hintSearchOffers;

  /// No description provided for @infoLoadingOffers.
  ///
  /// In en, this message translates to:
  /// **'Loading offers...'**
  String get infoLoadingOffers;

  /// No description provided for @errorLoadOffers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load offers. Try again.'**
  String get errorLoadOffers;

  /// No description provided for @infoNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get infoNoOrders;

  /// No description provided for @btnTrackDelivery.
  ///
  /// In en, this message translates to:
  /// **'Track Delivery'**
  String get btnTrackDelivery;

  /// No description provided for @btnJoinAsPartner.
  ///
  /// In en, this message translates to:
  /// **'Join as Partner'**
  String get btnJoinAsPartner;

  /// No description provided for @labelVerifiedRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Verified Restaurants'**
  String get labelVerifiedRestaurants;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get roleOwner;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'MANAGER'**
  String get roleManager;

  /// No description provided for @btnSaveFinish.
  ///
  /// In en, this message translates to:
  /// **'Save & Finish'**
  String get btnSaveFinish;

  /// No description provided for @btnSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get btnSkip;

  /// No description provided for @titleScanQR.
  ///
  /// In en, this message translates to:
  /// **'Validate Customer QR Code'**
  String get titleScanQR;

  /// No description provided for @btnPublishOffer.
  ///
  /// In en, this message translates to:
  /// **'Publish Offer'**
  String get btnPublishOffer;

  /// No description provided for @labelPickupTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Time'**
  String get labelPickupTime;

  /// No description provided for @labelCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get labelCategories;

  /// No description provided for @btnJoinAsDeliverer.
  ///
  /// In en, this message translates to:
  /// **'Join as Deliverer'**
  String get btnJoinAsDeliverer;

  /// No description provided for @btnBackToHome.
  ///
  /// In en, this message translates to:
  /// **'← Back to Home'**
  String get btnBackToHome;

  /// No description provided for @errorEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'You must verify your email before you can continue. Please check your inbox (and spam) and verify your email.'**
  String get errorEmailNotVerified;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please try again.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'This account is not allowed to login yet. Please contact support.'**
  String get errorForbidden;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again later.'**
  String get errorNetwork;

  /// No description provided for @errorRoleMismatch.
  ///
  /// In en, this message translates to:
  /// **'This email is registered as a {role}, not a {targetRole}. Please sign in from the correct portal or register a new account.'**
  String errorRoleMismatch(String role, String targetRole);

  /// No description provided for @errorOnboardingNeeded.
  ///
  /// In en, this message translates to:
  /// **'Account needs onboarding. Please complete your registration profile.'**
  String get errorOnboardingNeeded;

  /// No description provided for @errorLoginNoToken.
  ///
  /// In en, this message translates to:
  /// **'Login failed: No token returned.'**
  String get errorLoginNoToken;

  /// No description provided for @infoVerificationResent.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent! Please check your inbox (and spam).'**
  String get infoVerificationResent;

  /// No description provided for @errorResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resend verification email.'**
  String get errorResendFailed;

  /// No description provided for @errorResendException.
  ///
  /// In en, this message translates to:
  /// **'Error resending email: {error}'**
  String errorResendException(String error);

  /// No description provided for @labelAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get labelAlreadyHaveAccount;

  /// No description provided for @btnSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get btnSignUp;

  /// No description provided for @labelNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get labelNoAccount;

  /// No description provided for @dialogAlmostThere.
  ///
  /// In en, this message translates to:
  /// **'Almost there!'**
  String get dialogAlmostThere;

  /// No description provided for @infoRegistrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful.\n\nPlease check your email inbox (and spam) and verify your email to continue.'**
  String get infoRegistrationSuccess;

  /// No description provided for @btnOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get btnOkay;

  /// No description provided for @errorRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed (exception): {error}'**
  String errorRegistrationFailed(String error);

  /// No description provided for @errorAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'You must agree to terms of service.'**
  String get errorAgreeTerms;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get errorInvalidEmail;

  /// No description provided for @errorPasswordsNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errorPasswordsNotMatch;

  /// No description provided for @btnFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get btnFacebook;

  /// No description provided for @labelAlreadyAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get labelAlreadyAccount;

  /// No description provided for @btnSignInSmall.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get btnSignInSmall;

  /// No description provided for @labelDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get labelDescription;

  /// No description provided for @hintDescription.
  ///
  /// In en, this message translates to:
  /// **'e.g. Surprise pasta bag, Chef\'s selection...'**
  String get hintDescription;

  /// No description provided for @btnSelectCategories.
  ///
  /// In en, this message translates to:
  /// **'Select categories'**
  String get btnSelectCategories;

  /// No description provided for @labelOriginalPrice.
  ///
  /// In en, this message translates to:
  /// **'Original Price (€)'**
  String get labelOriginalPrice;

  /// No description provided for @labelDiscountedPrice.
  ///
  /// In en, this message translates to:
  /// **'Discounted Price (€)'**
  String get labelDiscountedPrice;

  /// No description provided for @labelQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get labelQuantity;

  /// No description provided for @labelVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get labelVisibility;

  /// No description provided for @labelDeliveryAvailable.
  ///
  /// In en, this message translates to:
  /// **'Delivery Available'**
  String get labelDeliveryAvailable;

  /// No description provided for @btnCreateOffer.
  ///
  /// In en, this message translates to:
  /// **'Create Offer'**
  String get btnCreateOffer;

  /// No description provided for @btnPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get btnPublish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
