import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundService {
  SoundService._();

  static final _player = AudioPlayer();
  static bool _contextApplied = false;

  /// Force un contexte audio type "alarme/notification" afin que l'alerte
  /// nouvelle commande sonne même en mode silencieux Android (hors DND strict).
  static Future<void> _ensureAlertContext() async {
    if (_contextApplied) return;
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
      _contextApplied = true;
    } catch (e) {
      // ignore: avoid_print
      print('[SOUND] setAudioContext failed: $e');
    }
  }

  /// Alerte forte nouvelle commande — son + vibration 3×
  static Future<void> playNewOrderAlert() async {
    // ignore: avoid_print
    print('[SOUND] playNewOrderAlert()');
    await vibrateLong();
    await _ensureAlertContext();
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/new_order.mp3'));
    } catch (e) {
      // ignore: avoid_print
      print('[SOUND] new_order.mp3 failed: $e → fallback ding.mp3');
      try {
        await _player.play(AssetSource('sounds/ding.mp3'));
      } catch (e2) {
        // ignore: avoid_print
        print('[SOUND] fallback ding failed: $e2');
      }
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
