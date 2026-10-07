import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/palette.dart';
import '../services/activity_tracker.dart';
import 'goals_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ActivityTracker tracker;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    tracker = ActivityTracker(widget.controller);
    tracker.start(widget.controller.user!);
  }

  @override
  void dispose() {
    tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            if (widget.controller.bannerMessage != null)
              SafeArea(
                bottom: false,
                child: MaterialBanner(
                  backgroundColor: context.palette.surfaceRaised,
                  content: Text(
                    widget.controller.bannerMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.controller.clearBanner,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(controller: widget.controller, tracker: tracker),
                  HistoryScreen(controller: widget.controller),
                  InsightsScreen(controller: widget.controller),
                  GoalsScreen(controller: widget.controller),
                  ProfileScreen(controller: widget.controller),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          height: 75,
          backgroundColor: context.palette.surface,
          indicatorColor: context.palette.citrus.withOpacity(0.62),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: 'Goals',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      );
}
