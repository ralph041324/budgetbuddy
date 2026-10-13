import 'package:cloud_firestore/cloud_firestore.dart';

/// A student's budget limits. A value of null means "not set".
class Budget {
  final double? daily;
  final double? weekly;
  final double? monthly;

  const Budget({this.daily, this.weekly, this.monthly});

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      daily: (map['daily'] as num?)?.toDouble(),
      weekly: (map['weekly'] as num?)?.toDouble(),
      monthly: (map['monthly'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'daily': daily,
      'weekly': weekly,
      'monthly': monthly,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
