import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

/// Clé SharedPreferences pour marquer l'onboarding comme terminé.
const kOnboardingCompletedKey = 'onboarding_completed';

/// Retourne true si l'onboarding est déjà terminé.
Future<bool> isOnboardingCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kOnboardingCompletedKey) ?? false;
  } catch (_) {
    return false;
  }
}

/// Marque l'onboarding comme terminé.
Future<void> markOnboardingCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingCompletedKey, true);
  } catch (_) {}
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  final int _total = 4;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    context.go('/home');
  }

  void _next() {
    if (_page >= _total - 1) {
      _finish();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _total - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip en haut à droite ─────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // ── Pages ─────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _page = p),
                children: const [
                  _SlideWelcome(),
                  _SlideOrders(),
                  _SlideRiders(),
                  _SlideRevenue(),
                ],
              ),
            ),

            // ── Dots indicator ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_total, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── CTA ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: Text(isLast ? "C'est parti !" : 'Suivant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide 1 : Bienvenue ────────────────────────────────────────────────────

class _SlideWelcome extends StatelessWidget {
  const _SlideWelcome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Image.asset(
                'assets/images/logo_nyama.jpg',
                fit: BoxFit.contain,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shakeX(hz: 2, amount: 6, duration: 1.4.seconds),
          const SizedBox(height: 32),
          const Text(
            'Bienvenue Maman Catherine',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Votre cuisine, votre succès. NYAMA vous accompagne à chaque commande.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 2 : Commandes — barres colorées qui slident ─────────────────────

class _SlideOrders extends StatelessWidget {
  const _SlideOrders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _orderBar(const Color(0xFFFFF1E3), AppColors.newOrder,
                        'Nouvelle', 0)
                    .animate(onPlay: (c) => c.repeat())
                    .slideX(
                        begin: -1,
                        end: 0,
                        duration: 600.ms,
                        curve: Curves.easeOut)
                    .then(delay: 1200.ms)
                    .slideX(
                        begin: 0,
                        end: 1,
                        duration: 600.ms,
                        curve: Curves.easeIn),
                const SizedBox(height: 8),
                _orderBar(const Color(0xFFFFF8DB), AppColors.warning,
                        'Préparation', 200)
                    .animate(onPlay: (c) => c.repeat())
                    .slideX(
                        begin: -1,
                        end: 0,
                        delay: 200.ms,
                        duration: 600.ms,
                        curve: Curves.easeOut)
                    .then(delay: 1000.ms)
                    .slideX(
                        begin: 0,
                        end: 1,
                        duration: 600.ms,
                        curve: Curves.easeIn),
                const SizedBox(height: 8),
                _orderBar(const Color(0xFFE6F4EA), AppColors.success, 'Prête',
                        400)
                    .animate(onPlay: (c) => c.repeat())
                    .slideX(
                        begin: -1,
                        end: 0,
                        delay: 400.ms,
                        duration: 600.ms,
                        curve: Curves.easeOut)
                    .then(delay: 800.ms)
                    .slideX(
                        begin: 0,
                        end: 1,
                        duration: 600.ms,
                        curve: Curves.easeIn),
                const SizedBox(height: 8),
                _orderBar(const Color(0xFFE4EEFB), const Color(0xFF2563EB),
                        'En livraison', 600)
                    .animate(onPlay: (c) => c.repeat())
                    .slideX(
                        begin: -1,
                        end: 0,
                        delay: 600.ms,
                        duration: 600.ms,
                        curve: Curves.easeOut)
                    .then(delay: 600.ms)
                    .slideX(
                        begin: 0,
                        end: 1,
                        duration: 600.ms,
                        curve: Curves.easeIn),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Gérez vos commandes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Reçue, en préparation, prête, livrée — chaque étape est claire et visible en un coup d\'œil.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderBar(Color bg, Color accent, String label, int delay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: accent,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

// ── Slide 3 : Chat livreur ──────────────────────────────────────────────────

class _SlideRiders extends StatelessWidget {
  const _SlideRiders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Bulle du livreur
                Positioned(
                  top: 40,
                  left: 16,
                  child: _chatBubble(
                    'Bonjour, je suis devant',
                    Colors.white,
                    AppColors.textPrimary,
                    isLeft: true,
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms)
                      .then(delay: 1400.ms)
                      .fadeOut(duration: 400.ms),
                ),
                // Bulle de maman Catherine
                Positioned(
                  bottom: 40,
                  right: 16,
                  child: _chatBubble(
                    'Arrive dans 2 min !',
                    AppColors.primary,
                    Colors.white,
                    isLeft: false,
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 600.ms, delay: 1200.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms)
                      .then(delay: 400.ms)
                      .fadeOut(duration: 400.ms),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Contactez vos livreurs',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chat intégré directement dans chaque commande. Zéro appel raté, zéro confusion.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(String text, Color bg, Color fg, {required bool isLeft}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isLeft ? 4 : 16),
          bottomRight: Radius.circular(isLeft ? 16 : 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'NunitoSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Slide 4 : Revenus avec bar chart animé ─────────────────────────────────

class _SlideRevenue extends StatefulWidget {
  const _SlideRevenue();

  @override
  State<_SlideRevenue> createState() => _SlideRevenueState();
}

class _SlideRevenueState extends State<_SlideRevenue> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days[i],
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  _bar(0, 3),
                  _bar(1, 5),
                  _bar(2, 4),
                  _bar(3, 7),
                  _bar(4, 6),
                  _bar(5, 9),
                  _bar(6, 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Suivez vos revenus',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chiffre d\'affaires en temps réel, plats populaires, tendances de la semaine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.primary,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}
