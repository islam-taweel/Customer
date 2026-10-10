class Customer {
  final int? id;
  final String name;
  final String phone;
  final double balance; // يُحسب تلقائياً من المعاملات (ديون - دفعات)

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.balance = 0,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: (map['phone'] ?? '') as String,
        balance: ((map['current_balance'] ?? 0) as num).toDouble(),
      );

  /// للإدخال في قاعدة البيانات (الرصيد لا يُخزَّن، بل يُحسب)
  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
      };
}