import 'dart:convert';
import 'package:http/http.dart' as http;
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';
import '../playlist/models/now_playing.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  Future<List<({String name, int count})>> getCategories() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/categories'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null || decoded is! List) return [];
      return decoded.map((g) => (name: g['category'] as String, count: g['channelCount'] as int)).toList();
    }
    throw Exception('Failed to load categories');
  }

  Future<({List<Channel> channels, int total})> getChannels({
    String? category,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{'limit': limit.toString(), 'offset': offset.toString()};
    if (category != null) params['category'] = category;
    if (search != null) params['search'] = search;

    final uri = Uri.parse('$baseUrl/api/channels').replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> channelsJson = data['channels'] ?? [];
      final total = data['total'] as int? ?? 0;
      return (channels: channelsJson.map((json) => Channel.fromJson(json)).toList(), total: total);
    }
    throw Exception('Failed to load channels');
  }

  Future<List<Channel>> getFeaturedChannels({int limit = 10}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/channels/featured?limit=$limit'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null || decoded is! List) return [];
      return decoded.map((json) => Channel.fromJson(json)).toList();
    }
    throw Exception('Failed to load featured channels');
  }

  Future<List<NowPlayingItem>> getNowPlaying() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/epg/now'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null || decoded is! List) return [];
      return decoded.map((json) => NowPlayingItem.fromJson(json)).toList();
    }
    throw Exception('Failed to load now playing');
  }

  Future<List<NowPlayingItem>> getUpcomingAll({int withinMinutes = 180, int limit = 50}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/epg/upcoming?within=$withinMinutes&limit=$limit'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null || decoded is! List) return [];
      return decoded.map((json) => NowPlayingItem.fromJson(json)).toList();
    }
    throw Exception('Failed to load upcoming');
  }

  Future<List<NowPlayingItem>> getFeaturedNowPlaying({int limit = 10}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/epg/featured?limit=$limit'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded == null || decoded is! List) return [];
      return decoded.map((json) => NowPlayingItem.fromJson(json)).toList();
    }
    throw Exception('Failed to load featured now playing');
  }

  Future<EpgProgram?> getCurrentProgram(int channelId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/channels/$channelId/epg?limit=1'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return null;
      final prog = EpgProgram.fromJson(data.first);
      if (prog.isNow) return prog;
      return null;
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to load current program');
  }

  Future<List<EpgProgram>> getUpcomingPrograms(int channelId, {int limit = 10}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/channels/$channelId/epg?limit=$limit'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => EpgProgram.fromJson(json)).toList();
    }
    throw Exception('Failed to load upcoming programs');
  }

  Future<String?> getBestStreamUrl(int channelId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/channels/$channelId/streams'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return null;
      return data.first['url'] as String?;
    }
    return null;
  }

  String thumbnailUrl(int channelId) => '$baseUrl/api/channels/$channelId/thumbnail.jpg';

  void dispose() {
    _client.close();
  }
}
