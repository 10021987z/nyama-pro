import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/users_repository.dart';

/// État local du profil utilisateur (avatar + infos de base).
/// Hydraté au démarrage depuis SecureStorage (affichage instantané),
/// puis synchronisé avec le backend via `refresh()`.
class UserProfileState {
  final String? avatarUrl; // chemin relatif backend (`/api/v1/uploads/...`)
  final String? name;
  final String? phone;
  final bool isUploading;
  final String? error;

  const UserProfileState({
    this.avatarUrl,
    this.name,
    this.phone,
    this.isUploading = false,
    this.error,
  });

  UserProfileState copyWith({
    String? avatarUrl,
    String? name,
    String? phone,
    bool? isUploading,
    String? error,
    bool clearAvatar = false,
  }) =>
      UserProfileState(
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        name: name ?? this.name,
        phone: phone ?? this.phone,
        isUploading: isUploading ?? this.isUploading,
        error: error,
      );
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final UsersRepository _repo;

  UserProfileNotifier(this._repo) : super(const UserProfileState()) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final cached = await SecureStorage.getAvatarUrl();
    if (!mounted) return;
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(avatarUrl: cached);
    }
    // Puis sync serveur, sans bloquer
    refresh();
  }

  Future<void> refresh() async {
    try {
      final me = await _repo.fetchMe();
      if (!mounted) return;
      state = state.copyWith(
        avatarUrl: me.avatarUrl,
        name: me.name,
        phone: me.phone,
      );
      if (me.avatarUrl != null && me.avatarUrl!.isNotEmpty) {
        await SecureStorage.saveAvatarUrl(me.avatarUrl!);
      }
    } catch (_) {
      // silencieux : on garde la valeur en cache
    }
  }

  Future<void> uploadAvatar(File file) async {
    state = state.copyWith(isUploading: true, error: null);
    try {
      final url = await _repo.uploadAvatar(file);
      if (!mounted) return;
      await SecureStorage.saveAvatarUrl(url);
      state = state.copyWith(avatarUrl: url, isUploading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> clearOnLogout() async {
    await SecureStorage.clearAvatarUrl();
    if (!mounted) return;
    state = const UserProfileState();
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(ref.read(usersRepositoryProvider));
});
