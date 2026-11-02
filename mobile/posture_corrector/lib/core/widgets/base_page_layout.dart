import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:posture_corrector/view/home/home_page.dart';
import 'package:posture_corrector/view/settings/settings_page.dart';
import 'package:posture_corrector/view/social/social_page.dart';
import 'package:posture_corrector/view/stats/stats_page.dart';

class BasePageLayout extends StatefulWidget {
  final String? title;

  const BasePageLayout({super.key, this.title});

  @override
  State<BasePageLayout> createState() => _BasePageLayoutState();
}

class _BasePageLayoutState extends State<BasePageLayout> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final List<NavigationDestination> navItems = [
      NavigationDestination(
        icon: Icon(Icons.home_rounded, color: colors.onSurface),
        selectedIcon: Icon(Icons.home_rounded, color: colors.primary),
        label: "home".tr(),
      ),
      NavigationDestination(
        icon: Icon(Icons.data_usage, color: colors.onSurface),
        selectedIcon: Icon(Icons.data_usage, color: colors.primary),

        label: "stats".tr(),
      ),
      NavigationDestination(
        icon: Icon(Icons.people_alt_outlined, color: colors.onSurface),
        selectedIcon: Icon(Icons.people_alt, color: colors.primary),
        label: "social".tr(),
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined, color: colors.onSurface),
        selectedIcon: Icon(Icons.settings_outlined, color: colors.primary),
        label: "settings".tr(),
      ),
    ];

    final List<Widget> pages = [
      const Homepage(),
      const StatsPage(),
      const SocialPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      appBar: widget.title != null ? AppBar(title: Text(widget.title!)) : null,
      bottomNavigationBar: NavigationBar(
        destinations: navItems,
        selectedIndex: currentPageIndex,
        indicatorColor: colors.primary.withValues(alpha: 0.2),
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
      ),
      body: SafeArea(
        child: IndexedStack(index: currentPageIndex, children: pages),
      ),
    );
  }
}
