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
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
