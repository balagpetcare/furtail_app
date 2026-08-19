import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/services/api_client.dart';

class SearchResultPage {
  final List<dynamic> items;
  final String? nextCursor;
  final bool hasMore;

  SearchResultPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  factory SearchResultPage.fromJson(Map<String, dynamic> json) {
    return SearchResultPage(
      items: json['items'] as List<dynamic>? ?? [],
      nextCursor: json['nextCursor']?.toString(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class SearchAllPage {
  final SearchResultPage people;
  final SearchResultPage posts;
  final SearchResultPage pets;

  SearchAllPage({
    required this.people,
    required this.posts,
    required this.pets,
  });

  factory SearchAllPage.fromJson(Map<String, dynamic> json) {
    return SearchAllPage(
      people: SearchResultPage.fromJson(json['people'] ?? {}),
      posts: SearchResultPage.fromJson(json['posts'] ?? {}),
      pets: SearchResultPage.fromJson(json['pets'] ?? {}),
    );
  }
}

class SearchService {
  final ApiClient _client;

  SearchService({ApiClient? client}) : _client = client ?? ApiClient();

  Map<String, dynamic> _asMap(dynamic decoded) =>
      (decoded as Map).cast<String, dynamic>();
  Map<String, dynamic> _data(dynamic decoded) {
    final map = _asMap(decoded);
    return (map['data'] as Map?)?.cast<String, dynamic>() ?? map;
  }

  Future<dynamic> search({
    required String query,
    required String type,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'q': query,
      'type': type,
      'limit': limit,
    };
    if (cursor != null) queryParams['cursor'] = cursor;

    final uri = Uri.parse('${ApiConfig.apiV1}/search')
        .replace(
          queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();

    final response = await _client.get(uri);
    final data = _data(response);

    if (type == 'all') {
      return SearchAllPage.fromJson(data);
    } else {
      return SearchResultPage.fromJson(data);
    }
  }
}
