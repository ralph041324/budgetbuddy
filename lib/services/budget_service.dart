import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('budgets').doc(_auth.currentUser!.uid);

  Stream<Budget> budgetStream() {
    return _doc.snapshots().map((snap) {
      final data = snap.data();
      return data == null ? const Budget() : Budget.fromMap(data);
    });
  }

  Future<Budget> getBudget() async {
    final snap = await _doc.get();
    final data = snap.data();
    return data == null ? const Budget() : Budget.fromMap(data);
  }


  Future<String?> saveBudget(Budget budget) async {
    try {
      await _doc.set(budget.toMap());
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') return 'No internet connection.';
      if (e.code == 'permission-denied') {
        return 'Not allowed to save. Check Firestore rules.';
      }
      return 'Something went wrong. (${e.code})';
    }
  }
}
