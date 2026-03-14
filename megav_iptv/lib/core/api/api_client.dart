import 'dart:convert';
import 'package:http/http.dart' as http;
import '../playlist/models/channel.dart';
import '../playlist/models/epg_program.dart';

/// Thin client to interact with the IPTV backend server.
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  /// Fetch all available channel groups (categories) with their channel counts
  Future<List<({String name, int count})>> getGroups() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/groups'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((g) => (name: g['name'] as String, count: g['count'] as int)).toList();
    }
    throw Exception('Failed to load groups');
  }

  /// Fetch channels for a specific group (with pagination)
  Future<List<Channel>> getChannels({String? group, int limit = 20, int offset = 0}) async {
    final uri = Uri.parse(
      '$baseUrl/api/channels',
    ).replace(queryParameters: {'group': ?group, 'limit': limit.toString(), 'offset': offset.toString()});

    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Channel.fromJson(json)).toList();
    }
    throw Exception('Failed to load channels');
  }

  /// Fetch featured channels for the home screen header
  Future<List<Channel>> getFeaturedChannels({int limit = 10}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/channels/featured?limit=$limit'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Channel.fromJson(json)).toList();
    }
    throw Exception('Failed to load featured channels');
  }

  /// Get current EPG program for a specific channel
  Future<EpgProgram?> getCurrentProgram(String channelId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/epg/current?channelId=$channelId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data?.isEmpty ?? true) return null;
      return EpgProgram.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to load current program');
  }

  /// Get upcoming EPG programs for a specific channel
  Future<List<EpgProgram>> getUpcomingPrograms(String channelId, {int limit = 10}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/epg/upcoming?channelId=$channelId&limit=$limit'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => EpgProgram.fromJson(json)).toList();
    }
    throw Exception('Failed to load upcoming programs');
  }

  void dispose() {
    _client.close();
  }
}
