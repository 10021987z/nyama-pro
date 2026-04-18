class OrderMessageModel {
  final String id;
  final String orderId;
  final String senderRole; // 'cook' | 'rider' | 'client' | 'system'
  final String senderName;
  final String text;
  final DateTime createdAt;

  const OrderMessageModel({
    required this.id,
    required this.orderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory OrderMessageModel.fromJson(Map<String, dynamic> json) =>
      OrderMessageModel(
        id: (json['id'] ?? json['_id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
            .toString(),
        orderId: (json['orderId'] ?? '').toString(),
        senderRole: (json['senderRole'] as String? ??
                json['role'] as String? ??
                'system')
            .toLowerCase(),
        senderName: json['senderName'] as String? ??
            json['name'] as String? ??
            'Livreur',
        text: json['text'] as String? ?? json['message'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  bool get isFromCook => senderRole == 'cook';
}
