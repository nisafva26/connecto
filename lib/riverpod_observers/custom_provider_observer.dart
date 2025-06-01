import 'package:connecto/riverpod_observers/my_app_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomProviderObservers extends ProviderObserver {
  
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    MyAppProviders.addProvider(provider);
    super.didAddProvider(provider, value, container);
  }
}