class Wallet {
  final int id;
  final String name;
  final double balance;
  final String currency;
  final String type;
  final DateTime? createdAt;

  Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
    required this.type,
    this.createdAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      balance: double.tryParse((json['balance'] ?? 0).toString()) ?? 0,
      currency: json['currency'] ?? 'XOF',
      type: json['type'] ?? 'mobile_money',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
