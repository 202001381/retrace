import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'screens/archive_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/myluna/myluna_screen.dart';
import 'screens/mypage/mypage_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/onboarding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
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
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bgPage,
        canvasColor: AppColors.bgPage,
        dialogBackgroundColor: AppColors.bgCard,
        colorScheme: const ColorScheme.light(
          primary: AppColors.red,
          onPrimary: AppColors.textOnDark,
          secondary: AppColors.ink900,
          onSecondary: AppColors.textOnDark,
          tertiary: AppColors.yellow,
          onTertiary: AppColors.textPrimary,
          surface: AppColors.bgCard,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.bgCardWarm,
          error: AppColors.red,
          onError: AppColors.textOnDark,
          outline: AppColors.textSecondary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bgCard,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: AppColors.line,
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
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
            backgroundColor: AppColors.bgPage,
            body: Center(
                child: CircularProgressIndicator(color: AppColors.red)),
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
  // '추천 지도' 탭은 기본으로 마이 루나 동선 표시.
  bool _mapMyLuna = true;
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

  /// 마이 루나 = bottom nav 별도 탭(index 2). 홈 카드의 "전체 동선 보기" 도 여기로.
  void _goToMyLuna() {
    setState(() {
      _currentIndex = 2;
    });
  }

  void _openMyPage() {
    setState(() {
      _currentIndex = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        onOpenMyLuna: _goToMyLuna,
        onOpenMyPage: _openMyPage,
        onResetOnboarding: widget.onResetOnboarding,
        openPricingOnStart: _openPricingOnStart,
      ),
      MapScreen(showMyLunaInitially: _mapMyLuna),
      const MyLunaScreen(),
      const ArchiveScreen(),
      MypageScreen(onResetOnboarding: widget.onResetOnboarding),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
              _navItem(1, Icons.map_rounded, '추천 지도'),
              _navItem(2, Icons.nightlight_round, '마이 루나'),
              _navItem(3, Icons.menu_book_rounded, 'Archive'),
              _navItem(4, Icons.person_rounded, '마이페이지'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    // 마이 루나 = 메인 기능. luna/AI 전용 블루(AppColors.blue)로 항시 강조.
    final isMyLuna = index == 2;
    final Color color = isMyLuna
        ? (isActive
            ? AppColors.blue
            : AppColors.blue.withValues(alpha: 0.75))
        : (isActive ? AppColors.red : AppColors.textSecondary);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _currentIndex = index;
          // 추천 지도 탭 진입 시 동선 자동 표시.
          if (index == 1) _mapMyLuna = true;
        }),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isMyLuna ? 24 : 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isMyLuna
                    ? FontWeight.w800
                    : (isActive ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
