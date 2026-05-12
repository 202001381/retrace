import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/favorites_provider.dart';
import 'providers/preference_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SeoulLandApp());
}

class SeoulLandApp extends StatelessWidget {
  const SeoulLandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()..load()),
        ChangeNotifierProvider(create: (_) => PreferenceProvider()..load()),
      ],
      child: MaterialApp(
        title: '서울랜드',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
          useMaterial3: true,
          fontFamily: 'Pretendard',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
