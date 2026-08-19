import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/search_service.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});
