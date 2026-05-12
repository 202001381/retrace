import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';

class PreferenceProvider extends ChangeNotifier {
  static const _kHeight = 'pref_height_cm';
  static const _kThrill = 'pref_thrill_level';
  static const _kCategories = 'pref_categories';

  int? _heightCm;
  int _thrillTolerance = 3;
  Set<AttractionCategory> _preferred = {
    AttractionCategory.family,
    AttractionCategory.thrill,
  };

  int? get heightCm => _heightCm;
  int get thrillTolerance => _thrillTolerance;
  Set<AttractionCategory> get preferred => Set.unmodifiable(_preferred);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getInt(_kHeight);
    _heightCm = h;
    _thrillTolerance = prefs.getInt(_kThrill) ?? 3;
    final cats = prefs.getStringList(_kCategories);
    if (cats != null && cats.isNotEmpty) {
      _preferred = cats
          .map((name) => AttractionCategory.values.firstWhere(
                (c) => c.name == name,
                orElse: () => AttractionCategory.family,
              ))
          .toSet();
    }
    notifyListeners();
  }

  Future<void> update({
    int? heightCm,
    int? thrillTolerance,
    Set<AttractionCategory>? preferred,
  }) async {
    if (heightCm != null) _heightCm = heightCm;
    if (thrillTolerance != null) _thrillTolerance = thrillTolerance;
    if (preferred != null) _preferred = preferred;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (_heightCm != null) {
      await prefs.setInt(_kHeight, _heightCm!);
    }
    await prefs.setInt(_kThrill, _thrillTolerance);
    await prefs.setStringList(
      _kCategories,
      _preferred.map((c) => c.name).toList(),
    );
  }

  void togglePreferred(AttractionCategory c) {
    final next = Set<AttractionCategory>.from(_preferred);
    if (next.contains(c)) {
      next.remove(c);
    } else {
      next.add(c);
    }
    update(preferred: next);
  }
}
