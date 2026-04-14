import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

/// Provider global pour la langue active.
final languageProvider = StateProvider<String>((ref) => 'fr');

/// Traduit une clé dans la langue active.
String t(String key, WidgetRef ref) {
  final lang = ref.watch(languageProvider);
  return translations[lang]?[key] ?? translations['fr']?[key] ?? key;
}

/// Charge la langue depuis SecureStorage et met à jour le provider.
Future<void> initLanguage(WidgetRef ref) async {
  final lang = await SecureStorage.getLanguage();
  if (lang != null && translations.containsKey(lang)) {
    ref.read(languageProvider.notifier).state = lang;
  }
}

const translations = <String, Map<String, String>>{
  'fr': {
    'orders': 'Commandes',
    'menu': 'Mon Menu',
    'dashboard': 'Tableau de bord',
    'profile': 'Profil',
    'new_orders': 'NOUVELLES',
    'in_progress': 'EN COURS',
    'ready': 'PRÊTES',
    'accept': 'Accepter',
    'reject': 'Refuser',
    'mark_ready': "C'est prêt !",
    'no_orders': 'Aucune commande',
    'rider_notified': 'Livreur notifié',
    'order_accepted': 'Commande acceptée — en préparation',
    'today': "Aujourd'hui",
    'revenue': 'Revenus',
    'pending_count': 'En attente',
    'language': 'Langue',
    'logout': 'Se déconnecter',
    'support': 'Aide & Support',
    'tos': "Conditions d'utilisation",
  },
  'en': {
    'orders': 'Orders',
    'menu': 'My Menu',
    'dashboard': 'Dashboard',
    'profile': 'Profile',
    'new_orders': 'NEW',
    'in_progress': 'IN PROGRESS',
    'ready': 'READY',
    'accept': 'Accept',
    'reject': 'Reject',
    'mark_ready': "It's ready!",
    'no_orders': 'No orders',
    'rider_notified': 'Rider notified',
    'order_accepted': 'Order accepted — preparing',
    'today': 'Today',
    'revenue': 'Revenue',
    'pending_count': 'Pending',
    'language': 'Language',
    'logout': 'Log out',
    'support': 'Help & Support',
    'tos': 'Terms of Service',
  },
  'pidgin': {
    'orders': 'Di chop dem',
    'menu': 'My food list',
    'dashboard': 'My place',
    'profile': 'My side',
    'new_orders': 'NEW NEW',
    'in_progress': 'I DEY COOK',
    'ready': 'E DON READY',
    'accept': 'Take am',
    'reject': 'Refuse',
    'mark_ready': "E don ready!",
    'no_orders': 'No chop dey',
    'rider_notified': 'Bensikin don sabi',
    'order_accepted': 'Chop don accept — I dey cook',
    'today': 'Today today',
    'revenue': 'Moni',
    'pending_count': 'Dey wait',
    'language': 'Language',
    'logout': 'Comot',
    'support': 'Help me',
    'tos': 'Di rules',
  },
};
