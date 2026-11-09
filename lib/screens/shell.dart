import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'other_screens.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, index, _) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: IndexedStack(index: index, children: const [
                  HomeScreen(),
                  ExploreScreen(),
                  OrdersScreen(),
                  ProfileScreen(embedded: true),
                ]),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: C.border)),
              boxShadow: [BoxShadow(color: Color(0x0F312E81), blurRadius: 16, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      for (int i = 0; i < _items.length; i++)
                        Expanded(child: _NavItem(
                          icon: index == i ? _items[i].$2 : _items[i].$1,
                          label: _items[i].$3,
                          active: index == i,
                          onTap: () => tabIndex.value = i,
                        )),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: active ? C.light : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: active ? C.purple : C.sub),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: t(12, w: active ? FontWeight.w700 : FontWeight.w500, c: active ? C.purple : C.sub)),
        ]),
      ),
    );
  }
}
