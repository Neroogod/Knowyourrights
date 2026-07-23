// Content repository: fetches from the backend when online, caches the content
// pack for offline use, and provides an offline cite-or-refuse fallback for Ask.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const String kBaseUrl = String.fromEnvironment(
  'KYR_BASE_URL',
  // Production API on Render. Override for local backend with:
  // flutter run --dart-define=KYR_BASE_URL=http://127.0.0.1:8000
  defaultValue: 'https://knowyourrights-api.onrender.com',
);
const String _cacheKey = 'kyr_content_pack_v1';
const String _disclaimer =
    'This is legal information, not legal advice. For advice on your specific '
    'situation, speak to a qualified lawyer.';
const String _refusal =
    "I could not find this in the verified rights information available offline. "
    "I would rather say I don't know than risk giving you wrong legal information. "
    "Please consult a lawyer or the Legal Aid Council - see Get help.";

const Set<String> _stopwords = {
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from', 'has', 'have',
  'how', 'i', 'in', 'is', 'it', 'of', 'on', 'or', 'the', 'to', 'was', 'what',
  'when', 'my', 'me', 'can', 'do', 'you', 'your', 'they', 'them', 'this', 'that',
};

class ContentRepository {
  ContentRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  List<Topic> topics = [];
  List<Scenario> scenarios = [];
  List<DirectoryEntry> directory = [];
  int version = 0;
  bool loadedFromCache = false;

  /// Load content: try the network, fall back to the cached pack when offline.
  Future<void> load() async {
    try {
      final resp = await _client
          .get(Uri.parse('$kBaseUrl/v1/content-pack'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        await _cache(resp.body);
        _parsePack(jsonDecode(resp.body) as Map<String, dynamic>);
        loadedFromCache = false;
        return;
      }
    } catch (_) {
      // fall through to cache
    }
    final cached = await _readCache();
    if (cached != null) {
      _parsePack(jsonDecode(cached) as Map<String, dynamic>);
      loadedFromCache = true;
    }
  }

  Future<void> _cache(String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, body);
  }

  Future<String?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheKey);
  }

  void _parsePack(Map<String, dynamic> json) {
    version = json['version'] as int? ?? 0;
    topics = (json['topics'] as List? ?? [])
        .map((t) => Topic.fromJson(t as Map<String, dynamic>))
        .toList();
    scenarios = (json['scenarios'] as List? ?? [])
        .map((s) => Scenario.fromJson(s as Map<String, dynamic>))
        .toList();
    directory = (json['directory'] as List? ?? [])
        .map((d) => DirectoryEntry.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Look up a scenario by id; null when the pack does not contain it.
  Scenario? scenarioById(String id) {
    for (final s in scenarios) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Look up a topic by id; null when the pack does not contain it.
  Topic? topicById(String id) {
    for (final t in topics) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Topic> searchTopics(String query) {
    final q = _tokens(query);
    if (q.isEmpty) return topics;
    final scored = topics
        .map((t) => MapEntry(t, _overlap(q, _tokens(_topicText(t)))))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Ask the backend; if offline, answer from cached verified topics or refuse.
  Future<AskResponse> ask(String question) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$kBaseUrl/v1/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'question': question}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return AskResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // fall through to offline answer
    }
    return _offlineAsk(question);
  }

  AskResponse _offlineAsk(String question) {
    final results = searchTopics(question);
    if (results.isEmpty || results.first.citations.isEmpty) {
      return const AskResponse(
        refused: true,
        answer: _refusal,
        citations: [],
        relatedTopicIds: [],
        disclaimer: _disclaimer,
      );
    }
    final best = results.first;
    final buffer = StringBuffer('${best.title}\n\n${best.summary}');
    if (best.rights.isNotEmpty) {
      buffer.write('\n\nKey points:\n${best.rights.map((r) => '- $r').join('\n')}');
    }
    return AskResponse(
      refused: false,
      answer: buffer.toString(),
      citations: best.citations,
      relatedTopicIds: results.skip(1).take(2).map((t) => t.id).toList(),
      disclaimer: _disclaimer,
    );
  }

  String _topicText(Topic t) =>
      '${t.title} ${t.summary} ${t.bodyPlain} ${t.rights.join(' ')} ${t.doList.join(' ')}';

  Set<String> _tokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 1 && !_stopwords.contains(w))
      .toSet();

  double _overlap(Set<String> q, Set<String> d) {
    if (q.isEmpty) return 0;
    return q.intersection(d).length / q.length;
  }
}
