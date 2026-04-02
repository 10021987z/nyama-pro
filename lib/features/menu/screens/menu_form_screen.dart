import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../data/models/menu_item_model.dart';
import '../providers/menu_provider.dart';

// ─── Categories ───────────────────────────────────────────────────────────────

const _kCategories = [
  ('🥘', 'Plats traditionnels'),
  ('🔥', 'Grillades'),
  ('🐟', 'Poissons'),
  ('🫘', 'Beignets & Snacks'),
  ('🍚', 'Accompagnements'),
  ('🥤', 'Boissons'),
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
            // ── 1. Photo placeholder ───────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📸', style: TextStyle(fontSize: 48)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Photo (bientôt disponible)',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
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
                        emoji: c.$1,
                        label: c.$2,
                        selected: _selectedCategory == c.$2,
                        onTap: () =>
                            setState(() => _selectedCategory = c.$2),
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
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 80,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji,
                style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

