// POST /api/story 호출 → 어트랙션 선택 → Claude(또는 스텁) 서사 표시.

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final _api = ApiClient();

  // backend/mock_data.py 의 ATTRACTIONS 와 동일. 운영 단계에서는 GET /api/attractions 로 받아오는 게 옳음.
  static const List<(String, String)> _options = [
    ('carousel', '회전목마'),
    ('blackhole_2000', '블랙홀 2000'),
    ('flume_ride', '후룸라이드'),
    ('shot_drop', '샷드롭'),
    ('double_rock_spin', '더블락스핀'),
    ('viking', '바이킹'),
    ('bumper_car', '범퍼카'),
    ('spinning_swing', '회전그네'),
    ('ferris_wheel', '대관람차'),
    ('mini_viking', '미니바이킹'),
    ('biryong_train', '비룡열차'),
    ('magic_swing', '매직스윙'),
    ('dokkaebi_academy', '도깨비 아카데미'),
    ('jumping_fly', '점핑플라이'),
    ('disco_coaster', '디스코드 코스터'),
  ];

  String _selected = 'carousel';
  bool _loading = false;
  String? _error;
  StoryResponse? _story;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _story = null;
    });
    try {
      final s = await _api.getStory(_selected);
      setState(() {
        _story = s;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('어트랙션 스토리')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: const InputDecoration(
                labelText: '어트랙션 선택',
                border: OutlineInputBorder(),
              ),
              items: _options
                  .map((o) =>
                      DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v ?? _selected),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _fetch,
              icon: const Icon(Icons.auto_stories),
              label: const Text('스토리 받기'),
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_error!),
        ),
      );
    }
    if (_story == null) {
      return const Center(child: Text('어트랙션을 골라 스토리를 받아보세요.'));
    }
    return ListView(
      children: [
        Text(_story!.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            Chip(label: Text('모델: ${_story!.model}')),
            Chip(label: Text(_story!.cached ? '캐시 응답' : '새 응답')),
          ],
        ),
        const SizedBox(height: 16),
        Text(_story!.body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
