import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundService {
  SoundService._();

  static final _player = AudioPlayer();

  /// Alerte forte nouvelle commande — son + vibration 3×
  static Future<void> playNewOrderAlert() async {
    await vibrateLong();
    try {
      // Si le fichier existe dans assets/sounds/new_order.mp3
      await _player.play(AssetSource('sounds/new_order.mp3'));
    } catch (_) {
      // En dev : pas de fichier audio, on log seulement
      assert(() {
        // ignore: avoid_print
        print('🔔 ALERTE SONORE — NOUVELLE COMMANDE');
        return true;
      }());
    }
  }

  /// Son court de succès (acceptation, validation)
  static Future<void> playSuccessSound() async {
    try {
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (_) {
      assert(() {
        // ignore: avoid_print
        print('✅ SON SUCCÈS');
        return true;
      }());
    }
    await _vibrateShort();
  }

  /// Son d'erreur / refus
  static Future<void> playErrorSound() async {
    try {
      await _player.play(AssetSource('sounds/error.mp3'));
    } catch (_) {
      assert(() {
        // ignore: avoid_print
        print('❌ SON ERREUR');
        return true;
      }());
    }
  }

  /// Petit "ding" doux quand un nouveau message arrive dans un chat de commande.
  /// Fichier attendu : `assets/sounds/ding.mp3` (à fournir, facultatif).
  static Future<void> playDing() async {
    try {
      final p = AudioPlayer();
      await p.setVolume(0.5);
      await p.play(AssetSource('sounds/ding.mp3'));
    } catch (_) {
      assert(() {
        // ignore: avoid_print
        print('🔔 DING (nouveau message)');
        return true;
      }());
    }
  }

  /// "Cha-ching" satisfaisant lorsqu'une commande passe au statut DELIVERED.
  /// Fichier attendu : `assets/sounds/cha-ching.mp3` (à fournir).
  static Future<void> playChaChing() async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource('sounds/cha-ching.mp3'));
    } catch (_) {
      assert(() {
        // ignore: avoid_print
        print('💰 CHA-CHING (commande livrée)');
        return true;
      }());
    }
  }

  /// Vibration longue 3× (500ms ON / 200ms OFF)
  static Future<void> vibrateLong() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 500],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    } catch (_) {
      assert(() {
        // ignore: avoid_print
        print('📳 VIBRATION LONGUE');
        return true;
      }());
    }
  }

  /// Vibration courte simple
  static Future<void> _vibrateShort() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(duration: 150);
      }
    } catch (_) {}
  }
}
