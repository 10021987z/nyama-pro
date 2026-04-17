import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _items = <_FaqItem>[
    _FaqItem(
      'Comment accepter une nouvelle commande ?',
      "Dès qu'une commande apparaît dans l'onglet « Commandes » (section NOUVELLES), "
          "une alerte sonore et une vibration se déclenchent. Appuie sur « Accepter » "
          "pour la prendre en charge : elle passe automatiquement en préparation. "
          "Tu as 3 minutes pour l'accepter avant qu'elle soit réattribuée.",
    ),
    _FaqItem(
      "Comment marquer une commande comme prête ?",
      "Quand le plat est terminé, va dans la section « EN PRÉPARATION » et appuie "
          "sur le bouton « C'est prêt ! » de la carte correspondante. Un livreur "
          "NYAMA est immédiatement notifié et vient récupérer la commande chez toi.",
    ),
    _FaqItem(
      "Comment refuser ou annuler une commande ?",
      "Dans la section « NOUVELLES », appuie sur « Refuser ». Attention : refuser "
          "trop souvent peut affecter ta note et ta visibilité. Une fois acceptée, "
          "une commande ne peut plus être annulée directement : contacte le support "
          "NYAMA.",
    ),
    _FaqItem(
      "Comment recevoir mes gains ?",
      "Tes revenus sont versés chaque semaine (lundi) sur ton compte Mobile Money "
          "(MTN MoMo ou Orange Money) enregistré dans la section « Paiement » de "
          "ton profil. NYAMA prélève une commission de 15 % sur chaque commande. "
          "Tu reçois un SMS à chaque virement.",
    ),
    _FaqItem(
      "Que faire si un livreur ne vient pas ?",
      "Attends 10 minutes après avoir marqué la commande « prête ». Si personne "
          "n'est venu, contacte immédiatement le support NYAMA par SMS ou WhatsApp. "
          "Ne donne jamais la commande à quelqu'un qui ne présente pas son badge "
          "NYAMA dans l'app livreur.",
    ),
    _FaqItem(
      "Comment modifier mes horaires d'ouverture ?",
      "Va dans « Mon Profil » → « Ma cuisine » → « MODIFIER ». Tu peux y définir "
          "les jours et heures d'ouverture. Quand tu es fermée, passe simplement "
          "en mode « Hors ligne » depuis l'écran principal.",
    ),
    _FaqItem(
      "Comment ajouter ou modifier un plat au menu ?",
      "Va dans l'onglet « Mon Menu » puis « + Ajouter un plat ». Renseigne le nom, "
          "le prix, la description, la catégorie et une photo claire du plat. "
          "Pour modifier, touche simplement le plat existant. Tu peux activer/"
          "désactiver la disponibilité à tout moment.",
    ),
    _FaqItem(
      "Comment améliorer ma note ?",
      "Respecte trois règles : 1) Le plat correspond à la photo et à la "
          "description. 2) La commande est prête dans le temps annoncé. 3) "
          "L'emballage est soigné. Les clients notent directement après réception. "
          "Une note moyenne ≥ 4,5 ★ augmente fortement ta visibilité.",
    ),
    _FaqItem(
      "Que faire en cas de litige avec un client ?",
      "Ouvre l'onglet « Historique », sélectionne la commande concernée et "
          "appuie sur « Signaler un problème ». Le support NYAMA contacte le "
          "client dans les 24h. Pendant l'analyse, le montant peut être bloqué "
          "de manière temporaire.",
    ),
    _FaqItem(
      "Comment suspendre temporairement mon activité ?",
      "Passe en « Hors ligne » depuis l'écran d'accueil (bouton en haut). "
          "Aucune nouvelle commande ne t'est envoyée tant que tu n'es pas "
          "revenue en ligne. Pour une absence prolongée (> 7 jours), préviens "
          "le support par SMS.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FAQ',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _FaqCard(item: _items[i]),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

class _FaqCard extends StatelessWidget {
  final _FaqItem item;
  const _FaqCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.primary,
          title: Text(
            item.question,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
