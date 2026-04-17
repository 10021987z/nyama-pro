import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CguScreen extends StatelessWidget {
  const CguScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Conditions d'utilisation",
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _H1('Conditions Générales d\'Utilisation — NYAMA Pro'),
          _P('Dernière mise à jour : 17 avril 2026'),
          _P(
              "Les présentes Conditions Générales d'Utilisation (ci-après « CGU ») régissent "
              "l'accès et l'utilisation de l'application mobile NYAMA Pro, éditée par "
              "NYAMA SAS, société immatriculée au Registre du Commerce et du Crédit Mobilier "
              "de Douala, République du Cameroun, soumise au droit OHADA. L'acceptation "
              "des présentes CGU est un préalable obligatoire à l'utilisation de "
              "l'application en qualité de Partenaire Cuisinier."),
          _H2('1. Définitions'),
          _P(
              "« NYAMA » désigne la société NYAMA SAS, éditrice de la plateforme. "
              "« Partenaire » désigne la personne physique ou morale inscrite en qualité "
              "de cuisinier sur l'application. « Client » désigne l'utilisateur final "
              "qui passe commande. « Livreur » désigne le partenaire de livraison "
              "référencé par NYAMA. « Commande » désigne toute demande de préparation "
              "culinaire transmise via l'application."),
          _H2('2. Inscription et compte Partenaire'),
          _P(
              "L'inscription est gratuite et soumise à l'acceptation des présentes CGU, "
              "à la vérification de l'identité du Partenaire (pièce officielle, "
              "photographie) et au contrôle de conformité de la cuisine. Le Partenaire "
              "garantit l'exactitude des informations fournies et s'engage à les "
              "mettre à jour. Le compte est strictement personnel et non cessible."),
          _H2('3. Obligations du Partenaire Cuisinier'),
          _P(
              "Le Partenaire s'engage à :\n"
              "• respecter les règles d'hygiène et de sécurité alimentaire en vigueur "
              "au Cameroun (décret n° 2012/2809/PM) ;\n"
              "• préparer les plats conformément à la description et aux photos "
              "publiées dans l'application ;\n"
              "• honorer toute commande acceptée dans le délai annoncé ;\n"
              "• ne servir que des plats destinés à la plateforme NYAMA dans les "
              "créneaux où le Partenaire est marqué « En ligne » ;\n"
              "• emballer la commande de manière propre, fermée et étiquetée ;\n"
              "• remettre la commande uniquement au Livreur NYAMA muni de son badge "
              "officiel ;\n"
              "• maintenir à jour son menu, ses prix et ses horaires."),
          _H2('4. Commission NYAMA et tarification'),
          _P(
              "En contrepartie des services fournis (mise en relation, paiement, "
              "support, marketing, assurance livraison), NYAMA perçoit une "
              "commission de quinze pour cent (15 %) sur le prix HT de chaque plat "
              "vendu via la plateforme. Cette commission peut évoluer moyennant "
              "un préavis de trente (30) jours notifié dans l'application."),
          _H2('5. Paiements et reversements'),
          _P(
              "NYAMA collecte les paiements auprès des Clients via Mobile Money "
              "(Orange Money, MTN MoMo) ou espèces. Les gains nets du Partenaire "
              "(prix HT – 15 % de commission) sont reversés chaque semaine, le "
              "lundi, sur le compte Mobile Money déclaré. Un relevé détaillé est "
              "disponible dans l'onglet « Revenus »."),
          _H2('6. Note et visibilité'),
          _P(
              "Les Clients évaluent chaque commande via un système de notation de 1 "
              "à 5 étoiles. Une note moyenne durablement inférieure à 3,5 ★ peut "
              "entraîner une baisse de visibilité, voire une suspension temporaire "
              "du compte après avertissement."),
          _H2('7. Responsabilités'),
          _P(
              "Le Partenaire est seul responsable de la qualité, de la conformité "
              "sanitaire et de la sécurité alimentaire des plats préparés. NYAMA "
              "agit uniquement en qualité d'intermédiaire technique et de "
              "plateforme de mise en relation. Sa responsabilité est limitée aux "
              "dommages directs et ne saurait excéder, en tout état de cause, le "
              "montant des commissions perçues au cours des trois (3) derniers mois."),
          _H2('8. Suspension et résiliation'),
          _P(
              "NYAMA peut suspendre ou résilier le compte d'un Partenaire, de plein "
              "droit et sans indemnité, en cas de manquement grave (fraude, plats "
              "non conformes, plaintes répétées, non-respect des règles d'hygiène, "
              "impossibilité de joindre le Partenaire pendant plus de quinze (15) "
              "jours consécutifs). Le Partenaire peut résilier à tout moment depuis "
              "l'application, sous réserve d'avoir finalisé les commandes en cours."),
          _H2('9. Données personnelles'),
          _P(
              "NYAMA traite les données personnelles conformément à la loi n° 2010/012 "
              "du 21 décembre 2010 relative à la cybersécurité et à la cybercriminalité "
              "au Cameroun. Le Partenaire peut à tout moment accéder, rectifier ou "
              "demander la suppression de ses données via l'application ou par email "
              "à privacy@nyama.cm."),
          _H2('10. Propriété intellectuelle'),
          _P(
              "La marque NYAMA, le logo, l'application et tous les éléments associés "
              "sont la propriété exclusive de NYAMA SAS. Toute reproduction ou "
              "utilisation non autorisée est strictement interdite. Les photos de "
              "plats téléchargées par le Partenaire restent sa propriété, mais il "
              "en concède à NYAMA une licence d'usage gratuite, non exclusive et "
              "mondiale pour la seule promotion de la plateforme."),
          _H2('11. Loi applicable et règlement des litiges'),
          _P(
              "Les présentes CGU sont régies par le droit camerounais et par les "
              "Actes uniformes OHADA. En cas de litige, les parties s'engagent à "
              "rechercher une solution amiable dans un délai de trente (30) jours. "
              "À défaut, les tribunaux compétents de Douala seront exclusivement "
              "saisis, nonobstant pluralité de défendeurs ou appel en garantie."),
          _H2('12. Modification des CGU'),
          _P(
              "NYAMA se réserve le droit de modifier les présentes CGU à tout moment. "
              "Les Partenaires sont informés via l'application au moins quinze (15) "
              "jours avant l'entrée en vigueur des modifications. L'usage continu "
              "de l'application vaut acceptation des nouvelles CGU."),
          _H2('Contact'),
          _P(
              "NYAMA SAS — Bonanjo, Douala, Cameroun\n"
              "Email : support@nyama.cm\n"
              "Téléphone / SMS : +237 699 000 000\n"
              "WhatsApp : wa.me/237699000000"),
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
