import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/archive_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/mypage/mypage_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/recommend_screen.dart';
import 'services/onboarding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    await Firebase.initializeApp();
  } catch (_) {/* config 미완료 — Firestore/FCM 의존 기능은 비활성 */}
  runApp(const SeoulLandApp());
}

class SeoulLandApp extends StatelessWidget {
  const SeoulLandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeoulLand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE60012),
          primary: const Color(0xFFE60012),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      home: const _AppGate(),
    );
  }
}

/// 최초 실행이면 OnboardingScreen, 아니면 MainScreen.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  Future<bool>? _needsOnboarding;
  // 온보딩 종료 시 진입 의도 (결과 화면 버튼별).
  OnboardingExit _exit = OnboardingExit.home;

  @override
  void initState() {
    super.initState();
    _needsOnboarding = OnboardingService.needsOnboarding();
  }

  void _onOnboardingDone(OnboardingExit exit) {
    setState(() {
      _exit = exit;
      _needsOnboarding = OnboardingService.needsOnboarding();
    });
  }

  void _resetToOnboarding() {
    setState(() {
      _exit = OnboardingExit.home;
      _needsOnboarding = OnboardingService.needsOnboarding();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _needsOnboarding,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F7F7),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE60012))),
          );
        }
        if (snap.data == true) {
          return OnboardingScreen(onDone: _onOnboardingDone);
        }
        return MainScreen(
          initialExit: _exit,
          onResetOnboarding: () async {
            await OnboardingService.reset();
            _resetToOnboarding();
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback? onResetOnboarding;
  final OnboardingExit initialExit;
  const MainScreen({
    super.key,
    this.onResetOnboarding,
    this.initialExit = OnboardingExit.home,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _mapMyLuna = false;
  bool _openPricingOnStart = false;

  @override
  void initState() {
    super.initState();
    switch (widget.initialExit) {
      case OnboardingExit.mapTab:
        _currentIndex = 1;
        break;
      case OnboardingExit.pricingPopup:
        _currentIndex = 0;
        _openPricingOnStart = true;
        break;
      case OnboardingExit.home:
        break;
    }
  }

  void _goToMap({bool myLuna = false}) {
    setState(() {
      _currentIndex = 1;
      _mapMyLuna = myLuna;
    });
  }

  void _openMyPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MypageScreen(
          onResetOnboarding: widget.onResetOnboarding,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        onOpenMyLuna: () => _goToMap(myLuna: true),
        onOpenMyPage: _openMyPage,
        onResetOnboarding: widget.onResetOnboarding,
        openPricingOnStart: _openPricingOnStart,
      ),
      MapScreen(showMyLunaInitially: _mapMyLuna),
      const RecommendScreen(),
      const ArchiveScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, '홈'),
              _navItem(1, Icons.map_rounded, 'MAP'),
              _navItem(2, Icons.auto_awesome_rounded, '추천'),
              _navItem(3, Icons.menu_book_rounded, 'Archive'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFFE60012) : const Color(0xFF9E9E9E);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _currentIndex = index;
          if (index != 1) _mapMyLuna = false;
        }),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
