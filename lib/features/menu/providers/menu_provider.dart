import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/menu_repository.dart';
import '../data/models/menu_item_model.dart';

// ─── Repository provider ──────────────────────────────────────────────────────

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository();
});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MenuNotifier
    extends StateNotifier<AsyncValue<List<MenuItemModel>>> {
  final MenuRepository _repo;

  MenuNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getMenu());
  }

  Future<void> create(Map<String, dynamic> data) async {
    final item = await _repo.createItem(data);
    if (!mounted) return;
    state = state.whenData((list) => [item, ...list]);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final updated = await _repo.updateItem(id, data);
    if (!mounted) return;
    state = state.whenData(
        (list) => list.map((i) => i.id == id ? updated : i).toList());
  }

  Future<void> toggleAvailability(String id) async {
    final current =
        state.valueOrNull?.where((i) => i.id == id).firstOrNull;
    if (current == null) return;

    // Optimistic update
    state = state.whenData((list) => list
        .map((i) =>
            i.id == id ? i.copyWith(isAvailable: !i.isAvailable) : i)
        .toList());

    try {
      await _repo.updateItem(id, {'isAvailable': !current.isAvailable});
    } catch (_) {
      if (!mounted) return;
      // Revert on error
      state = state.whenData((list) => list
          .map((i) =>
              i.id == id ? i.copyWith(isAvailable: current.isAvailable) : i)
          .toList());
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    await _repo.deleteItem(id);
    if (!mounted) return;
    state = state
        .whenData((list) => list.where((i) => i.id != id).toList());
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final cookMenuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuItemModel>>>(
  (ref) => MenuNotifier(ref.read(menuRepositoryProvider)),
);
