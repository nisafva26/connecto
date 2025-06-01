import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyAppProviders {
  MyAppProviders._();

  static final List _neglectProviders = [
    StateNotifierProvider<StateNotifier, State>,
  ];

  static final List<ProviderBase> _allProviders = <ProviderBase>[];

  static void addProvider(ProviderBase provider) {
    if (_neglectProviders.contains(provider.runtimeType)) {
      return;
    }
    _allProviders.add(provider);
  }

  static Future<void> invalidateAllProviders(WidgetRef ref) async {
    for (var provider in _allProviders) {
      ref.invalidate(provider);
    }
    _allProviders.clear();
  }
}