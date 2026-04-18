import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/socket_provider.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../shared/widgets/compact_order_timeline.dart';
import '../data/messages_repository.dart';
import '../data/models/cook_order_model.dart';
import '../data/models/order_message_model.dart';
import '../providers/orders_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final CookOrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _msgScroll = ScrollController();
  final _msgRepo = MessagesRepository();

  Timer? _pollTimer;
  bool _sending = false;
  List<OrderMessageModel> _messages = const [];

  String get _orderId => widget.order.id;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Essaye d'écouter le socket, sinon polling 5s.
    final socket = ref.read(socketServiceProvider);
    final connected = socket.isConnected;
    if (connected) {
      // Backend (events.gateway.ts) listens for `join:order` and joins the
      // socket to room `order-${orderId}` where it emits `message:new`.
      socket.emit('join:order', {'orderId': _orderId});
      socket.on('message:new', _onSocketMessage);
    } else {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadMessages(silent: true),
      );
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgScroll.dispose();
    _pollTimer?.cancel();
    try {
      final socket = ref.read(socketServiceProvider);
      socket.off('message:new');
      // No `leave` event on backend — the room is cleaned up on disconnect.
    } catch (_) {}
    super.dispose();
  }

  void _onSocketMessage(dynamic data) {
    if (!mounted) return;
    if (data is! Map) return;
    final oid = data['orderId']?.toString();
    if (oid != null && oid != _orderId) return;
    try {
      final m = OrderMessageModel.fromJson(Map<String, dynamic>.from(data));
      SoundService.playDing();
      setState(() => _messages = [..._messages, m]);
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final list = await _msgRepo.getMessages(_orderId);
      if (!mounted) return;
      // Ding sur nouveau message entrant (hors ceux envoyés par la cuisinière)
      final prev = _messages.length;
      if (!silent && list.length > prev && _messages.isNotEmpty) {
        final last = list.last;
        if (!last.isFromCook) SoundService.playDing();
      }
      setState(() => _messages = list);
      _scrollToBottom();
    } catch (_) {
      // Silencieux — on garde la liste existante
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_msgScroll.hasClients) return;
      _msgScroll.animateTo(
        _msgScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    // Optimistic
    final optimistic = OrderMessageModel(
      id: 'tmp-${DateTime.now().microsecondsSinceEpoch}',
      orderId: _orderId,
      senderRole: 'cook',
      senderName: 'Moi',
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, optimistic];
      _msgCtrl.clear();
    });
    _scrollToBottom();

    try {
      await _msgRepo.postMessage(_orderId, text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Envoi impossible : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _callClient() async {
    final phone = widget.order.clientPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _accept() async {
    try {
      await ref.read(cookOrdersProvider.notifier).accept(_orderId);
      if (!mounted) return;
      SoundService.playSuccessSound();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur : $e'),
        ),
      );
    }
  }

  Future<void> _markReady() async {
    try {
      await ref.read(cookOrdersProvider.notifier).markReady(_orderId);
      if (!mounted) return;
      SoundService.playSuccessSound();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur : $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Récupère la version la plus récente de la commande depuis le store
    final storeOrder = ref.watch(cookOrdersProvider).pending
        .followedBy(ref.watch(cookOrdersProvider).preparing)
        .followedBy(ref.watch(cookOrdersProvider).ready)
        .followedBy(ref.watch(cookOrdersProvider).delivering)
        .cast<CookOrderModel?>()
        .firstWhere((o) => o?.id == _orderId, orElse: () => null);

    final order = storeOrder ?? widget.order;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          'Commande #${order.shortId}',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Hero(
              tag: 'order-${order.id}',
              flightShuttleBuilder: (_, __, ___, ____, _____) =>
                  Material(color: Colors.transparent, child: const SizedBox()),
              child: Material(
                color: Colors.transparent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _header(order),
                    const SizedBox(height: 12),
                    _card(
                      child: CompactOrderTimeline(
                        currentStep: order.compactTimelineStep,
                        showLabels: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _clientCard(order),
                    const SizedBox(height: 12),
                    _itemsCard(order),
                    if ((order.clientNote ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _allergyBanner(order.clientNote!),
                    ],
                    const SizedBox(height: 12),
                    _paymentCard(order),
                    const SizedBox(height: 18),
                    _chatSection(),
                  ],
                ),
              ),
            ),
          ),
          _bottomActions(order),
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _header(CookOrderModel o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#${o.shortId}',
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.formattedFullDate,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  o.timeAgo,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            o.totalXaf.toFcfa(),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientCard(CookOrderModel o) {
    final phone = o.clientPhone;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLIENT',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 22, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o.clientName,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (phone != null && phone.isNotEmpty)
                IconButton.filled(
                  onPressed: _callClient,
                  icon: const Icon(Icons.phone_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          if (o.landmark != null && o.landmark!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    o.landmark!,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard(CookOrderModel o) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ARTICLES',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in o.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quantity}×',
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.menuItemName,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  item.subtotalXaf.toFcfa(),
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                o.totalXaf.toFcfa(),
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _allergyBanner(String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOTE / ALLERGIES',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(CookOrderModel o) {
    return _card(
      child: Row(
        children: [
          Icon(
            o.isPaid
                ? Icons.verified_rounded
                : Icons.account_balance_wallet_rounded,
            color: o.isPaid ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAIEMENT',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  o.isPaid
                      ? '${o.paymentMethodLabel} · Payé'
                      : '${o.paymentMethodLabel} · À payer',
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'COMMENTAIRES LIVREUR',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80, maxHeight: 260),
            child: _messages.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Aucun message pour le moment',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _msgScroll,
                    shrinkWrap: true,
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _msgBubble(_messages[i]),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Écrire au livreur...',
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _msgBubble(OrderMessageModel m) {
    final fromMe = m.isFromCook;
    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fromMe ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(fromMe ? 12 : 4),
              bottomRight: Radius.circular(fromMe ? 4 : 12),
            ),
          ),
          child: Text(
            m.text,
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 14,
              color: fromMe ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomActions(CookOrderModel o) {
    Widget? primary;
    if (o.isPending) {
      primary = _actionButton(
        label: 'ACCEPTER',
        color: AppColors.forestGreen,
        icon: Icons.check_rounded,
        onTap: _accept,
      );
    } else if (o.isPreparing) {
      primary = _actionButton(
        label: "C'EST PRÊT",
        color: AppColors.primary,
        icon: Icons.check_circle_outline_rounded,
        onTap: _markReady,
      );
    }

    if (primary == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: primary,
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
