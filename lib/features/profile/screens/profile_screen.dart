import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  File? _localPreview;

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt,
                  color: AppColors.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.primary),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    // Aperçu immédiat pendant l'upload
    setState(() => _localPreview = file);

    try {
      await ref.read(userProfileProvider.notifier).uploadAvatar(file);
      if (!mounted) return;
      setState(() => _localPreview = null); // on repasse sur l'URL backend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.forestGreen,
          content: Text('Photo de profil mise à jour'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _localPreview = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          content: Text('Échec upload : $e'),
        ),
      );
    }
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('Aucune nouvelle notification',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Tu seras prévenue dès qu\'une commande arrive',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _pickLang() {
    final current = ref.read(languageProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir la langue'),
        children: const [
          ['fr', 'Français'],
          ['en', 'English'],
          ['pidgin', 'Pidgin'],
        ]
            .map((p) => SimpleDialogOption(
                  onPressed: () async {
                    ref.read(languageProvider.notifier).state = p[0];
                    await SecureStorage.saveLanguage(p[0]);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Row(
                    children: [
                      if (current == p[0])
                        const Icon(Icons.check,
                            size: 18, color: AppColors.primary),
                      if (current == p[0]) const SizedBox(width: 8),
                      Text(p[1]),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  String _langLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'pidgin':
        return 'Pidgin';
      default:
        return 'Français';
    }
  }

  void _openSupport() => context.push('/profile/support');
  void _openCgu() => context.push('/profile/cgu');
  void _openAbout() => context.push('/profile/about');

  Widget _buildAvatar() {
    if (_localPreview != null) {
      return Image.file(_localPreview!, fit: BoxFit.cover);
    }
    final remote = ref.watch(userProfileProvider).avatarUrl;
    if (remote != null && remote.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ApiConstants.absoluteUrl(remote),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppColors.surface),
        errorWidget: (_, __, ___) => Image.asset(
          'assets/images/mock/logo_nyama.jpg',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      'assets/images/mock/logo_nyama.jpg',
      fit: BoxFit.cover,
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
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
    if (confirm == true && mounted) {
      await ref.read(userProfileProvider.notifier).clearOnLogout();
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Mon Profil',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Hero ──────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 2),
                          ),
                          child: ClipOval(
                            child: _buildAvatar(),
                          ),
                        ),
                        if (ref.watch(userProfileProvider).isUploading)
                          const Positioned.fill(
                            child: ClipOval(
                              child: ColoredBox(
                                color: Color(0x66000000),
                                child: Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: -6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Cuisinière Vérifiée',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Maman Catherine',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.place,
                          color: AppColors.primary, size: 16),
                      SizedBox(width: 4),
                      Text('Akwa, Douala',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('Membre depuis Mars 2024',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Stats ─────────────────────────────────────────────────
            Row(
              children: const [
                Expanded(
                    child: _StatCard(
                        label: 'COMMANDES',
                        value: '342',
                        color: AppColors.primary)),
                SizedBox(width: 10),
                Expanded(
                    child: _StatCard(
                        label: 'NOTE',
                        value: '4.8 ★',
                        color: AppColors.gold)),
                SizedBox(width: 10),
                Expanded(
                    child: _StatCard(
                        label: 'CLIENTS',
                        value: '285',
                        color: AppColors.primary)),
                SizedBox(width: 10),
                Expanded(
                    child: _StatCard(
                        label: 'PLATS',
                        value: '12',
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Ma cuisine ────────────────────────────────────────────
            _SectionCard(
              title: 'Ma cuisine',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('MODIFIER',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800)),
              ),
              children: [
                const Text('Spécialités',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _Chip('Traditionnel'),
                    _Chip('Grillades'),
                    _Chip('Poissons'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Icon(Icons.schedule,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Lundi - Samedi',
                        style:
                            TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                const Padding(
                  padding: EdgeInsets.only(left: 26),
                  child: Text('08h00 - 20h00'),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 26),
                  child: Text('Dimanche : Fermé',
                      style: TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.timer,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Temps moyen : '),
                    Text('25 min',
                        style: TextStyle(
                            fontFamily: 'SpaceMono',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Paiement ──────────────────────────────────────────────
            _SectionCard(
              title: 'Paiement',
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('MTN MoMo : +237 699 XXX XXX')),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Orange Money : +237 655 XXX XXX'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft),
                  child: const Text('Modifier mes comptes',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Mon restaurant ────────────────────────────────────────
            _SectionCard(
              title: 'Mon restaurant',
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/mock/ndole.jpg',
                    height: 80,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Cuisine de Maman Catherine',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Plats traditionnels camerounais préparés avec amour depuis 2024.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/profile/restaurant'),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft),
                  child: const Text('Modifier mon restaurant →',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Menu items ────────────────────────────────────────────
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.notifications_none,
                label: 'Notifications',
                onTap: _openNotifications,
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.language,
                label: t('language', ref),
                trailing: _langLabel(ref.watch(languageProvider)),
                onTap: _pickLang,
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.help_outline,
                label: t('support', ref),
                onTap: _openSupport,
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.description_outlined,
                label: t('tos', ref),
                onTap: _openCgu,
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.info_outline,
                label: 'À propos',
                onTap: _openAbout,
              ),
            ]),
            const SizedBox(height: 20),

            // ── Déconnexion ───────────────────────────────────────────
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _confirmLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.error.withValues(alpha: 0.12),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t('logout', ref),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Version 1.0 • Cuisine de Nyama',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

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

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _MenuTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing!,
                style: const TextStyle(
                    color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              color: AppColors.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }
}
