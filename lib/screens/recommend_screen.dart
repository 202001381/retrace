// POST /api/recommend 호출 → 구성원 입력 폼 + Top-3 결과 카드.

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  final _api = ApiClient();
  final List<_MemberInput> _members = [_MemberInput()];
  bool _loading = false;
  String? _error;
  List<RecommendedAttraction>? _result;

  Future<void> _request() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final list = await _api.getRecommend(
        members: _members
            .map((m) => {
                  'age': m.age,
                  'thrill_pref': m.thrillPref,
                  'has_kids_role': m.hasKidsRole,
                })
            .toList(),
        currentLocation: const {'lat': 37.4357, 'lng': 127.0064},
      );
      setState(() {
        _result = list;
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
      appBar: AppBar(
        title: const Text('Top-3 추천'),
        actions: [
          IconButton(
            tooltip: '구성원 추가',
            icon: const Icon(Icons.person_add),
            onPressed: () => setState(() => _members.add(_MemberInput())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('구성원 정보', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._members.asMap().entries.map(
                (e) => _MemberCard(
                  index: e.key,
                  input: e.value,
                  onChanged: () => setState(() {}),
                  onRemove: _members.length > 1
                      ? () => setState(() => _members.removeAt(e.key))
                      : null,
                ),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _request,
            icon: const Icon(Icons.search),
            label: const Text('추천받기'),
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          if (_result != null) ...[
            Text('추천 결과', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._result!.asMap().entries.map(
                  (e) => _ResultCard(rank: e.key + 1, attraction: e.value),
                ),
          ],
        ],
      ),
    );
  }
}

class _MemberInput {
  int age = 25;
  int thrillPref = 3;
  bool hasKidsRole = false;
}

class _MemberCard extends StatelessWidget {
  final int index;
  final _MemberInput input;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.index,
    required this.input,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('구성원 #${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                  ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('나이')),
                Expanded(
                  child: Slider(
                    value: input.age.toDouble(),
                    min: 0,
                    max: 80,
                    divisions: 80,
                    label: '${input.age}세',
                    onChanged: (v) {
                      input.age = v.round();
                      onChanged();
                    },
                  ),
                ),
                SizedBox(width: 50, child: Text('${input.age}세')),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('스릴 선호')),
                Expanded(
                  child: Slider(
                    value: input.thrillPref.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${input.thrillPref}',
                    onChanged: (v) {
                      input.thrillPref = v.round();
                      onChanged();
                    },
                  ),
                ),
                SizedBox(width: 50, child: Text('${input.thrillPref}/5')),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('어린이 동반 (가족 적합도 가중)'),
              value: input.hasKidsRole,
              onChanged: (v) {
                input.hasKidsRole = v;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final int rank;
  final RecommendedAttraction attraction;
  const _ResultCard({required this.rank, required this.attraction});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$rank')),
        title: Text(attraction.name),
        subtitle: Text(attraction.reason),
        trailing: Text(
          '${attraction.score.toStringAsFixed(1)}점',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}
