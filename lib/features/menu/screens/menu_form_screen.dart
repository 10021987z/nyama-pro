import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../data/models/menu_item_model.dart';
import '../providers/menu_provider.dart';

// ─── Categories ───────────────────────────────────────────────────────────────
// Photo réelle pour chaque catégorie (alignées avec l'app Client) — meilleure
// expérience que les emojis et cohérence visuelle d'un bout à l'autre.

class _Category {
  final String emoji;
  final String label;
  final String image;
  const _Category(this.emoji, this.label, this.image);
}

const _kCategories = <_Category>[
  _Category('🥘', 'Plats traditionnels', 'assets/images/mock/ndole.jpg'),
  _Category('🔥', 'Grillades', 'assets/images/mock/grillades-jardin-d-olympe.jpg'),
  _Category('🐟', 'Poissons', 'assets/images/mock/poisson.jpg'),
  _Category('🫘', 'Beignets & Snacks', 'assets/images/mock/beignet.jpg'),
  _Category('🍚', 'Accompagnements', 'assets/images/mock/plat_accompagnement.jpg'),
  _Category('🥤', 'Boissons', 'assets/images/mock/Boissons.jpg'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class MenuFormScreen extends ConsumerStatefulWidget {
  /// null = mode ajout, non-null = mode édition
  final MenuItemModel? item;

  const MenuFormScreen({super.key, this.item});

  @override
  ConsumerState<MenuFormScreen> createState() => _MenuFormScreenState();
}

class _MenuFormScreenState extends ConsumerState<MenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDeleting = false;

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;

  // Local state
  String? _selectedCategory;
  double _prepTime = 20;
  bool _isDailySpecial = false;
  File? _pickedPhoto;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _descCtrl = TextEditingController(text: item?.description ?? '');
    _priceCtrl = TextEditingController(
        text: item != null ? item.priceXaf.toString() : '');
    _stockCtrl = TextEditingController(
        text: item?.stockRemaining?.toString() ?? '');
    _selectedCategory = item?.category;
    _prepTime = (item?.prepTimeMin ?? 20).toDouble().clamp(5, 60);
    _isDailySpecial = item?.isDailySpecial ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
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
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null && mounted) {
      setState(() => _pickedPhoto = File(picked.path));
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une catégorie'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);

    // Upload photo si une nouvelle a été choisie. Le backend retourne
    // `{id, url, ...}` — on stocke l'URL dans imageUrl du menu item.
    String? uploadedImageUrl;
    if (_pickedPhoto != null) {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _pickedPhoto!.path,
            filename: _pickedPhoto!.path.split('/').last,
          ),
        });
        final res = await ApiClient.instance.post(
          '/uploads/document',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        );
        final body = res.data;
        if (body is Map<String, dynamic>) {
          final relativeUrl = body['url']?.toString();
          if (relativeUrl != null) {
            uploadedImageUrl = relativeUrl.startsWith('http')
                ? relativeUrl
                : '${ApiConstants.serverHost}$relativeUrl';
          }
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Échec upload photo : $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
    }

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty)
        'description': _descCtrl.text.trim(),
      'priceXaf': int.parse(_priceCtrl.text.trim()),
      'category': _selectedCategory!,
      'prepTimeMin': _prepTime.toInt(),
      if (_stockCtrl.text.trim().isNotEmpty)
        'stockRemaining': int.parse(_stockCtrl.text.trim()),
      'isDailySpecial': _isDailySpecial,
      if (uploadedImageUrl != null) 'imageUrl': uploadedImageUrl,
    };

    try {
      if (_isEdit) {
        await ref
            .read(cookMenuProvider.notifier)
            .update(widget.item!.id, data);
      } else {
        await ref.read(cookMenuProvider.notifier).create(data);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Plat enregistré ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer ce plat ?'),
        content: Text(
          'Voulez-vous vraiment supprimer "${widget.item!.name}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    try {
      await ref
          .read(cookMenuProvider.notifier)
          .delete(widget.item!.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Plat supprimé')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'Modifier le plat' : 'Ajouter un plat',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── 1. Photo ───────────────────────────────────────────────
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.divider, width: 1),
                  image: _pickedPhoto != null
                      ? DecorationImage(
                          image: FileImage(_pickedPhoto!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _pickedPhoto == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt,
                              color: AppColors.primary, size: 40),
                          SizedBox(height: 6),
                          Text(
                            'Ajouter une photo',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pickedPhoto = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. Nom ─────────────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 18),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom du plat *',
                hintText: 'Ex: Ndolé complet',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom requis' : null,
            ),
            const SizedBox(height: 16),

            // ── 3. Description ─────────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Ex: Ndolé aux crevettes et viande de bœuf',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Prix ────────────────────────────────────────────────
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
              decoration: const InputDecoration(
                labelText: 'Prix (FCFA) *',
                suffixText: 'FCFA',
                border: OutlineInputBorder(),
                suffixStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Prix requis';
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return 'Prix invalide';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── 5. Catégorie ───────────────────────────────────────────
            const Text(
              'Catégorie *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _kCategories
                  .map((c) => _CategoryButton(
                        emoji: c.emoji,
                        label: c.label,
                        image: c.image,
                        selected: _selectedCategory == c.label,
                        onTap: () =>
                            setState(() => _selectedCategory = c.label),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ── 6. Temps de préparation ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '⏱️ Temps de préparation',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_prepTime.toInt()} min',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _prepTime,
              min: 5,
              max: 60,
              divisions: 11,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surface,
              onChanged: (v) =>
                  setState(() => _prepTime = (v / 5).round() * 5.0),
            ),
            const SizedBox(height: 16),

            // ── 7. Stock restant ───────────────────────────────────────
            TextFormField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '📦 Portions disponibles',
                hintText: 'Laisser vide = illimité',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return 'Nombre invalide';
                return null;
              },
            ),
            const SizedBox(height: 8),

            // ── 8. Toggle Plat du jour ─────────────────────────────────
            SwitchListTile(
              value: _isDailySpecial,
              onChanged: (v) => setState(() => _isDailySpecial = v),
              activeThumbColor: AppColors.secondary,
              title: const Text(
                '⭐ Plat du jour',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Mettre ce plat en avant pour les clients',
                style: TextStyle(fontSize: 13),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // ── 9. Bouton Enregistrer ──────────────────────────────────
            SizedBox(
              height: 72,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : const Text(
                        '💾  Enregistrer',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
              ),
            ),

            // ── 10. Bouton Supprimer (edit only) ──────────────────────
            if (_isEdit) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.error),
                        )
                      : const Text(
                          '🗑️  Supprimer ce plat',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Category button ───────────────────────────────────────────────────────────

class _CategoryButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.emoji,
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 124,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              color: selected ? AppColors.primary : Colors.white,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

