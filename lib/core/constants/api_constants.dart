class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://nyama-api-production.up.railway.app/api/v1';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String requestOtp = '/auth/otp/request';
  static const String verifyOtp = '/auth/otp/verify';
  static const String accessCodeLogin = '/auth/access-code';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // ── Profil cuisinière ─────────────────────────────────────────────────────
  static const String cookProfile = '/cook/profile';
  static const String cookStats = '/cook/stats';
  static const String cookRevenue = '/cook/revenue';

  // ── Menu items ────────────────────────────────────────────────────────────
  static const String cookMenuItems = '/cook/menu/items';
  static String cookMenuItemById(String id) => '/cook/menu/items/$id';
  static const String toggleMenuItemAvailability =
      '/cook/menu/items/:id/toggle';

  // ── Commandes cuisinière ──────────────────────────────────────────────────
  static const String cookOrders = '/cook/orders';
  static String cookOrderById(String id) => '/cook/orders/$id';
  static String acceptOrder(String id) => '/cook/orders/$id/accept';
  static String rejectOrder(String id) => '/cook/orders/$id/reject';
  static String startPreparing(String id) => '/cook/orders/$id/preparing';
  static String markReady(String id) => '/cook/orders/$id/ready';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const String cookDashboard = '/cook/dashboard';

  // ── Avis ──────────────────────────────────────────────────────────────────
  static const String cookReviews = '/cook/reviews';

  // ── Shared endpoints ──────────────────────────────────────────────────────
  static const String cooks = '/cooks';
  static String cookById(String id) => '/cooks/$id';

  // ── WebSocket ─────────────────────────────────────────────────────────────
  static const String wsUrl = 'https://nyama-api-production.up.railway.app';

  // ── Storage keys ──────────────────────────────────────────────────────────
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userPhoneKey = 'user_phone';
  static const String userIdKey = 'user_id';
  static const String cookIdKey = 'cook_id';
}
