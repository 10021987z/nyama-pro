import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Splash "Cuisine de Nyama" — animation 4 phases identique à l'app client
/// (logo → bounce → titre → sous-titre) puis redirection /home ou /login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _bounceY;
  late final Animation<double> _bouncePulse;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleTranslateY;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _subtitleTranslateY;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.16, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.16, curve: Curves.easeOut),
      ),
    );

    _bounceY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -15.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -15.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.32),
      ),
    );
    _bouncePulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.32),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.48, curve: Curves.easeOut),
      ),
    );
    _titleTranslateY = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.48, curve: Curves.easeOut),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.56, curve: Curves.easeOut),
      ),
    );
    _subtitleTranslateY = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.56, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2500), _decideRoute);
  }

  void _decideRoute() {
    if (!mounted) return;
    final status = ref.read(authStateProvider).status;
    if (status == AuthStatus.authenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) => Opacity(
                opacity: _logoOpacity.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, _bounceY.value),
                  child: Transform.scale(
                    scale: _logoScale.value * _bouncePulse.value,
                    child: Transform.rotate(
                      angle: 3 * math.pi / 180,
                      child: child,
                    ),
                  ),
                ),
              ),
              child: const _LogoCard(),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) => Opacity(
                opacity: _titleOpacity.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, _titleTranslateY.value),
                  child: child,
                ),
              ),
              child: const Text(
                'CUISINE DE NYAMA',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) => Opacity(
                opacity: _subtitleOpacity.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, _subtitleTranslateY.value),
                  child: child,
                ),
              ),
              child: Text(
                'ESPACE CUISINIÈRE',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 12,
                  letterSpacing: 3.6,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 200,
            height: 200,
            margin: const EdgeInsets.only(top: 10, left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 34,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.asset(
                'assets/images/logo_nyama.jpg',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.restaurant_menu,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
