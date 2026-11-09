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
          backgroundColor: C.bg,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: IndexedStack(
                  index: index,
                  children: const [
                    HomeScreen(),
                    ExploreScreen(),
                    OrdersScreen(),
                    ProfileScreen(embedded: true),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _LuxuryFloatingNavBar(
            currentIndex: index,
            items: _items,
            onTap: (newIndex) => tabIndex.value = newIndex,
          ),
        );
      },
    );
  }
}

class _LuxuryFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  const _LuxuryFloatingNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFE9E6F0),
                width: 1.0,
              ),
              boxShadow: DawaShadows.navBar,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < items.length; i++)
                  _LuxuryNavItem(
                    inactiveIcon: items[i].$1,
                    activeIcon: items[i].$2,
                    label: items[i].$3,
                    isActive: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryNavItem extends StatelessWidget {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LuxuryNavItem({
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? C.light : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(
                  color: C.purple.withValues(alpha: 0.25),
                  width: 1.0,
                )
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                size: 21,
                color: isActive ? C.purple : C.sub,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: isActive ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Text(
                  label,
                  style: t(
                    12.5,
                    w: FontWeight.w700,
                    c: C.purple,
                    ls: 0.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
