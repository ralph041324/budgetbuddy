import 'package:flutter/material.dart';
import 'budget_screen.dart';
import 'home_screen.dart';

/// Shown right after login. Opens on the Budget tab.
/// Teammates can add their tabs (Expenses, Summary, ...) to _pages
/// and _destinations below.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0; // 0 = Budget, so it shows first after login

  final List<Widget> _pages = const [
    HomeScreen(), // profile / logout
     BudgetScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
     NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Budget',
    ),
   
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
