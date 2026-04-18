// ─── TodayStatsModel ─────────────────────────────────────────────────────────

class TodayStatsModel {
  final int ordersCount;
  final int revenueXaf;
  final double avgRating;
  final int prepTimeAvg; // minutes — base prep time average for the cook
  final List<HourlyBreakdownEntry> hourly;

  const TodayStatsModel({
    this.ordersCount = 0,
    this.revenueXaf = 0,
    this.avgRating = 0.0,
    this.prepTimeAvg = 15,
    this.hourly = const [],
  });

  factory TodayStatsModel.fromJson(Map<String, dynamic> json) =>
      TodayStatsModel(
        ordersCount: (json['ordersCount'] as num?)?.toInt() ??
            (json['orders'] as num?)?.toInt() ??
            (json['ordersToday'] as num?)?.toInt() ??
            0,
        revenueXaf: (json['revenueXaf'] as num?)?.toInt() ??
            (json['revenue'] as num?)?.toInt() ??
            (json['revenueToday'] as num?)?.toInt() ??
            0,
        avgRating: (json['avgRating'] as num?)?.toDouble() ??
            (json['rating'] as num?)?.toDouble() ??
            0.0,
        prepTimeAvg: (json['prepTimeAvg'] as num?)?.toInt() ??
            (json['prepTimeAvgMin'] as num?)?.toInt() ??
            15,
        hourly: (json['hourly'] as List<dynamic>? ??
                json['hourlyBreakdown'] as List<dynamic>? ??
                const <dynamic>[])
            .map((e) =>
                HourlyBreakdownEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class HourlyBreakdownEntry {
  final int hour; // 0..23
  final int ordersCount;
  final int revenueXaf;

  const HourlyBreakdownEntry({
    required this.hour,
    this.ordersCount = 0,
    this.revenueXaf = 0,
  });

  factory HourlyBreakdownEntry.fromJson(Map<String, dynamic> json) =>
      HourlyBreakdownEntry(
        hour: (json['hour'] as num?)?.toInt() ?? 0,
        ordersCount: (json['ordersCount'] as num?)?.toInt() ??
            (json['orders'] as num?)?.toInt() ??
            0,
        revenueXaf: (json['revenueXaf'] as num?)?.toInt() ??
            (json['revenue'] as num?)?.toInt() ??
            0,
      );
}

// ─── WeeklyStatsModel ────────────────────────────────────────────────────────

class WeeklyStatsModel {
  final int currentOrders;
  final int currentRevenueXaf;
  final int previousOrders;
  final int previousRevenueXaf;
  final double growthPercent; // +12.4, -3.2 ...
  final String? topDishName;
  final int? topDishSales;

  const WeeklyStatsModel({
    this.currentOrders = 0,
    this.currentRevenueXaf = 0,
    this.previousOrders = 0,
    this.previousRevenueXaf = 0,
    this.growthPercent = 0.0,
    this.topDishName,
    this.topDishSales,
  });

  factory WeeklyStatsModel.fromJson(Map<String, dynamic> json) {
    final current = json['currentWeek'] as Map<String, dynamic>? ?? const {};
    final previous = json['previousWeek'] as Map<String, dynamic>? ?? const {};
    final topDish = json['topDish'] as Map<String, dynamic>?;

    return WeeklyStatsModel(
      currentOrders: (current['ordersCount'] as num?)?.toInt() ??
          (current['orders'] as num?)?.toInt() ??
          0,
      currentRevenueXaf: (current['revenueXaf'] as num?)?.toInt() ??
          (current['revenue'] as num?)?.toInt() ??
          0,
      previousOrders: (previous['ordersCount'] as num?)?.toInt() ??
          (previous['orders'] as num?)?.toInt() ??
          0,
      previousRevenueXaf: (previous['revenueXaf'] as num?)?.toInt() ??
          (previous['revenue'] as num?)?.toInt() ??
          0,
      growthPercent: (json['growthPercent'] as num?)?.toDouble() ??
          (json['growth'] as num?)?.toDouble() ??
          0.0,
      topDishName: topDish?['name'] as String?,
      topDishSales:
          (topDish?['sales'] as num?)?.toInt() ?? (topDish?['count'] as num?)?.toInt(),
    );
  }
}

// ─── PrepTimeEstimateModel ───────────────────────────────────────────────────
//
// Backend (LOT A) returns `{ activeOrdersCount, estimatedPrepTimeMin }` from
// `GET /cook/orders/prep-time-estimate`. We keep `avgMinutes` as a tolerant
// fallback alias for older builds, but the canonical fields below match the
// current contract.

class PrepTimeEstimateModel {
  final int activeOrdersCount;
  final int estimatedPrepTimeMin;

  const PrepTimeEstimateModel({
    this.activeOrdersCount = 0,
    this.estimatedPrepTimeMin = 15,
  });

  /// Backwards-compat getter — some UI surfaces may still reference the
  /// previous `avgMinutes` name. Always returns the latest estimated prep time.
  int get avgMinutes => estimatedPrepTimeMin;

  factory PrepTimeEstimateModel.fromJson(Map<String, dynamic> json) =>
      PrepTimeEstimateModel(
        activeOrdersCount: (json['activeOrdersCount'] as num?)?.toInt() ?? 0,
        estimatedPrepTimeMin:
            (json['estimatedPrepTimeMin'] as num?)?.toInt() ??
                (json['avgMinutes'] as num?)?.toInt() ??
                (json['avg'] as num?)?.toInt() ??
                15,
      );
}

// ─── RushStatusModel ─────────────────────────────────────────────────────────

class RushStatusModel {
  final bool active;
  final DateTime? until;
  final int? durationMinutes;

  const RushStatusModel({
    this.active = false,
    this.until,
    this.durationMinutes,
  });

  factory RushStatusModel.fromJson(Map<String, dynamic> json) {
    // LOT A backend returns the full CookProfile after PATCH /cook/status/rush
    // → fields `isRush`, `rushUntil`. Older/legacy responses may use `rush`,
    // `active`, `until`. Accept all forms.
    final activeRaw = json['isRush'] ??
        json['rush'] ??
        json['active'] ??
        false;
    final untilRaw = json['rushUntil'] ?? json['until'];
    return RushStatusModel(
      active: activeRaw is bool ? activeRaw : false,
      until: untilRaw is String ? DateTime.tryParse(untilRaw) : null,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }
}
