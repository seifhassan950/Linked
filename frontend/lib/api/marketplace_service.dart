import 'api_client.dart';

class MarketplaceAsset {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final String category;
  final String style;
  final String creatorId;
  final bool isPaid;
  final int price;
  final String currency;
  final String? thumbObjectKey;
  final String? modelObjectKey;
  final String? thumbUrl;
  final String? previewUrl;
  final Map<String, dynamic> metadata;

  const MarketplaceAsset({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.category,
    required this.style,
    required this.creatorId,
    required this.isPaid,
    required this.price,
    required this.currency,
    required this.thumbObjectKey,
    required this.modelObjectKey,
    required this.thumbUrl,
    required this.previewUrl,
    required this.metadata,
  });

  factory MarketplaceAsset.fromJson(Map<String, dynamic> json) {
    return MarketplaceAsset(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      category: json['category']?.toString() ?? '',
      style: json['style']?.toString() ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      isPaid: json['is_paid'] == true,
      price: (json['price'] ?? 0) as int,
      currency: json['currency']?.toString() ?? 'usd',
      thumbObjectKey: json['thumb_object_key']?.toString(),
      modelObjectKey: json['model_object_key']?.toString(),
      thumbUrl: json['thumb_url']?.toString(),
      previewUrl: json['preview_url']?.toString(),
      metadata: (json['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }

  String get author => metadata['creator_username']?.toString() ?? 'Unknown';

  String get likes => metadata['likes']?.toString() ?? '0';
}

class MarketplaceService {
  MarketplaceService(this._api);

  final ApiClient _api;

  Future<List<MarketplaceAsset>> listAssets({
    String? query,
    String? category,
    String? style,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (category != null && category.isNotEmpty && category != 'All') {
      params['category'] = category;
    }
    if (style != null && style.isNotEmpty && style != 'All') {
      params['style'] = style;
    }

    final list = await _api.getJsonList('/marketplace/assets', query: params);
    return list
        .whereType<Map<String, dynamic>>()
        .map(MarketplaceAsset.fromJson)
        .toList();
  }

  Future<String> checkoutAsset(String assetId) async {
    final data = await _api.postJson('/billing/checkout/asset',
        auth: true, body: {'asset_id': assetId});
    return data['checkout_url']?.toString() ?? '';
  }

  Future<String> downloadAsset(String assetId) async {
    final data = await _api.getJson('/assets/$assetId/download', auth: true);
    return data['url']?.toString() ?? '';
  }
}
