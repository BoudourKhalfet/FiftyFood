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
      'Vous devez vérifier votre e-mail avant de continuer. Veuillez consulter votre boîte de réception (et les spams) et vérifier votre e-mail.';

  @override
  String get errorUnauthorized =>
      'E-mail ou mot de passe invalide. Veuillez réessayer.';

  @override
  String get errorForbidden =>
      'Ce compte n\'est pas encore autorisé à se connecter. Veuillez contacter le support.';

  @override
  String get errorAccountDoesNotExist => 'Ce compte n\'existe pas.';

  @override
  String get errorAccountSuspended => 'Votre compte est suspendu.';

  @override
  String get errorNetwork => 'Erreur réseau. Veuillez réessayer plus tard.';

  @override
  String errorRoleMismatch(String role, String targetRole) {
    return 'Cet e-mail est enregistré en tant que $role, pas $targetRole. Veuillez vous connecter depuis le bon portail ou créer un nouveau compte.';
  }

  @override
  String get errorOnboardingNeeded =>
      'Le compte nécessite une configuration. Veuillez compléter votre profil d\'inscription.';

  @override
  String get errorLoginNoToken =>
      'Échec de la connexion : aucun jeton retourné.';

  @override
  String get infoVerificationResent =>
      'E-mail de vérification renvoyé ! Veuillez consulter votre boîte de réception (et les spams).';

  @override
  String get errorResendFailed =>
      'Impossible de renvoyer l\'e-mail de vérification.';

  @override
  String errorResendException(String error) {
    return 'Erreur lors du renvoi de l\'e-mail : $error';
  }

  @override
  String get labelAlreadyHaveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get btnSignUp => 'S\'inscrire';

  @override
  String get labelNoAccount => 'Vous n\'avez pas de compte ? ';

  @override
  String get dialogAlmostThere => 'Presque là !';

  @override
  String get infoRegistrationSuccess =>
      'Inscription réussie.\n\nVeuillez consulter votre boîte de réception (et les spams) et vérifier votre e-mail pour continuer.';

  @override
  String get btnOkay => 'D\'accord';

  @override
  String errorRegistrationFailed(String error) {
    return 'Échec de l\'inscription (exception) : $error';
  }

  @override
  String get errorAgreeTerms =>
      'Vous devez accepter les conditions d\'utilisation.';

  @override
  String get errorInvalidEmail => 'Format d\'e-mail invalide';

  @override
  String get errorPasswordsNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get btnFacebook => 'Facebook';

  @override
  String get labelAlreadyAccount => 'Vous avez déjà un compte ? ';

  @override
  String get btnSignInSmall => 'Se connecter';

  @override
  String get labelDescription => 'Description';

  @override
  String get hintDescription =>
      'ex : Sac de pâtes surprise, Sélection du chef...';

  @override
  String get btnSelectCategories => 'Sélectionner les catégories';

  @override
  String get labelOriginalPrice => 'Prix original (DT)';

  @override
  String get labelDiscountedPrice => 'Prix réduit (DT)';

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
