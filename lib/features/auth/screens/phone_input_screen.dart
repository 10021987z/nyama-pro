import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Entrez votre numéro';
    final cleaned = v.replaceAll(RegExp(r'[\s\-]'), '');
    final local = RegExp(r'^6[5-9]\d{7}$');
    final intl = RegExp(r'^(?:\+237|00237)6[5-9]\d{7}$');
    if (!local.hasMatch(cleaned) && !intl.hasMatch(cleaned)) {
      return 'Numéro invalide (ex: 691 000 000)';
    }
    return null;
  }

  String _normalize(String phone) {
    final c = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (c.startsWith('+237')) return c;
    if (c.startsWith('00237')) return '+${c.substring(2)}';
    if (c.startsWith('6')) return '+237$c';
    return c;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _normalize(_controller.text.trim());
    ref.read(authStateProvider.notifier).requestOtp(phone);
  }

  void _openAccessCodeSheet() {
    final initialPhone = _controller.text.trim().isNotEmpty
        ? _normalize(_controller.text.trim())
        : '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AccessCodeSheet(initialPhone: initialPhone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
        authStateProvider.select((s) => s.status == AuthStatus.loading));
    final error = ref.watch(
        authStateProvider.select((s) =>
            s.status == AuthStatus.error ? s.errorMessage : null));

    ref.listen<AuthState>(authStateProvider, (_, next) {
      if (next.status == AuthStatus.otpSent) {
        context.go('/otp', extra: next.phone);
      } else if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Icône + titre
                const Text('👩‍🍳', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text(
                  'Bienvenue\nchez NYAMA Pro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Votre numéro MTN ou Orange',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Champ numéro
                TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9\+\s\-]')),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '+237 ',
                    prefixStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    hintText: '6XX XXX XXX',
                    hintStyle: TextStyle(
                        fontSize: 22, color: AppColors.textSecondary),
                  ),
                  validator: _validate,
                  onFieldSubmitted: (_) => _submit(),
                ),

                if (error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],

                const Spacer(),

                // Bouton — 56dp
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Recevoir le code SMS',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 22),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: isLoading ? null : _openAccessCodeSheet,
                    icon: const Icon(Icons.key_rounded, size: 18),
                    label: const Text(
                      'Première connexion ? Utilisez votre code d\'accès',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom sheet : code d'accès première connexion ─────────────────────────

class AccessCodeSheet extends ConsumerStatefulWidget {
  final String initialPhone;
  const AccessCodeSheet({super.key, required this.initialPhone});

  @override
  ConsumerState<AccessCodeSheet> createState() => _AccessCodeSheetState();
}

class _AccessCodeSheetState extends ConsumerState<AccessCodeSheet> {
  late final TextEditingController _phoneCtrl;
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhone.startsWith('+237')
        ? widget.initialPhone.substring(4)
        : widget.initialPhone;
    _phoneCtrl = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _normalize(String phone) {
    final c = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (c.startsWith('+237')) return c;
    if (c.startsWith('00237')) return '+${c.substring(2)}';
    if (c.startsWith('6')) return '+237$c';
    return c;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Entrez votre numéro';
    final cleaned = v.replaceAll(RegExp(r'[\s\-]'), '');
    final local = RegExp(r'^6[5-9]\d{7}$');
    final intl = RegExp(r'^(?:\+237|00237)6[5-9]\d{7}$');
    if (!local.hasMatch(cleaned) && !intl.hasMatch(cleaned)) {
      return 'Numéro invalide';
    }
    return null;
  }

  String? _validateCode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Entrez votre code';
    final ok = RegExp(r'^NYAM-[A-Z0-9]{4}$').hasMatch(v.trim().toUpperCase());
    if (!ok) return 'Format attendu : NYAM-XXXX';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _normalize(_phoneCtrl.text.trim());
    final code = _codeCtrl.text.trim().toUpperCase();
    await ref.read(authStateProvider.notifier).loginWithAccessCode(phone, code);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
        authStateProvider.select((s) => s.status == AuthStatus.verifying));
    final error = ref.watch(
        authStateProvider.select((s) =>
            s.status == AuthStatus.error ? s.errorMessage : null));

    ref.listen<AuthState>(authStateProvider, (_, next) {
      if (next.status == AuthStatus.authenticated && mounted) {
        Navigator.of(context).pop();
      }
    });

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Activer votre compte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Entrez le code d\'accès reçu par email après l\'approbation de votre candidature.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\+\s\-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  prefixText: '+237 ',
                  hintText: '6XX XXX XXX',
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  LengthLimitingTextInputFormatter(9),
                  _UpperCaseFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
                decoration: const InputDecoration(
                  labelText: 'Code d\'accès',
                  hintText: 'NYAM-XXXX',
                ),
                validator: _validateCode,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4332),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white),
                        )
                      : const Text(
                          'Activer mon compte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
