import 'package:intl/intl.dart';

// ─── OrderReviewModel ─────────────────────────────────────────────────────────

class OrderReviewModel {
  final double cookRating;
  final double? riderRating;
  final String? comment;
  final DateTime createdAt;

  const OrderReviewModel({
    required this.cookRating,
    this.riderRating,
    this.comment,
    required this.createdAt,
  });

  factory OrderReviewModel.fromJson(Map<String, dynamic> json) =>
      OrderReviewModel(
        cookRating: (json['cookRating'] as num?)?.toDouble() ?? 0,
        riderRating: (json['riderRating'] as num?)?.toDouble(),
        comment: json['comment'] as String? ?? json['text'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ─── OrderItemModel ───────────────────────────────────────────────────────────

class OrderItemModel {
  final String menuItemName;
  final int quantity;
  final int unitPriceXaf;
  final int subtotalXaf;

  const OrderItemModel({
    required this.menuItemName,
    required this.quantity,
    required this.unitPriceXaf,
    required this.subtotalXaf,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        menuItemName: json['menuItemName'] as String? ??
            json['name'] as String? ??
            'Article',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPriceXaf: (json['unitPriceXaf'] as num?)?.toInt() ??
            (json['priceXaf'] as num?)?.toInt() ??
            0,
        subtotalXaf: (json['subtotalXaf'] as num?)?.toInt() ?? 0,
      );

  String get label => '$quantity× $menuItemName';
}

// ─── RiderInfo (livreur assigné) ──────────────────────────────────────────────

class RiderInfo {
  final String? id;
  final String name;
  final String? photoUrl;
  final String? phone;
  final int? etaMin;

  const RiderInfo({
    this.id,
    required this.name,
    this.photoUrl,
    this.phone,
    this.etaMin,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> json) => RiderInfo(
        id: (json['id'] ?? json['_id'])?.toString(),
        name: json['name'] as String? ?? json['fullName'] as String? ?? 'Livreur',
        photoUrl: json['photoUrl'] as String? ?? json['avatarUrl'] as String?,
        phone: json['phone'] as String?,
        etaMin: (json['etaMin'] as num?)?.toInt() ??
            (json['eta'] as num?)?.toInt(),
      );
}

// ─── CookOrderModel ───────────────────────────────────────────────────────────

class CookOrderModel {
  final String id;
  final String status;
  final String clientName;
  final String? clientPhone;
  final List<OrderItemModel> items;
  final int totalXaf;
  final int deliveryFeeXaf;
  final String? landmark;
  final String? clientNote;

  // Paiement
  final String? paymentMethod; // 'cash' | 'mobile_money' | 'card' | ...
  final String? paymentStatus; // 'paid' | 'pending' | 'unpaid'

  // Rider (quand assigned / picked_up)
  final RiderInfo? rider;

  // Timestamps
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final OrderReviewModel? review;

  const CookOrderModel({
    required this.id,
    required this.status,
    required this.clientName,
    this.clientPhone,
    required this.items,
    required this.totalXaf,
    required this.deliveryFeeXaf,
    this.landmark,
    this.clientNote,
    this.paymentMethod,
    this.paymentStatus,
    this.rider,
    required this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancelReason,
    this.review,
  });

  factory CookOrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Client peut être dans 'client', 'user', ou directement 'clientName'
    final clientData = json['client'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>?;
    final clientName = json['clientName'] as String? ??
        clientData?['name'] as String? ??
        clientData?['phone'] as String? ??
        'Client';

    // Payment
    final paymentData = json['payment'] as Map<String, dynamic>?;
    final paymentMethod = json['paymentMethod'] as String? ??
        paymentData?['method'] as String?;
    final paymentStatus = json['paymentStatus'] as String? ??
        paymentData?['status'] as String?;

    // Rider
    final riderData = json['rider'] as Map<String, dynamic>? ??
        json['driver'] as Map<String, dynamic>? ??
        json['delivery']?['rider'] as Map<String, dynamic>?;

    return CookOrderModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      clientName: clientName,
      clientPhone: json['clientPhone'] as String? ??
          clientData?['phone'] as String?,
      items: itemsList,
      totalXaf: (json['totalXaf'] as num?)?.toInt() ?? 0,
      deliveryFeeXaf: (json['deliveryFeeXaf'] as num?)?.toInt() ?? 0,
      landmark: json['landmark'] as String? ??
          json['delivery']?['landmark'] as String?,
      clientNote: json['clientNote'] as String? ??
          json['noteForCook'] as String?,
      paymentMethod: paymentMethod?.toLowerCase(),
      paymentStatus: paymentStatus?.toLowerCase(),
      rider: riderData != null ? RiderInfo.fromJson(riderData) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
      readyAt: json['readyAt'] != null
          ? DateTime.tryParse(json['readyAt'] as String)
          : null,
      assignedAt: json['assignedAt'] != null
          ? DateTime.tryParse(json['assignedAt'] as String)
          : null,
      pickedUpAt: json['pickedUpAt'] != null
          ? DateTime.tryParse(json['pickedUpAt'] as String)
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'] as String)
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      cancelReason: json['cancelReason'] as String? ??
          json['rejectionReason'] as String?,
      review: json['review'] is Map
          ? OrderReviewModel.fromJson(
              json['review'] as Map<String, dynamic>)
          : null,
    );
  }

  CookOrderModel copyWith({
    String? status,
    DateTime? acceptedAt,
    DateTime? readyAt,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    RiderInfo? rider,
  }) =>
      CookOrderModel(
        id: id,
        status: status ?? this.status,
        clientName: clientName,
        clientPhone: clientPhone,
        items: items,
        totalXaf: totalXaf,
        deliveryFeeXaf: deliveryFeeXaf,
        landmark: landmark,
        clientNote: clientNote,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        rider: rider ?? this.rider,
        createdAt: createdAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        readyAt: readyAt ?? this.readyAt,
        assignedAt: assignedAt ?? this.assignedAt,
        pickedUpAt: pickedUpAt ?? this.pickedUpAt,
        deliveredAt: deliveredAt,
        cancelledAt: cancelledAt,
        cancelReason: cancelReason,
        review: review,
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get shortId => id.length >= 4
      ? id.substring(0, 4).toUpperCase()
      : id.toUpperCase();

  /// "il y a X min"
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    final minutes = diff.inMinutes;
    if (minutes < 1) return 'il y a quelques secondes';
    if (minutes < 60) return 'il y a $minutes min';
    final hours = diff.inHours;
    return 'il y a $hours h';
  }

  /// Heure d'arrivée "12h34"
  String get arrivalTime =>
      DateFormat("HH'h'mm", 'fr').format(createdAt.toLocal());

  /// Minutes écoulées depuis la création (pour timer urgence)
  int get minutesSinceCreation =>
      DateTime.now().difference(createdAt).inMinutes;

  /// Minutes depuis acceptation (pour timer préparation)
  int get minutesSinceAccepted {
    if (acceptedAt == null) return 0;
    return DateTime.now().difference(acceptedAt!).inMinutes;
  }

  String get formattedDate =>
      DateFormat('d MMM à HH:mm', 'fr').format(createdAt.toLocal());

  // ── Status getters ────────────────────────────────────────────────────────

  bool get isPending => status == 'pending' || status == 'confirmed';
  bool get isPreparing => status == 'preparing';
  bool get isReady => status == 'ready';
  bool get isAssigned => status == 'assigned';
  bool get isPickedUp =>
      status == 'picked_up' || status == 'pickedup' || status == 'delivering';
  bool get isDelivering => isAssigned || isPickedUp;
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isActive =>
      isPending || isPreparing || isReady || isDelivering;

  // ── Paiement helpers ──────────────────────────────────────────────────────

  /// La commande est payée en ligne (mobile money / carte)
  bool get isPaid =>
      paymentStatus == 'paid' ||
      status == 'confirmed' && paymentMethod != 'cash';

  /// Paiement cash à la livraison
  bool get isCashOnDelivery =>
      paymentMethod == 'cash' || (paymentStatus == 'pending' && !isPaid);

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash':
        return 'Cash';
      case 'mobile_money':
      case 'mobilemoney':
      case 'momo':
        return 'Mobile Money';
      case 'card':
        return 'Carte';
      default:
        return isPaid ? 'Payé' : 'Cash';
    }
  }

  /// Étape de la timeline : 0=Reçue, 1=Acceptée, 2=Prête, 3=Livrée
  int get timelineStep {
    if (isDelivered) return 3;
    if (isDelivering) return 2;
    if (isReady) return 2;
    if (isPreparing) return 1;
    return 0;
  }

  /// Résumé condensé des plats : "2x Ndolé, 1x Miondo"
  String get itemsSummary =>
      items.map((i) => '${i.quantity}x ${i.menuItemName}').join(', ');

  /// Date complète : "2 avr. 2026 à 12h15"
  String get formattedFullDate =>
      DateFormat("d MMM yyyy 'à' HH'h'mm", 'fr').format(createdAt.toLocal());
}

// ─── DashboardModel ───────────────────────────────────────────────────────────

class DashboardModel {
  final int ordersToday;
  final int revenueToday;
  final int pendingOrders;
  final int preparingOrders;
  final double avgRating;
  final int totalOrders;

  const DashboardModel({
    this.ordersToday = 0,
    this.revenueToday = 0,
    this.pendingOrders = 0,
    this.preparingOrders = 0,
    this.avgRating = 0.0,
    this.totalOrders = 0,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) => DashboardModel(
        ordersToday: (json['ordersToday'] as num?)?.toInt() ?? 0,
        revenueToday: (json['revenueToday'] as num?)?.toInt() ?? 0,
        pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
        preparingOrders: (json['preparingOrders'] as num?)?.toInt() ?? 0,
        avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
        totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      );
}
