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

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final nested = json['menuItem'] as Map<String, dynamic>?;
    final rawName = (nested?['name'] as String?) ??
        (json['menuItemName'] as String?) ??
        (json['name'] as String?);
    final menuItemId =
        (json['menuItemId'] ?? nested?['id'] ?? nested?['_id'])?.toString();

    String resolvedName;
    if (rawName != null && rawName.trim().isNotEmpty && !_looksLikeIdOrSlug(rawName)) {
      resolvedName = rawName.trim();
    } else if (menuItemId != null && menuItemId.isNotEmpty) {
      final shortId =
          menuItemId.length >= 6 ? menuItemId.substring(0, 6) : menuItemId;
      resolvedName = 'Plat #$shortId';
    } else {
      resolvedName = 'Article';
    }

    return OrderItemModel(
      menuItemName: resolvedName,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceXaf: (json['unitPriceXaf'] as num?)?.toInt() ??
          (nested?['priceXaf'] as num?)?.toInt() ??
          (json['priceXaf'] as num?)?.toInt() ??
          0,
      subtotalXaf: (json['subtotalXaf'] as num?)?.toInt() ?? 0,
    );
  }

  /// Heuristic — value is a UUID, raw id, or slug ("mi-ndole-complet")
  /// rather than a human-readable plate name.
  static bool _looksLikeIdOrSlug(String s) {
    final t = s.trim();
    if (t.isEmpty) return true;
    // UUID v4 pattern (with or without dashes).
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$');
    if (uuid.hasMatch(t)) return true;
    // Pure hex / pure id-like (no spaces, all lowercase + dashes, length > 8).
    if (!t.contains(' ') &&
        t.length > 8 &&
        RegExp(r'^[a-z0-9_\-]+$').hasMatch(t)) {
      return true;
    }
    return false;
  }

  String get label => '$quantity× $menuItemName';
}

// ─── RiderInfo (livreur assigné) ──────────────────────────────────────────────

class RiderInfo {
  final String? id;
  final String name;
  final String? photoUrl;
  final String? phone;
  final int? etaMin;
  final String? vehicleType; // ex: "MOTO", "VELO", "VOITURE"
  final String? plateNumber; // ex: "LT-2341-A"

  const RiderInfo({
    this.id,
    required this.name,
    this.photoUrl,
    this.phone,
    this.etaMin,
    this.vehicleType,
    this.plateNumber,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    // Gère : { vehicle: { type, plate } } ou directement vehicleType/plateNumber
    String? vType = json['vehicleType'] as String? ??
        json['vehicle_type'] as String?;
    String? plate = json['plateNumber'] as String? ??
        json['plate'] as String? ??
        json['licensePlate'] as String?;
    final vehicle = json['vehicle'];
    if (vehicle is Map) {
      vType ??= vehicle['type'] as String? ?? vehicle['name'] as String?;
      plate ??= vehicle['plate'] as String? ??
          vehicle['plateNumber'] as String? ??
          vehicle['licensePlate'] as String?;
    }

    return RiderInfo(
      id: (json['id'] ?? json['_id'] ?? json['riderId'])?.toString(),
      name: json['name'] as String? ??
          json['fullName'] as String? ??
          json['displayName'] as String? ??
          'Livreur',
      photoUrl: json['photoUrl'] as String? ??
          json['avatarUrl'] as String? ??
          json['photo'] as String? ??
          json['avatar'] as String?,
      phone: json['phone'] as String? ?? json['phoneNumber'] as String?,
      etaMin: (json['etaMin'] as num?)?.toInt() ??
          (json['eta'] as num?)?.toInt(),
      vehicleType: vType?.toUpperCase(),
      plateNumber: plate,
    );
  }

  /// "MOTO · LT-2341-A" ou "MOTO" ou plaque seule
  String? get vehicleLabel {
    final parts = <String>[];
    if (vehicleType != null && vehicleType!.isNotEmpty) parts.add(vehicleType!);
    if (plateNumber != null && plateNumber!.isNotEmpty) parts.add(plateNumber!);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// Initiales pour avatar de fallback : "Kevin Tchiaze" → "KT"
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.isNotEmpty ? p.substring(0, 1).toUpperCase() : '?';
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
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

  // Étape de livraison détaillée (envoyée par delivery:status)
  // ex: "en_route_restaurant" | "at_restaurant" | "en_route_client" | "at_client"
  final String? deliveryStage;
  // Libellé FR dynamique envoyé par le backend (déjà mappé)
  final String? deliveryStatusLabel;
  // Timestamp d'entrée dans l'étape de livraison courante
  final DateTime? deliveryStageAt;

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
    this.deliveryStage,
    this.deliveryStatusLabel,
    this.deliveryStageAt,
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

    // Delivery stage / label (envoyés par delivery:status ou dans le getAll)
    final deliveryData = json['delivery'];
    String? deliveryStage = json['deliveryStage'] as String? ??
        json['deliveryStatus'] as String? ??
        json['deliverySubStatus'] as String?;
    String? deliveryStatusLabel = json['deliveryStatusLabel'] as String? ??
        json['statusLabel'] as String?;
    DateTime? deliveryStageAt;
    if (deliveryData is Map) {
      deliveryStage ??= deliveryData['stage'] as String? ??
          deliveryData['status'] as String? ??
          deliveryData['subStatus'] as String?;
      deliveryStatusLabel ??= deliveryData['statusLabel'] as String? ??
          deliveryData['label'] as String?;
      final t = deliveryData['stageAt'] ?? deliveryData['updatedAt'];
      if (t is String) deliveryStageAt = DateTime.tryParse(t);
    }

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
      deliveryStage: deliveryStage?.toLowerCase(),
      deliveryStatusLabel: deliveryStatusLabel,
      deliveryStageAt: deliveryStageAt,
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
    String? deliveryStage,
    String? deliveryStatusLabel,
    DateTime? deliveryStageAt,
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
        deliveryStage: deliveryStage ?? this.deliveryStage,
        deliveryStatusLabel: deliveryStatusLabel ?? this.deliveryStatusLabel,
        deliveryStageAt: deliveryStageAt ?? this.deliveryStageAt,
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

  /// Étape sur la timeline 7-points utilisée par CompactOrderTimeline :
  /// 0=Reçue, 1=Acceptée, 2=En préparation, 3=Prête, 4=Récupérée, 5=En route, 6=Livrée.
  int get compactTimelineStep {
    if (isDelivered) return 6;
    if (isPickedUp) return 5; // "En route" après pickup
    if (isAssigned) return 4; // "Récupérée" = livreur assigné/en chemin côté resto
    if (isReady) return 3;
    if (isPreparing) return 2;
    // acceptedAt non null = acceptée sans être encore en préparation
    if (acceptedAt != null) return 1;
    return 0;
  }

  /// Résumé condensé des plats : "2x Ndolé, 1x Miondo"
  String get itemsSummary =>
      items.map((i) => '${i.quantity}x ${i.menuItemName}').join(', ');

  /// Date complète : "2 avr. 2026 à 12h15"
  String get formattedFullDate =>
      DateFormat("d MMM yyyy 'à' HH'h'mm", 'fr').format(createdAt.toLocal());

  // ── Delivery stage helpers ────────────────────────────────────────────────

  /// Canonicalise l'étape de livraison en l'un de :
  /// 'en_route_restaurant' | 'at_restaurant' | 'en_route_client' | 'at_client'
  String get deliveryStageKey {
    final raw = (deliveryStage ?? '').toLowerCase();
    if (raw.contains('at_client') ||
        raw.contains('arrived_client') ||
        raw == 'arrived' ||
        raw == 'at_customer') {
      return 'at_client';
    }
    if (raw.contains('en_route_client') ||
        raw.contains('to_client') ||
        raw.contains('on_delivery') ||
        raw.contains('in_transit') ||
        raw == 'delivering' ||
        raw == 'picked_up' ||
        raw == 'pickedup') {
      return 'en_route_client';
    }
    if (raw.contains('at_restaurant') ||
        raw.contains('at_pickup') ||
        raw.contains('arrived_restaurant')) {
      return 'at_restaurant';
    }
    if (raw.contains('to_restaurant') ||
        raw.contains('en_route_restaurant') ||
        raw.contains('to_pickup') ||
        raw == 'assigned' ||
        raw == 'heading_to_pickup') {
      return 'en_route_restaurant';
    }
    // Fallback basé sur status
    if (isPickedUp) return 'en_route_client';
    if (isAssigned) return 'en_route_restaurant';
    return 'en_route_restaurant';
  }

  /// Libellé FR dynamique pour le badge.
  /// Priorité au label envoyé par le backend, sinon fallback mappé.
  String get deliveryStageLabel {
    final server = deliveryStatusLabel?.trim();
    if (server != null && server.isNotEmpty) return server;
    switch (deliveryStageKey) {
      case 'at_client':
        return 'Arrivé chez le client';
      case 'en_route_client':
        return 'En route vers le client';
      case 'at_restaurant':
        return 'Chez le restaurant';
      case 'en_route_restaurant':
      default:
        return 'En route vers le restaurant';
    }
  }

  /// Minutes écoulées depuis l'entrée dans l'étape courante.
  int get minutesInCurrentStage {
    final ref = deliveryStageAt ??
        (deliveryStageKey == 'en_route_client' ? pickedUpAt : assignedAt) ??
        readyAt;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inMinutes;
  }

  /// Temps écoulé lisible : "il y a 3 min"
  String get timeInStage {
    final m = minutesInCurrentStage;
    if (m < 1) return 'à l\'instant';
    if (m < 60) return 'il y a $m min';
    return 'il y a ${m ~/ 60} h';
  }
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
