import 'package:cloud_firestore/cloud_firestore.dart';

/// The categories students can pick from.
const List<String> expenseCategories = [
  'Food',
  'Transportation',
  'School',
  'Load/Internet',
  'Entertainment',
  'Other',
];

/// One recorded expense.
class Expense {
  final String? id; // Firestore document id (null before it is saved)
  final String name;
  final double amount;
  final String category;
  final DateTime date;
  final String notes;

  const Expense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
    this.notes = '',
  });

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Expense(
      id: doc.id,
      name: (map['name'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: (map['category'] as String?) ?? 'Other',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: (map['notes'] as String?) ?? '',
    );
  }

  /// [userId] ties the expense to the logged-in student.
  Map<String, dynamic> toMap(String userId) {
    return {
      'userId': userId,
      'name': name,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
