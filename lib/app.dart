import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/log_screen.dart';
import 'theme.dart';

class PlantScanApp extends StatelessWidget {
  const PlantScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Scan',
      debugShowCheckedModeBanner: false,
      theme: buildPlantScanTheme(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [HomeScreen(), LogScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.center_focus_weak_outlined),
            selectedIcon: Icon(Icons.center_focus_strong),
            label: 'Identify',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'My plants',
          ),
        ],
      ),
    );
  }
}
