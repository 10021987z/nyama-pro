import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Politique de confidentialité',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _H1('Politique de confidentialité — NYAMA Pro'),
          _P('Dernière mise à jour : 17 avril 2026'),
          _P(
              "NYAMA SAS (ci-après « NYAMA ») s'engage à protéger la vie privée de "
              "ses Partenaires cuisiniers. La présente politique décrit les données "
              "personnelles collectées dans l'application NYAMA Pro, les finalités "
              "de leur traitement et les droits dont vous disposez conformément à "
              "la loi n° 2010/012 du 21 décembre 2010 relative à la cybersécurité "
              "et à la cybercriminalité au Cameroun."),
          _H2('1. Responsable du traitement'),
          _P(
              "Le responsable du traitement est NYAMA SAS, dont le siège social est "
              "situé à Bonanjo, Douala, République du Cameroun. Toute question "
              "relative à la protection des données peut être adressée à "
              "privacy@nyama.cm."),
          _H2('2. Données collectées'),
          _P(
              "Nous collectons les catégories de données suivantes :\n"
              "• Identification : nom, prénom, date de naissance, photo de profil, "
              "pièce d'identité ;\n"
              "• Contact : numéro de téléphone, email, adresse du restaurant ;\n"
              "• Financières : numéro Mobile Money (MTN ou Orange), historique "
              "des paiements ;\n"
              "• Activité : menu, prix, photos de plats, horaires, note moyenne, "
              "commandes traitées ;\n"
              "• Techniques : identifiant de l'appareil, jeton de notification "
              "Firebase, adresse IP, version de l'application, journaux "
              "d'erreurs ;\n"
              "• Localisation : position GPS de la cuisine (et, ponctuellement, "
              "position en temps réel pendant la livraison)."),
          _H2('3. Finalités du traitement'),
          _P(
              "Vos données sont traitées pour :\n"
              "• fournir et maintenir le service de mise en relation ;\n"
              "• traiter les paiements et les reversements ;\n"
              "• garantir la sécurité sanitaire et lutter contre la fraude ;\n"
              "• vous envoyer des notifications liées aux commandes ;\n"
              "• améliorer l'expérience et mesurer la qualité du service ;\n"
              "• respecter nos obligations légales (fiscalité, OHADA)."),
          _H2('4. Base légale'),
          _P(
              "Le traitement repose, selon les cas, sur : l'exécution du contrat "
              "qui nous lie au Partenaire, le respect d'obligations légales, "
              "l'intérêt légitime de NYAMA à assurer la sécurité de la plateforme, "
              "et votre consentement pour l'envoi de messages marketing."),
          _H2('5. Destinataires des données'),
          _P(
              "Vos données ne sont ni vendues ni louées. Elles peuvent être "
              "transmises aux :\n"
              "• équipes internes NYAMA (support, opérations, fraude) ;\n"
              "• Livreurs NYAMA (uniquement adresse, nom du restaurant et "
              "commande en cours) ;\n"
              "• Clients (nom commercial et note, dans l'app client) ;\n"
              "• prestataires techniques (hébergement Railway, notifications "
              "Firebase, Mobile Money) sous contrat de confidentialité ;\n"
              "• autorités compétentes sur réquisition légale."),
          _H2('6. Durée de conservation'),
          _P(
              "Les données d'identification et de contact sont conservées pendant "
              "toute la durée du compte, puis archivées pendant cinq (5) ans à des "
              "fins probatoires. Les données financières sont conservées pendant "
              "dix (10) ans conformément aux obligations comptables OHADA."),
          _H2('7. Sécurité'),
          _P(
              "Nous mettons en œuvre des mesures techniques et organisationnelles "
              "appropriées : chiffrement des échanges (HTTPS/TLS), authentification "
              "JWT, hébergement sécurisé, contrôle d'accès par rôle, sauvegardes "
              "régulières, surveillance des incidents."),
          _H2('8. Vos droits'),
          _P(
              "Vous disposez des droits suivants :\n"
              "• accès à vos données ;\n"
              "• rectification des informations inexactes ;\n"
              "• suppression (sous réserve des obligations légales) ;\n"
              "• opposition et limitation du traitement ;\n"
              "• portabilité ;\n"
              "• retrait de votre consentement à tout moment.\n"
              "Pour exercer ces droits, écrivez à privacy@nyama.cm en joignant "
              "une copie de votre pièce d'identité."),
          _H2('9. Cookies et traceurs'),
          _P(
              "L'application NYAMA Pro n'utilise pas de cookies publicitaires. Elle "
              "utilise uniquement des identifiants techniques nécessaires au "
              "fonctionnement (session, notifications, mesure de performance)."),
          _H2('10. Modifications'),
          _P(
              "La présente politique peut être mise à jour. Les Partenaires sont "
              "informés dans l'application au moins quinze (15) jours avant l'entrée "
              "en vigueur des modifications."),
          _H2('Contact'),
          _P(
              "Pour toute question ou réclamation relative à vos données :\n"
              "Email : privacy@nyama.cm\n"
              "SMS / Téléphone : +237 699 000 000"),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _H1 extends StatelessWidget {
  final String text;
  const _H1(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _H2 extends StatelessWidget {
  final String text;
  const _H2(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary),
      ),
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, height: 1.55),
      ),
    );
  }
}
