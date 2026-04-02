import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait uniquement — maman Catherine tient son téléphone droit
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise les locales françaises pour intl
  await initializeDateFormatting('fr_FR', null);

  runApp(
    ProviderScope(
      child: App(),
    ),
  );
}
