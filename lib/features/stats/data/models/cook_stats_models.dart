// ─── TodayStatsModel ─────────────────────────────────────────────────────────

class TodayStatsModel {
  final int ordersCount;
  final int revenueXaf;
  final double avgRating;
  final List<HourlyBreakdownEntry> hourly;

  const TodayStatsModel({
    this.ordersCount = 0,
    this.revenueXaf = 0,
    this.avgRating = 0.0,
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

class PrepTimeEstimateModel {
  final int avgMinutes;
  final int? medianMinutes;

  const PrepTimeEstimateModel({
    this.avgMinutes = 15,
    this.medianMinutes,
  });

  factory PrepTimeEstimateModel.fromJson(Map<String, dynamic> json) =>
      PrepTimeEstimateModel(
        avgMinutes: (json['avgMinutes'] as num?)?.toInt() ??
            (json['avg'] as num?)?.toInt() ??
            15,
        medianMinutes: (json['medianMinutes'] as num?)?.toInt(),
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

  factory RushStatusModel.fromJson(Map<String, dynamic> json) => RushStatusModel(
        active: json['rush'] as bool? ?? json['active'] as bool? ?? false,
        until: json['until'] != null
            ? DateTime.tryParse(json['until'] as String)
            : null,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      );
}
