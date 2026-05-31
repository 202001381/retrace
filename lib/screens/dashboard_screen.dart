// POST /api/pricing 호출 → 날씨·할인·방문가치 스코어·혼잡도 표시.

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  late Future<PricingResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getPricing();
  }

  Future<void> _refresh() async {
    setState(() => _future = _api.getPricing());
    await _future;
  }

  String _conditionLabel(String c) => switch (c) {
        'sunny' => '맑음 ☀',
        'cloudy' => '흐림 ☁',
        'rainy' => '비 🌧',
        'snowy' => '눈 ❄',
        _ => c,
      };

  String _zoneLabel(String id) => switch (id) {
        'central' => '중앙광장',
        'thrill' => '스릴 존',
        'family' => '패밀리 존',
        'kids' => '어린이 존',
        _ => id,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 방문 가치')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<PricingResponse>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('백엔드 호출 실패',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${snap.error}'),
                  const SizedBox(height: 16),
                  Text(
                    '백엔드가 http://localhost:8080 에서 실행 중인지 확인하세요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }
            final p = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScoreCard(score: p.visitValueScore),
                const SizedBox(height: 16),
                _SectionTitle('현재 날씨'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.wb_sunny),
                    title: Text(_conditionLabel(p.weather.condition)),
                    subtitle: Text('${p.weather.tempC.toStringAsFixed(1)}°C'),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle('적용 가능 할인'),
                if (p.discounts.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('현재 조건에 맞는 할인이 없습니다.'),
                    ),
                  )
                else
                  ...p.discounts.map(
                    (d) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_offer),
                        title: Text(d.title),
                        trailing: Text(
                          '${(d.rate * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _SectionTitle('구역별 혼잡도'),
                Card(
                  child: Column(
                    children: p.congestionByZone.entries
                        .map((e) => ListTile(
                              title: Text(_zoneLabel(e.key)),
                              trailing: _CongestionBar(level: e.value),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '방문 가치 스코어',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$score',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const Text('/ 100'),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _CongestionBar extends StatelessWidget {
  final int level;
  const _CongestionBar({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level <= 1
        ? Colors.green
        : level <= 3
            ? Colors.orange
            : Colors.red;
    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: level / 5, color: color),
          const SizedBox(height: 2),
          Text('$level / 5', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
