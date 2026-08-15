class FinancialSummary {
  final double totalRevenue;
  final double totalExpenses;
  final double balance;

  FinancialSummary({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.balance,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TransactionItem {
  final String id;
  final String type;
  final double amount;
  final String date;
  final String description;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? '',
      type: json['transaction_type'] ?? 'income',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_type': type,
      'amount': amount,
      'date': date,
      'description': description,
    };
  }
}
