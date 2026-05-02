class Transaction {
  final int id;
  final int walletId;
  final int? categoryId;
  final String type;
  final double amount;
  final String? description;
  final String status;
  final DateTime? transactionDate;
  final DateTime? createdAt;

  Transaction({
    required this.id,
    required this.walletId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.description,
    this.status = 'completed',
    this.transactionDate,
    this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      walletId: json['wallet_id'] ?? 0,
      categoryId: json['category_id'],
      type: json['type'] ?? 'expense',
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      description: json['description'],
      status: json['status'] ?? 'completed',
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
