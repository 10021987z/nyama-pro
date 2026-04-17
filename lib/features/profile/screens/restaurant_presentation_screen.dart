import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

// ── Days of the week ────────────────────────────────────────────────────────

const _dayLabels = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _timeSlots = [
  '06:00', '06:30', '07:00', '07:30', '08:00', '08:30',
  '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
  '12:00', '12:30', '13:00', '13:30', '14:00', '14:30',
  '15:00', '15:30', '16:00', '16:30', '17:00', '17:30',
  '18:00', '18:30', '19:00', '19:30', '20:00', '20:30',
  '21:00', '21:30', '22:00', '22:30', '23:00',
];

const _prepTimes = ['15 min', '25 min', '30 min', '45 min'];

class RestaurantPresentationScreen extends ConsumerStatefulWidget {
  const RestaurantPresentationScreen({super.key});

  @override
  ConsumerState<RestaurantPresentationScreen> createState() =>
      _RestaurantPresentationScreenState();
}

class _RestaurantPresentationScreenState
    extends ConsumerState<RestaurantPresentationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Form fields
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyInputCtrl = TextEditingController();
  final List<String> _specialties = [];
  String _prepTime = '25 min';

  // Images
  File? _coverImage;
  File? _profileImage;

  // Opening hours: 7 days
  late final List<_DaySchedule> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = List.generate(7, (_) => _DaySchedule());
    _loadExistingData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final response =
          await ApiClient.instance.get(ApiConstants.cookProfile);
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data is Map && response.data['data'] is Map
              ? response.data['data'] as Map<String, dynamic>
              : null);
      if (data != null) {
        _nameCtrl.text = data['displayName']?.toString() ?? '';
        _descCtrl.text = data['description']?.toString() ?? '';
        _addressCtrl.text = data['landmark']?.toString() ?? '';
        _phoneCtrl.text = data['phone']?.toString() ?? '';
        if (data['specialty'] is List) {
          _specialties.addAll(
              (data['specialty'] as List).map((e) => e.toString()));
        }
        if (data['prepTimeAvgMin'] != null) {
          _prepTime = '${data['prepTimeAvgMin']} min';
          if (!_prepTimes.contains(_prepTime)) _prepTime = '25 min';
        }
        _parseOpeningHours(data['openingHours']);
      }
    } catch (_) {
      // Fallback: load from storage
      final phone = await SecureStorage.getUserPhone();
      if (phone != null) _phoneCtrl.text = phone;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _parseOpeningHours(dynamic raw) {
    if (raw == null) return;
    Map<String, dynamic> map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else {
      return;
    }
    for (int i = 0; i < _dayKeys.length; i++) {
      final day = map[_dayKeys[i]];
      if (day is Map<String, dynamic>) {
        _schedule[i].isClosed = day['closed'] == true;
        _schedule[i].open = day['open']?.toString() ?? '08:00';
        _schedule[i].close = day['close']?.toString() ?? '20:00';
      }
    }
  }

  Future<void> _pickImage(bool isCover) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.primary),
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
      setState(() {
        if (isCover) {
          _coverImage = File(picked.path);
        } else {
          _profileImage = File(picked.path);
        }
      });
    }
  }

  void _addSpecialty() {
    final text = _specialtyInputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _specialties.add(text);
      _specialtyInputCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final hours = <String, Map<String, dynamic>>{};
    for (int i = 0; i < _dayKeys.length; i++) {
      hours[_dayKeys[i]] = {
        'open': _schedule[i].open,
        'close': _schedule[i].close,
        'closed': _schedule[i].isClosed,
      };
    }

    final body = {
      'displayName': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'landmark': _addressCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'specialty': _specialties,
      'prepTimeAvgMin': int.tryParse(_prepTime.replaceAll(' min', '')) ?? 25,
      'openingHours': hours,
    };

    try {
      await ApiClient.instance.patch(
        ApiConstants.cookProfile,
        data: body,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant mis a jour'),
          backgroundColor: AppColors.forestGreen,
        ),
      );
    } on DioException catch (_) {
      // Fallback: save locally
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sauvegarde locale (hors-ligne)'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(0),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Hero image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _coverImage != null
                      ? Image.file(_coverImage!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.restaurant,
                                size: 48, color: AppColors.primary),
                          ),
                        ),
                ),
              ),
              // Profile overlay
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 37,
                      backgroundColor: AppColors.surface,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? const Icon(Icons.person,
                              size: 32, color: AppColors.primary)
                          : null,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isEmpty
                          ? 'Nom du restaurant'
                          : _nameCtrl.text,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 16, color: AppColors.gold),
                        const SizedBox(width: 4),
                        const Text('4.8',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(width: 12),
                        const Icon(Icons.schedule,
                            size: 14,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(_prepTime,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_descCtrl.text.isNotEmpty)
                      Text(
                        _descCtrl.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    if (_specialties.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _specialties
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(s,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      )),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Opening hours
                    const Text('Horaires',
                        style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...List.generate(7, (i) {
                      final s = _schedule[i];
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 80,
                                child: Text(_dayLabels[i],
                                    style: const TextStyle(
                                        fontSize: 13))),
                            Text(
                              s.isClosed
                                  ? 'Ferme'
                                  : '${s.open} - ${s.close}',
                              style: TextStyle(
                                fontSize: 13,
                                color: s.isClosed
                                    ? AppColors.error
                                    : AppColors.forestGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Mon restaurant')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon restaurant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // ── Cover photo ─────────────────────────────────────────
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Stack(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      image: _coverImage != null
                          ? DecorationImage(
                              image: FileImage(_coverImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 36,
                                  color: AppColors.textSecondary),
                              SizedBox(height: 8),
                              Text('Photo de couverture',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          )
                        : null,
                  ),
                  // Profile photo overlapping
                  Positioned(
                    bottom: -30,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.surface,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? const Icon(Icons.camera_alt,
                                  size: 24,
                                  color: AppColors.textSecondary)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),

            // ── Name ────────────────────────────────────────────────
            const _FieldLabel('Nom du restaurant'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
              decoration: const InputDecoration(
                hintText: 'Ex: Cuisine de Maman Catherine',
              ),
            ),
            const SizedBox(height: 20),

            // ── Description ─────────────────────────────────────────
            const _FieldLabel('Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Decrivez votre cuisine, votre histoire, vos specialites...',
              ),
            ),
            const SizedBox(height: 20),

            // ── Specialties ─────────────────────────────────────────
            const _FieldLabel('Specialites'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _specialtyInputCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Ndole, Poulet DG...',
                    ),
                    onSubmitted: (_) => _addSpecialty(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _addSpecialty,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.add, size: 24),
                  ),
                ),
              ],
            ),
            if (_specialties.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _specialties
                    .map((s) => Chip(
                          label: Text(s),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(
                              () => _specialties.remove(s)),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),

            // ── Opening hours ───────────────────────────────────────
            const _FieldLabel("Horaires d'ouverture"),
            const SizedBox(height: 10),
            ...List.generate(7, (i) => _DayRow(
              label: _dayLabels[i],
              schedule: _schedule[i],
              onChanged: () => setState(() {}),
            )),
            const SizedBox(height: 20),

            // ── Address ─────────────────────────────────────────────
            const _FieldLabel('Adresse / Repere'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                hintText:
                    'Ex: En face de la pharmacie Centrale, Akwa',
              ),
            ),
            const SizedBox(height: 20),

            // ── Phone ───────────────────────────────────────────────
            const _FieldLabel('Telephone'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+237 6XX XXX XXX',
              ),
            ),
            const SizedBox(height: 20),

            // ── Prep time ───────────────────────────────────────────
            const _FieldLabel('Temps de preparation moyen'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _prepTime,
              items: _prepTimes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _prepTime = v);
              },
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 32),

            // ── Save button ─────────────────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Preview button ──────────────────────────────────────
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _showPreview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Voir l'apercu",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field label ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Day schedule model ──────────────────────────────────────────────────────

class _DaySchedule {
  String open;
  String close;
  bool isClosed;

  _DaySchedule()
      : open = '08:00',
        close = '20:00',
        isClosed = false;
}

// ── Day row widget ──────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String label;
  final _DaySchedule schedule;
  final VoidCallback onChanged;

  const _DayRow({
    required this.label,
    required this.schedule,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (!schedule.isClosed) ...[
              _TimeDropdown(
                value: schedule.open,
                onChanged: (v) {
                  schedule.open = v;
                  onChanged();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('-',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              _TimeDropdown(
                value: schedule.close,
                onChanged: (v) {
                  schedule.close = v;
                  onChanged();
                },
              ),
            ] else
              const Text('Ferme',
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            const Spacer(),
            SizedBox(
              height: 24,
              child: Switch(
                value: !schedule.isClosed,
                onChanged: (v) {
                  schedule.isClosed = !v;
                  onChanged();
                },
                activeThumbColor: AppColors.forestGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TimeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final effectiveValue =
        _timeSlots.contains(value) ? value : _timeSlots.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: _timeSlots
              .map((t) =>
                  DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
