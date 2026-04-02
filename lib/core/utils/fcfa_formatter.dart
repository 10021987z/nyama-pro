import 'package:intl/intl.dart';

class FcfaFormatter {
  FcfaFormatter._();

  static final _fmt = NumberFormat('#,###', 'fr_FR');

  static String format(int amount) {
    // Utilise l'espace fine insécable comme séparateur de milliers
    return '${_fmt.format(amount).replaceAll('\u00a0', '\u202f')} FCFA';
  }
}

extension FcfaIntExtension on int {
  String toFcfa() => FcfaFormatter.format(this);
}

extension FcfaDoubleExtension on double {
  String toFcfa() => FcfaFormatter.format(toInt());
}
