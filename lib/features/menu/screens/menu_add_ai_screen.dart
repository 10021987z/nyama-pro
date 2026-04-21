import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';

import '../../../core/constants/app_colors.dart';
import '../data/ai_menu_repository.dart';
import '../providers/menu_provider.dart';

// ─── Radio catégories (UX spec) → mappées vers les labels existants ──────────
//
// L'app Pro utilise déjà une liste de catégories dans menu_form_screen/
// menu_screen. L'IA retourne 'entree' | 'plat' | 'dessert' | 'boisson'.
// On mappe vers les labels existants pour ne pas casser les filtres.
const _aiToCatalogCategory = {
  'entree': 'Beignets & Snacks',
  'plat': 'Plats traditionnels',
  'dessert': 'Plats traditionnels',
  'boisson': 'Boissons',
};

const _radioCategories = [
  ('entree', 'Entrée', '🥗'),
  ('plat', 'Plat', '🥘'),
  ('dessert', 'Dessert', '🍰'),
  ('boisson', 'Boisson', '🥤'),
];

// ─── Steps ───────────────────────────────────────────────────────────────────
enum _Step { keywords, loading, review, submitting }

class MenuAddAiScreen extends ConsumerStatefulWidget {
  const MenuAddAiScreen({super.key});

  @override
  ConsumerState<MenuAddAiScreen> createState() => _MenuAddAiScreenState();
}

class _MenuAddAiScreenState extends ConsumerState<MenuAddAiScreen>
    with TickerProviderStateMixin {
  _Step _step = _Step.keywords;

  final _keywordsCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  final _aiRepo = AiMenuRepository();

  MenuSuggestion? _suggestion;
  String _selectedAiCategory = 'plat';
  List<String> _allergens = [];
  double _prepTime = 25;
  bool _available = true;
  File? _pickedPhoto;
  String? _error;

  // Champs régénérés individuellement (pour micro-UX "Régénérer ce champ")
  bool _regenName = false;
  bool _regenDesc = false;
  bool _regenPrice = false;

  // Confetti particles
  late final AnimationController _confettiCtrl;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _keywordsCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ── Haptic helpers ──────────────────────────────────────────────────────
  Future<void> _haptic([int duration = 10]) async {
    HapticFeedback.lightImpact();
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _hapticSuccess() async {
    HapticFeedback.mediumImpact();
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 30, 40, 50]);
    }
  }

  // ── Generate from keywords ──────────────────────────────────────────────
  Future<void> _generate({String? overrideCategory}) async {
    final keywords = _keywordsCtrl.text.trim();
    if (keywords.isEmpty) {
      setState(() => _error = 'Tape quelques mots-clés');
      return;
    }

    _haptic(8);
    setState(() {
      _step = _Step.loading;
      _error = null;
    });

    try {
      final suggestion = await _aiRepo.suggest(
        dishKeywords: keywords,
        category: overrideCategory,
      );

      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _nameCtrl.text = suggestion.name;
        _descCtrl.text = suggestion.description;
        _priceCtrl.text = suggestion.suggestedPriceXaf.toString();
        _selectedAiCategory = suggestion.category;
        _allergens = List.of(suggestion.allergens);
        _prepTime = suggestion.preparationTimeMin.toDouble().clamp(5, 60);
        _step = _Step.review;
      });
      _hapticSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Oups : $e';
        _step = _Step.keywords;
      });
    }
  }

  Future<void> _regenerateField(String field) async {
    if (_suggestion == null) return;
    _haptic(5);
    setState(() {
      if (field == 'name') _regenName = true;
      if (field == 'desc') _regenDesc = true;
      if (field == 'price') _regenPrice = true;
    });

    try {
      // Petite variation : on peut rappeler /ai/menu/suggest avec les mêmes
      // mots-clés — le dictionnaire renverra la même base, mais pour
      // ouvrir une vraie variation en V2 on ajoutera un paramètre seed.
      final fresh = await _aiRepo.suggest(
        dishKeywords: _keywordsCtrl.text.trim(),
        category: _selectedAiCategory,
      );
      if (!mounted) return;
      setState(() {
        if (field == 'name') _nameCtrl.text = fresh.name;
        if (field == 'desc') _descCtrl.text = fresh.description;
        if (field == 'price') _priceCtrl.text = fresh.suggestedPriceXaf.toString();
      });
    } catch (_) {
      // silent fallback
    }
    if (!mounted) return;
    setState(() {
      if (field == 'name') _regenName = false;
      if (field == 'desc') _regenDesc = false;
      if (field == 'price') _regenPrice = false;
    });
  }

  // ── Manual skip ─────────────────────────────────────────────────────────
  void _skipToManual() {
    _haptic(8);
    setState(() {
      _step = _Step.review;
      _suggestion = null;
      _nameCtrl.text = '';
      _descCtrl.text = '';
      _priceCtrl.text = '';
    });
  }

  // ── Photo ───────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    _haptic(5);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
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
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _pickedPhoto = File(picked.path));
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nom requis');
      return;
    }
    final price = int.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Prix invalide');
      return;
    }

    _haptic(10);
    setState(() {
      _step = _Step.submitting;
      _error = null;
    });

    final mappedCategory =
        _aiToCatalogCategory[_selectedAiCategory] ?? 'Plats traditionnels';

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty)
        'description': _descCtrl.text.trim(),
      'priceXaf': price,
      'category': mappedCategory,
      'prepTimeMin': _prepTime.toInt(),
      'isDailySpecial': false,
    };

    try {
      await ref.read(cookMenuProvider.notifier).create(data);
      if (!mounted) return;
      _hapticSuccess();

      // Toast + confetti
      setState(() => _showConfetti = true);
      _confettiCtrl.forward(from: 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Row(
            children: [
              const Text('✨ ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  '${_nameCtrl.text.trim()} ajouté à votre menu',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );

      // Laisse les confetti respirer puis ferme
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur : $e';
        _step = _Step.review;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Nouveau plat',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _buildStep(),
          ),
          if (_showConfetti)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (ctx, _) => CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(_confettiCtrl.value),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.keywords:
        return _buildKeywordsStep(key: const ValueKey('keywords'));
      case _Step.loading:
        return _buildLoadingStep(key: const ValueKey('loading'));
      case _Step.review:
      case _Step.submitting:
        return _buildReviewStep(key: const ValueKey('review'));
    }
  }

  // ── STEP 1 — Saisie mots-clés ───────────────────────────────────────────
  Widget _buildKeywordsStep({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge IA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primaryLight.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'ASSISTÉ PAR IA',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),

          const SizedBox(height: 24),

          const Text(
            'Décrivez votre plat',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.2),

          const SizedBox(height: 8),
          const Text(
            "Quelques mots suffisent. L'IA rédige une fiche appétissante pour vos clients.",
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

          const SizedBox(height: 28),

          // Champ mots-clés
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.4),
                  AppColors.primaryLight.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _keywordsCtrl,
                autofocus: true,
                maxLines: 2,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _generate(),
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Ex : ndolé viande arachide',
                  hintStyle: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 17,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  counterText: '',
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.15),

          const SizedBox(height: 12),

          // Chips suggestions de mots-clés
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['ndolé poulet', 'poulet dg', 'poisson braisé', 'bissap']
                .map((s) => _SuggestionChip(
                      label: s,
                      onTap: () {
                        _haptic(3);
                        _keywordsCtrl.text = s;
                      },
                    ))
                .toList(),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 32),

          // Bouton Générer
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: () => _generate(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 22))
                      .animate(
                          onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                          begin: 1, end: 1.25, duration: 900.ms, curve: Curves.easeInOut),
                  const SizedBox(width: 10),
                  const Text(
                    'Générer avec l\'IA',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideY(begin: 0.2),

          const SizedBox(height: 18),

          Center(
            child: TextButton(
              onPressed: _skipToManual,
              child: const Text(
                'Saisir manuellement',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
        ],
      ),
    );
  }

  // ── STEP 2 — Loading ────────────────────────────────────────────────────
  Widget _buildLoadingStep({required Key key}) {
    return Center(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sparkle animé
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(begin: 0.85, end: 1.15, duration: 1200.ms)
                    .then()
                    .scaleXY(begin: 1.15, end: 0.85, duration: 1200.ms),
                const Text('✨', style: TextStyle(fontSize: 64))
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 2400.ms)
                    .fadeIn()
                    .then()
                    .shimmer(
                      duration: 1200.ms,
                      color: AppColors.primaryLight,
                    ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "L'IA rédige votre fiche plat…",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 600.ms)
              .then(delay: 400.ms)
              .fadeOut(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            _keywordsCtrl.text.trim().isEmpty
                ? ''
                : '« ${_keywordsCtrl.text.trim()} »',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3 — Révision ──────────────────────────────────────────────────
  Widget _buildReviewStep({required Key key}) {
    final isSubmitting = _step == _Step.submitting;

    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        if (_suggestion?.matchedDish != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suggestion basée sur : ${_suggestion!.matchedDish}',
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 16),

        // ── Photo ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajouter une photo',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedPhoto = null),
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

        // ── Nom ──────────────────────────────────────────────────────────
        _FieldLabel(
          label: 'Nom du plat',
          aiHint: _suggestion != null,
          onRegenerate: _suggestion == null ? null : () => _regenerateField('name'),
          regenerating: _regenName,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: _fieldDeco(hint: 'Ex : Ndolé complet'),
        ),
        const SizedBox(height: 18),

        // ── Description ──────────────────────────────────────────────────
        _FieldLabel(
          label: 'Description',
          aiHint: _suggestion != null,
          onRegenerate: _suggestion == null ? null : () => _regenerateField('desc'),
          regenerating: _regenDesc,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          maxLength: 240,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 15,
            height: 1.4,
          ),
          decoration: _fieldDeco(
            hint: 'Description appétissante de 2 phrases…',
          ),
        ),
        const SizedBox(height: 18),

        // ── Prix + temps prep ───────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(
                    label: 'Prix (FCFA)',
                    aiHint: _suggestion != null,
                    onRegenerate: _suggestion == null
                        ? null
                        : () => _regenerateField('price'),
                    regenerating: _regenPrice,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                    decoration: _fieldDeco(hint: '2500', suffix: 'FCFA'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6, top: 2),
                    child: Text(
                      '⏱️ Préparation',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_prepTime.toInt()} min',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8),
                            ),
                            child: Slider(
                              value: _prepTime,
                              min: 5,
                              max: 60,
                              divisions: 11,
                              activeColor: AppColors.primary,
                              inactiveColor:
                                  AppColors.divider.withValues(alpha: 0.6),
                              onChanged: (v) {
                                _haptic(2);
                                setState(() =>
                                    _prepTime = (v / 5).round() * 5.0);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── Allergènes ───────────────────────────────────────────────────
        if (_allergens.isNotEmpty || _suggestion != null) ...[
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                _allergens.isEmpty
                    ? 'Aucun allergène détecté'
                    : 'Allergènes (touche pour retirer)',
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergens
                .map((a) => InputChip(
                      label: Text(a),
                      avatar: const Text('⚠️', style: TextStyle(fontSize: 12)),
                      onDeleted: () {
                        _haptic(3);
                        setState(() => _allergens.remove(a));
                      },
                      backgroundColor:
                          AppColors.warning.withValues(alpha: 0.15),
                      side: BorderSide(
                          color: AppColors.warning.withValues(alpha: 0.4)),
                      labelStyle: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
        ],

        // ── Catégorie radio ──────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Catégorie',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Row(
          children: _radioCategories
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _CategoryRadio(
                        emoji: c.$3,
                        label: c.$2,
                        selected: _selectedAiCategory == c.$1,
                        onTap: () {
                          _haptic(3);
                          setState(() => _selectedAiCategory = c.$1);
                        },
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),

        // ── Disponible toggle ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: SwitchListTile(
            value: _available,
            onChanged: (v) {
              _haptic(5);
              setState(() => _available = v);
            },
            activeThumbColor: AppColors.success,
            title: const Text(
              'Disponible dès maintenant',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _available
                  ? 'Les clients peuvent le commander'
                  : 'Le plat sera créé masqué',
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],

        const SizedBox(height: 28),

        // ── Submit ───────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 72,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.forestGreen.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  )
                : const Text(
                    'Ajouter à mon menu',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 10),

        Center(
          child: TextButton(
            onPressed: isSubmitting
                ? null
                : () => setState(() => _step = _Step.keywords),
            child: const Text(
              'Recommencer avec d\'autres mots-clés',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDeco({String? hint, String? suffix}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      suffixText: suffix,
      suffixStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool aiHint;
  final VoidCallback? onRegenerate;
  final bool regenerating;

  const _FieldLabel({
    required this.label,
    required this.aiHint,
    required this.onRegenerate,
    required this.regenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (aiHint) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '✨ IA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onRegenerate != null)
            InkWell(
              onTap: regenerating ? null : onRegenerate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (regenerating)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      const Icon(Icons.refresh, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text(
                      'Régénérer',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CategoryRadio extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryRadio({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Confetti painter ────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ConfettiPainter(this.progress)
      : particles = List.generate(28, (i) => _Particle(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = size.width / 2 + p.dx * progress * 320;
      final dy = size.height * 0.35 + p.dy * progress * 280 +
          progress * progress * 420;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - progress);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(progress * math.pi * 2 * p.spin);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 10),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  final double dx;
  final double dy;
  final double spin;
  final Color color;
  _Particle(int seed)
      : dx = (math.Random(seed).nextDouble() - 0.5) * 2,
        dy = (math.Random(seed + 99).nextDouble() - 0.6),
        spin = math.Random(seed + 7).nextDouble() * 2 - 1,
        color = _palette[seed % _palette.length];

  static const _palette = [
    AppColors.primary,
    AppColors.primaryLight,
    AppColors.success,
    AppColors.gold,
    AppColors.forestGreen,
  ];
}
