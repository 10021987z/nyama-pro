import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

// ── Local providers ───────────────────────────────────────────────────────────

final _soundLevelProvider = StateProvider<String>((ref) => 'Normal');

// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider.select((s) => s.user));
    final soundLevel = ref.watch(_soundLevelProvider);

    final name = user?.name ?? 'Cuisinière';
    final phone = user?.phone ?? '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Mon Profil',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── En-tête ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPhone(phone),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 12),
                // Spécialités
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: const [
                    _SpecialtyChip('🥘 Plats traditionnels'),
                    _SpecialtyChip('🔥 Grillades'),
                    _SpecialtyChip('🐟 Poissons'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Localisation ──────────────────────────────────────────────
          _ProfileCard(
            children: [
              _ProfileTile(
                leading: '📍',
                title: 'Localisation',
                subtitle: 'Akwa, Douala',
                trailing: null,
              ),
              const Divider(height: 1),
              _ProfileTile(
                leading: '🏠',
                title: 'Repère',
                subtitle: 'En face de la pharmacie Centrale',
                trailing: null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Paiement ──────────────────────────────────────────────────
          _ProfileCard(
            children: [
              _ProfileTile(
                leading: '🟡',
                title: 'MTN Mobile Money',
                subtitle: '+237 69X XXX XX01',
                trailing: null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Paramètres ────────────────────────────────────────────────
          _ProfileCard(
            children: [
              // Son des alertes
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text('🔔',
                        style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Son des alertes',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary)),
                    ),
                    DropdownButton<String>(
                      value: soundLevel,
                      underline: const SizedBox(),
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(
                            value: 'Normal',
                            child: Text('Normal')),
                        DropdownMenuItem(
                            value: 'Fort',
                            child: Text('Fort')),
                        DropdownMenuItem(
                            value: 'Maximum',
                            child: Text('Maximum')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(_soundLevelProvider.notifier)
                              .state = v;
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const _ProfileTile(
                leading: '🌐',
                title: 'Langue',
                subtitle: 'Français',
                trailing: null,
                subtitleColor: AppColors.textSecondary,
              ),
              const Divider(height: 1),
              const _ProfileTile(
                leading: '⏰',
                title: 'Horaires',
                subtitle: 'Non renseignés',
                trailing: null,
                subtitleColor: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Navigation ────────────────────────────────────────────────
          _ProfileCard(
            children: [
              _ProfileTile(
                leading: '📦',
                title: 'Historique commandes',
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => context.push('/history'),
              ),
              const Divider(height: 1),
              _ProfileTile(
                leading: '⭐',
                title: 'Mes avis',
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => context.push('/reviews'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Aide ──────────────────────────────────────────────────────
          _ProfileCard(
            children: [
              _ProfileTile(
                leading: '📞',
                title: 'Contacter NYAMA',
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () =>
                    _callNyama(),
              ),
              const Divider(height: 1),
              const _ProfileTile(
                leading: 'ℹ️',
                title: 'Version',
                subtitle: 'NYAMA Pro v1.0.0',
                trailing: null,
                subtitleColor: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Déconnexion ───────────────────────────────────────────────
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Se déconnecter',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatPhone(String phone) {
    if (phone.length < 6) return phone;
    // Format: +237 6XX XXX XXX
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 12) {
      return '+${digits.substring(0, 3)} ${digits.substring(3, 4)} ${digits.substring(4, 7)} ${digits.substring(7, 10)} ${digits.substring(10)}';
    }
    return phone;
  }

  Future<void> _callNyama() async {
    final uri = Uri.parse('tel:+237600000000');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content:
            const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Déconnecter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/phone');
    }
  }
}

// ── Specialty chip ────────────────────────────────────────────────────────────

class _SpecialtyChip extends StatelessWidget {
  final String label;
  const _SpecialtyChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfileCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }
}

// ── Profile tile ──────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final String leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? subtitleColor;

  const _ProfileTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(leading, style: const TextStyle(fontSize: 22)),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: subtitleColor ?? AppColors.textSecondary,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
