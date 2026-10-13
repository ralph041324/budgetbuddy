import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// 1500 -> "₱1,500" , 1500.5 -> "₱1,500.50"
String formatPeso(double value) {
  final isWhole = value == value.roundToDouble();
  final parts = value.toStringAsFixed(isWhole ? 0 : 2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '₱$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

enum BudgetPeriod {
  daily('Daily', 'per day', Icons.today_rounded, Color(0xFFF57C00),
      [50, 100, 200, 500]),
  weekly('Weekly', 'per week', Icons.date_range_rounded, Color(0xFF1E88E5),
      [500, 1000, 1500, 2000]),
  monthly('Monthly', 'per month', Icons.calendar_month_rounded,
      Color(0xFF2E7D32), [2000, 3000, 5000, 10000]);

  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final List<int> quickAmounts;

  const BudgetPeriod(
      this.label, this.unit, this.icon, this.color, this.quickAmounts);

  double? valueOf(Budget b) {
    switch (this) {
      case BudgetPeriod.daily:
        return b.daily;
      case BudgetPeriod.weekly:
        return b.weekly;
      case BudgetPeriod.monthly:
        return b.monthly;
    }
  }

  /// Returns a copy of [b] with this period set to [value] (null = removed).
  Budget apply(Budget b, double? value) {
    switch (this) {
      case BudgetPeriod.daily:
        return Budget(daily: value, weekly: b.weekly, monthly: b.monthly);
      case BudgetPeriod.weekly:
        return Budget(daily: b.daily, weekly: value, monthly: b.monthly);
      case BudgetPeriod.monthly:
        return Budget(daily: b.daily, weekly: b.weekly, monthly: value);
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Shows the student's daily, weekly and monthly budget as cards.
/// Tap a card to set or edit it.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _budgetService = BudgetService();
  late final Stream<Budget> _stream = _budgetService.budgetStream();

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _openEditor(Budget current, BudgetPeriod period) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditSheet(
        period: period,
        initial: period.valueOf(current),
        onSave: (value) async {
          final error =
              await _budgetService.saveBudget(period.apply(current, value));
          if (error == null && mounted) {
            _snack(value == null
                ? '${period.label} budget removed.'
                : '${period.label} budget saved!');
          }
          return error;
        },
      ),
    );
  }

  // Suggest daily & weekly from the monthly amount.
  Future<void> _autoFill(Budget current) async {
    final monthly = current.monthly;
    if (monthly == null || monthly <= 0) {
      _snack('Set a monthly budget first.');
      return;
    }
    final daily = double.parse((monthly / 30).toStringAsFixed(2));
    final weekly = double.parse((monthly / 30 * 7).toStringAsFixed(2));
    final error = await _budgetService.saveBudget(
      Budget(daily: daily, weekly: weekly, monthly: monthly),
    );
    if (mounted) {
      _snack(error ?? 'Daily and weekly filled from your monthly budget.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      body: SafeArea(
        child: StreamBuilder<Budget>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load your budget.\nCheck your connection and Firestore rules.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final budget = snapshot.data!;
            return _buildContent(budget);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Budget budget) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Title row
        Row(
          children: [
            if (Navigator.canPop(context))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Budget',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap a card to set or edit your limit',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Monthly hero card
        _HeroCard(
          value: budget.monthly,
          onTap: () => _openEditor(budget, BudgetPeriod.monthly),
        ),
        const SizedBox(height: 14),

        // Weekly + Daily boxes side by side
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PeriodBox(
                  period: BudgetPeriod.weekly,
                  value: budget.weekly,
                  onTap: () => _openEditor(budget, BudgetPeriod.weekly),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _PeriodBox(
                  period: BudgetPeriod.daily,
                  value: budget.daily,
                  onTap: () => _openEditor(budget, BudgetPeriod.daily),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Auto-fill tip
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _autoFill(budget),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFF7B1FA2)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-fill from monthly',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Calculates your daily and weekly limits for you.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// Big green card for the monthly budget.
class _HeroCard extends StatelessWidget {
  final double? value;
  final VoidCallback onTap;

  const _HeroCard({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSet = value != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Monthly budget',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSet ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  isSet ? formatPeso(value!) : 'Not set',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSet ? 'per month · tap to edit' : 'Tap to set your monthly limit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White box for the weekly / daily budget.
class _PeriodBox extends StatelessWidget {
  final BudgetPeriod period;
  final double? value;
  final VoidCallback onTap;

  const _PeriodBox({
    required this.period,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = value != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: period.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(period.icon, color: period.color, size: 20),
                  ),
                  const Spacer(),
                  Icon(
                    isSet ? Icons.edit_rounded : Icons.add_circle_outline,
                    size: 18,
                    color: Colors.black38,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${period.label} budget',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isSet ? formatPeso(value!) : 'Not set',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isSet ? Colors.black87 : Colors.black38,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSet ? period.unit : 'Tap to set',
                style: TextStyle(color: period.color, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit bottom sheet
// ---------------------------------------------------------------------------

class _EditSheet extends StatefulWidget {
  final BudgetPeriod period;
  final double? initial;

  /// Saves the value (null = remove). Returns null on success or an error text.
  final Future<String?> Function(double? value) onSave;

  const _EditSheet({
    required this.period,
    required this.initial,
    required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _controller = TextEditingController(
      text: v == null
          ? ''
          : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(double? value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(value);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _submit(double.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final color = period.color;

    return Padding(
      // Lifts the sheet above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(period.icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${period.label} budget',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'How much can you spend ${period.unit}?',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '₱ ',
                  prefixStyle: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  filled: true,
                  fillColor: color.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an amount';
                  }
                  final n = double.tryParse(value.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n <= 0) return 'Amount must be more than 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Quick amount chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in period.quickAmounts)
                    ActionChip(
                      label: Text(formatPeso(amount.toDouble())),
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                      backgroundColor: Colors.white,
                      onPressed: () =>
                          setState(() => _controller.text = amount.toString()),
                    ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (widget.initial != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: _saving ? null : () => _submit(null),
                    child: Text('Remove ${period.label.toLowerCase()} budget'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}