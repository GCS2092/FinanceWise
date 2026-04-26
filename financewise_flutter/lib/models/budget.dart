class Budget {
  final int id;
  final int categoryId;
  final double amount;
  final double spent;
  final double remaining;
  final double percentage;
  final String period;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    this.spent = 0,
    this.remaining = 0,
    this.percentage = 0,
    required this.period,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      spent: (json['spent'] ?? 0).toDouble(),
      remaining: (json['remaining'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      period: json['period'] ?? 'monthly',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      isActive: json['is_active'] ?? true,
    );
  }
}
