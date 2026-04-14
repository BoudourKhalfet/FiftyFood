// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FiftyFood';

  @override
  String get welcome => 'Bienvenue sur FiftyFood';

  @override
  String get login => 'Connexion';

  @override
  String get register => 'S\'inscrire';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get arabic => 'Arabe';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get btnGetStarted => 'Commencer';

  @override
  String get btnSignIn => 'Se connecter';

  @override
  String get signInWelcome => 'Bon retour';

  @override
  String get signInSubtitle =>
      'Connectez-vous pour continuer à économiser de délicieux repas';

  @override
  String get labelEmail => 'E-mail';

  @override
  String get labelPassword => 'Mot de passe';

  @override
  String get btnForgotPassword => 'Mot de passe oublié ?';

  @override
  String get labelOrContinueWith => 'OU CONTINUER AVEC';

  @override
  String get btnGoogle => 'Google';

  @override
  String get errorRequired => 'Requis';

  @override
  String get errorInvalidCredentials =>
      'Email ou mot de passe invalide. Veuillez réessayer.';

  @override
  String get infoVerificationSent => 'E-mail de vérification renvoyé.';

  @override
  String get btnResendVerification => 'Renvoyer l\'e-mail de vérification';

  @override
  String get btnJoinAsClient => 'Rejoindre en tant que client';

  @override
  String get signupTitle => 'Créez votre compte';

  @override
  String get signupSubtitle =>
      'Commencez à économiser de la nourriture et de l\'argent en quelques minutes';

  @override
  String get labelConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get errorPasswordLength => 'Doit contenir au moins 8 caractères';

  @override
  String get labelAgreedTerms =>
      'J\'accepte les conditions d\'utilisation et la politique de confidentialité';

  @override
  String get btnContinue => 'Continuer';

  @override
  String get titleAvailableOffers => 'Offres disponibles';

  @override
  String get hintSearchOffers => 'Rechercher des restaurants ou des plats.';

  @override
  String get infoLoadingOffers => 'Chargement des offres...';

  @override
  String get errorLoadOffers => 'Échec du chargement des offres. Réessayez.';

  @override
  String get infoNoOrders => 'Pas encore de commandes.';

  @override
  String get btnTrackDelivery => 'Suivre la livraison';

  @override
  String get btnJoinAsPartner => 'Rejoindre en tant que partenaire';

  @override
  String get labelVerifiedRestaurants => 'Restaurants vérifiés';

  @override
  String get roleOwner => 'PROPRIÉTAIRE';

  @override
  String get roleManager => 'GÉRANT';

  @override
  String get btnSaveFinish => 'Enregistrer et terminer';

  @override
  String get btnSkip => 'Passer pour l\'instant';

  @override
  String get titleScanQR => 'Valider le code QR du client';

  @override
  String get btnPublishOffer => 'Publier une offre';

  @override
  String get labelPickupTime => 'Heure de récupération';

  @override
  String get labelCategories => 'Catégories';

  @override
  String get btnJoinAsDeliverer => 'Rejoindre en tant que livreur';

  @override
  String get btnBackToHome => '← Retour à l\'accueil';

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
  String get hintDescription =>
      'ex : Sac de pâtes surprise, Sélection du chef...';

  @override
  String get btnSelectCategories => 'Sélectionner les catégories';

  @override
  String get labelOriginalPrice => 'Prix original (€)';

  @override
  String get labelDiscountedPrice => 'Prix réduit (€)';

  @override
  String get labelQuantity => 'Quantité';

  @override
  String get labelVisibility => 'Visibilité';

  @override
  String get labelDeliveryAvailable => 'Livraison disponible';

  @override
  String get btnCreateOffer => 'Créer une offre';

  @override
  String get btnPublish => 'Publier';
}
