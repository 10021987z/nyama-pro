import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportPhone = '+237699000000';
  static const _supportSmsBody =
      "Bonjour NYAMA, je rencontre un problème sur l'app Pro et j'aurais besoin d'aide. Merci.";

  Future<void> _openSms(BuildContext context) async {
    final uri = Uri(
      scheme: 'sms',
      path: _supportPhone,
      queryParameters: {'body': _supportSmsBody},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'app SMS')),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/237699000000');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Aide & Support',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionTitle('Aide & Support'),
          const SizedBox(height: 8),
          _CardList(children: [
            _Tile(
              icon: Icons.quiz_outlined,
              label: 'FAQ',
              subtitle: 'Questions fréquentes',
              onTap: () => context.push('/profile/faq'),
            ),
            const Divider(height: 1),
            _Tile(
              icon: Icons.sms_outlined,
              label: 'Contacter le support',
              subtitle: 'SMS au +237 699 000 000',
              onTap: () => _openSms(context),
            ),
            const Divider(height: 1),
            _Tile(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp NYAMA',
              subtitle: 'Discuter avec l\'équipe',
              onTap: () => _openWhatsApp(context),
            ),
          ]),
          const SizedBox(height: 24),
          _SectionTitle('Légal'),
          const SizedBox(height: 8),
          _CardList(children: [
            _Tile(
              icon: Icons.description_outlined,
              label: 'Conditions d\'utilisation',
              onTap: () => context.push('/profile/cgu'),
            ),
            const Divider(height: 1),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              label: 'Politique de confidentialité',
              onTap: () => context.push('/profile/privacy'),
            ),
            const Divider(height: 1),
            _Tile(
              icon: Icons.info_outline,
              label: 'À propos',
              onTap: () => context.push('/profile/about'),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Widgets communs ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  final List<Widget> children;
  const _CardList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
