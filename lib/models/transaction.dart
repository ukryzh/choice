import 'dart:convert';

enum TransactionType { voting, dataSale }

class Transaction {
  Transaction({
    required this.id,
    required this.type,
    required this.date,
    this.question,
    this.answer,
    this.costTokens,
    this.title,
    this.reward,
    this.details,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.voting,
      ),
      date: DateTime.parse(json['date'] as String),
      question: json['question'] as String?,
      answer: json['answer'] as String?,
      costTokens: json['costTokens'] as int?,
      title: json['title'] as String?,
      reward: json['reward'] as String?,
      details: json['details'] as String?,
    );
  }

  final String id;
  final TransactionType type;
  final DateTime date;
  final String? question;
  final String? answer;
  final int? costTokens;
  final String? title;
  final String? reward;
  final String? details;

  // For voting transactions, use question as unique identifier
  // For data sales, use title as unique identifier
  String get uniqueKey {
    if (type == TransactionType.voting && question != null) {
      return 'voting_$question';
    } else if (type == TransactionType.dataSale && title != null) {
      return 'sale_$title';
    }
    return id;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        if (question != null) 'question': question,
        if (answer != null) 'answer': answer,
        if (costTokens != null) 'costTokens': costTokens,
        if (title != null) 'title': title,
        if (reward != null) 'reward': reward,
        if (details != null) 'details': details,
      };

  String encode() => jsonEncode(toJson());
}


