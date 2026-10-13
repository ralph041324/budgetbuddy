import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('expenses');

  // ADD EXPENSE: returns null if success, or an error message if failed
  Future<String?> addExpense(Expense expense) async {
    try {
      await _expenses.add(expense.toMap(_auth.currentUser!.uid));
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') return 'No internet connection.';
      if (e.code == 'permission-denied') {
        return 'Not allowed to save. Check Firestore rules.';
      }
      return 'Something went wrong. (${e.code})';
    }
  }

  // The logged-in student's latest expenses (newest date first).
  // Sorted here in the app, so no Firestore index is needed.
  Stream<List<Expense>> recentExpenses({int limit = 5}) {
    return _expenses
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Expense.fromDoc).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list.take(limit).toList();
    });
  }
}
