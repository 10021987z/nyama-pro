import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  void _verify(String code) {
    if (code.length < 4) return;
    ref.read(authStateProvider.notifier).verifyOtp(widget.phone, code);
  }

  void _showWrongRoleDialog(String? message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('⛔', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Accès refusé'),
          ],
        ),
        content: Text(
          message ??
              'Ce numéro n\'est pas associé à un compte cuisinière. Contactez NYAMA au +237 691 000 000.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authStateProvider.select((s) => s.status));
    final error = ref.watch(authStateProvider.select((s) =>
        s.status == AuthStatus.error ? s.errorMessage : null));
    final isVerifying = status == AuthStatus.verifying;

    ref.listen<AuthState>(authStateProvider, (_, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      }
      if (next.status == AuthStatus.error) {
        _controller.clear();
      }
      if (next.status == AuthStatus.wrongRole) {
        _controller.clear();
        _showWrongRoleDialog(next.errorMessage);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📱', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Code de confirmation',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Envoyé au ${widget.phone}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // OTP input — grandes cases
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _controller,
                autoFocus: true,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 64,
                  fieldWidth: 48,
                  activeFillColor: AppColors.surface,
                  inactiveFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surface,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  selectedColor: AppColors.primary,
                ),
                enableActiveFill: true,
                keyboardType: TextInputType.number,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                onChanged: (_) {
                  if (error != null) {
                    ref.read(authStateProvider.notifier).clearError();
                  }
                },
                onCompleted: _verify,
              ),

              if (error != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(error,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 14)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Renvoyer
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Renvoyer dans ${_secondsLeft}s',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 15),
                      )
                    : TextButton(
                        onPressed: () {
                          ref.read(authStateProvider.notifier).resendOtp();
                          _startTimer();
                        },
                        child: const Text(
                          'Renvoyer le code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),

              const Spacer(),

              if (isVerifying)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
