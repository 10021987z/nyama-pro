import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/l10n/translations.dart';
import 'core/services/push_notification_service.dart';
import 'core/storage/secure_storage.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait uniquement — maman Catherine tient son téléphone droit
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise les locales françaises pour intl
  await initializeDateFormatting('fr_FR', null);

  // Initialise les notifications push (no-op si Firebase non configuré)
  await PushNotificationService.instance.init();

  final storedLang = await SecureStorage.getLanguage();
  final initialLang = (storedLang != null && translations.containsKey(storedLang))
      ? storedLang
      : 'fr';

  // Détermine si l'onboarding doit être affiché en premier
  final onboardingDone = await isOnboardingCompleted();

  runApp(
    ProviderScope(
      overrides: [
        languageProvider.overrideWith((ref) => initialLang),
      ],
      child: App(initialLocation: onboardingDone ? '/splash' : '/onboarding'),
    ),
  );
}
