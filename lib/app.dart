import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_colors.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/socket_debug_overlay.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/phone_input_screen.dart';
import 'features/auth/screens/otp_verification_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/menu/screens/menu_screen.dart';
import 'features/menu/screens/menu_form_screen.dart';
import 'features/menu/screens/menu_add_ai_screen.dart';
import 'features/menu/data/models/menu_item_model.dart';
import 'features/revenue/screens/revenue_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/history/screens/history_detail_screen.dart';
import 'features/orders/data/models/cook_order_model.dart';
import 'features/reviews/screens/reviews_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/stats/screens/stats_detail_screen.dart';
import 'features/profile/screens/restaurant_presentation_screen.dart';
import 'features/profile/screens/help_support_screen.dart';
import 'features/profile/screens/faq_screen.dart';
import 'features/profile/screens/cgu_screen.dart';
import 'features/profile/screens/privacy_screen.dart';
import 'features/profile/screens/about_screen.dart';
import 'shared/widgets/pro_bottom_nav_bar.dart';

/// Flag global — passe à `false` pour cacher le bandeau debug socket en prod.
const bool kShowSocketDebug = true;

class App extends StatelessWidget {
  final String initialLocation;

  App({super.key, this.initialLocation = '/splash'})
      : _router = GoRouter(
          initialLocation: initialLocation,
          debugLogDiagnostics: false,
          routes: [
            GoRoute(
              path: '/splash',
              builder: (context, state) => const SplashScreen(),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (context, state) => const OnboardingScreen(),
            ),
            // Login = saisie téléphone + OTP (flux identique au client)
            GoRoute(
              path: '/login',
              builder: (context, state) => const PhoneInputScreen(),
            ),
            GoRoute(
              path: '/otp',
              builder: (context, state) {
                final phone = state.extra as String? ?? '';
                return OtpVerificationScreen(phone: phone);
              },
            ),
            // Shell principal avec bottom nav 4 tabs (Commandes/Menu/Revenus/Avis)
            GoRoute(
              path: '/home',
              builder: (context, state) => const MainShell(initialIndex: 0),
            ),
            GoRoute(
              path: '/orders',
              builder: (context, state) => const MainShell(initialIndex: 0),
            ),
            GoRoute(
              path: '/menu',
              builder: (context, state) => const MainShell(initialIndex: 1),
            ),
            GoRoute(
              path: '/menu/add',
              builder: (context, state) => const MenuAddAiScreen(),
            ),
            GoRoute(
              path: '/menu/edit/:id',
              builder: (context, state) =>
                  MenuFormScreen(item: state.extra as MenuItemModel?),
            ),
            GoRoute(
              path: '/revenue',
              builder: (context, state) => const MainShell(initialIndex: 2),
            ),
            GoRoute(
              path: '/reviews',
              builder: (context, state) => const MainShell(initialIndex: 3),
            ),
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsDetailScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/historique',
              builder: (context, state) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/history/:id',
              builder: (context, state) => HistoryDetailScreen(
                orderId: state.pathParameters['id']!,
                initialOrder: state.extra is CookOrderModel
                    ? state.extra as CookOrderModel
                    : null,
              ),
            ),
            // Profil accessible via l'avatar du header (hors shell)
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/profile/restaurant',
              builder: (context, state) =>
                  const RestaurantPresentationScreen(),
            ),
            GoRoute(
              path: '/profile/support',
              builder: (context, state) => const HelpSupportScreen(),
            ),
            GoRoute(
              path: '/profile/faq',
              builder: (context, state) => const FaqScreen(),
            ),
            GoRoute(
              path: '/profile/cgu',
              builder: (context, state) => const CguScreen(),
            ),
            GoRoute(
              path: '/profile/privacy',
              builder: (context, state) => const PrivacyScreen(),
            ),
            GoRoute(
              path: '/profile/about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
          errorBuilder: (context, state) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text('Page introuvable'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Accueil'),
                  ),
                ],
              ),
            ),
          ),
        );

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cuisine de Nyama',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'CM'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'CM'),
        Locale('fr', 'FR'),
        Locale('fr'),
        Locale('en'),
      ],
      builder: (context, child) {
        if (!kShowSocketDebug) return child ?? const SizedBox.shrink();
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const SocketDebugOverlay(),
          ],
        );
      },
    );
  }
}

// ── Shell principal avec bottom nav 4 tabs ──────────────────────────────────

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  static const _screens = [
    OrdersScreen(),
    MenuScreen(),
    RevenueScreen(),
    ReviewsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creme,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: offlineNotifier,
            builder: (context, isOffline, child) {
              if (!isOffline) return const SizedBox.shrink();
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    color: Colors.orange.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.wifi_off,
                            color: Colors.orange, size: 18),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Mode hors-ligne — Les données peuvent ne pas être à jour',
                            style: TextStyle(
                              color: Color(0xFF3D3D3D),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: ProBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
