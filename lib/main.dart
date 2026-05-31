import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/recommend_screen.dart';
import 'screens/story_screen.dart';

void main() {
  runApp(const SeoullandApp());
}

class SeoullandApp extends StatelessWidget {
  const SeoullandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '서울랜드 데모',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
  int _index = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    RecommendScreen(),
    StoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.recommend_outlined),
            selectedIcon: Icon(Icons.recommend),
            label: '추천',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '스토리',
          ),
        ],
      ),
    );
  }
}
