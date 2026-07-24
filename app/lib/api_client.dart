// Content repository: fetches from the backend when online, caches the content
// pack for offline use, and provides an offline cite-or-refuse fallback for Ask.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'content_sync_client.dart';
import 'models.dart';
import 'settings.dart';
import 'offline_database.dart';

const String kBaseUrl = String.fromEnvironment(
  'KYR_BASE_URL',
  // Production API on Render. Override for local backend with:
  // flutter run --dart-define=KYR_BASE_URL=http://127.0.0.1:8000
  defaultValue: 'https://knowyourrights-api.onrender.com',
);
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
const bool kSupabaseConfigured =
    kSupabaseUrl != '' && kSupabasePublishableKey != '';
const String _cacheKey = 'kyr_content_pack_v1';
const String _disclaimer =
    'This is legal information, not legal advice. For advice on your specific '
    'situation, speak to a qualified lawyer.';
const String _refusal =
    "I could not find this in the verified rights information available offline. "
    "I would rather say I don't know than risk giving you wrong legal information. "
    "Please consult a lawyer or the Legal Aid Council - see Get help.";

const Set<String> _stopwords = {
  'a',
  'an',
  'and',
  'are',
  'as',
  'at',
  'be',
  'by',
  'for',
  'from',
  'has',
  'have',
  'how',
  'i',
  'in',
  'is',
  'it',
  'of',
  'on',
  'or',
  'the',
  'to',
  'was',
  'what',
  'when',
  'my',
  'me',
  'can',
  'do',
  'you',
  'your',
  'they',
  'them',
  'this',
  'that',
};

class ContentRepository {
  ContentRepository({http.Client? client, OfflineDatabase? database})
    : _client = client ?? http.Client(),
      _database = database ?? OfflineDatabase.instance {
    _sync = ContentPackSyncClient(database: _database, client: _client);
  }

  final http.Client _client;
  final OfflineDatabase _database;
  late final ContentPackSyncClient _sync;

  List<Topic> topics = [];
  List<Scenario> scenarios = [];
  List<DirectoryEntry> directory = [];
  List<Obligation> obligations = [];
  List<CompanyChecklist> companyChecklists = [];
  List<CaseBrief> cases = [];
  int version = 0;
  bool loadedFromCache = false;
  DateTime? lastSyncedAt;
  String? syncError;

  Map<String, bool> get offlineAvailability => {
    'Rights and offline answers': topics.isNotEmpty,
    'Emergency guides': scenarios.isNotEmpty,
    'Emergency directory': directory.isNotEmpty,
    'Student case search': cases.isNotEmpty,
    'Company reference': obligations.isNotEmpty,
    'Generative AI answers': false,
  };

  /// Load content: try the network, fall back to the cached pack when offline.
  Future<void> load() async {
    try {
      await _sync.syncAll();
      await _loadDatabase();
      loadedFromCache = false;
      lastSyncedAt = DateTime.now();
      syncError = null;
      return;
    } catch (error) {
      syncError = error.toString();
      if (await _loadDatabase()) {
        loadedFromCache = true;
        return;
      }
    }
    final cached = await _readCache();
    if (cached != null) {
      _parsePack(jsonDecode(cached) as Map<String, dynamic>);
      loadedFromCache = true;
    }
  }

  Future<String?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheKey);
  }

  Future<bool> _loadDatabase() async {
    final topicRows = await _database.records('rights', 'NG-Federal', 'topics');
    final scenarioRows = await _database.records(
      'rights',
      'NG-Federal',
      'scenarios',
    );
    final directoryRows = await _database.records(
      'rights',
      'NG-Federal',
      'directory',
    );
    final obligationRows = await _database.records(
      'company',
      'NG-Federal',
      'obligations',
    );
    final checklistRows = await _database.records(
      'company',
      'NG-Federal',
      'company_checklists',
    );
    final caseRows = await _database.records('students', 'NG-Federal', 'cases');
    if (topicRows.isEmpty && scenarioRows.isEmpty && caseRows.isEmpty) {
      return false;
    }
    topics = topicRows.map(Topic.fromJson).toList();
    scenarios = scenarioRows.map(Scenario.fromJson).toList();
    directory = directoryRows.map(DirectoryEntry.fromJson).toList();
    obligations = obligationRows.map(Obligation.fromJson).toList();
    companyChecklists = checklistRows.map(CompanyChecklist.fromJson).toList();
    cases = caseRows.map(CaseBrief.fromJson).toList();
    final states = await _database.select(_database.contentSyncStates).get();
    version = states.fold(0, (best, item) {
      return item.contentVersion > best ? item.contentVersion : best;
    });
    lastSyncedAt = states
        .map((state) => state.lastCheckedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (best, item) {
          return best == null || item.isAfter(best) ? item : best;
        });
    return true;
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
    obligations = (json['obligations'] as List? ?? [])
        .map((item) => Obligation.fromJson(item as Map<String, dynamic>))
        .toList();
    companyChecklists = (json['company_checklists'] as List? ?? [])
        .map((item) => CompanyChecklist.fromJson(item as Map<String, dynamic>))
        .toList();
    cases = (json['cases'] as List? ?? [])
        .map((item) => CaseBrief.fromJson(item as Map<String, dynamic>))
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

  Obligation? obligationById(String id) {
    for (final obligation in obligations) {
      if (obligation.id == id) return obligation;
    }
    return null;
  }

  CaseBrief? caseById(String id) {
    for (final caseBrief in cases) {
      if (caseBrief.id == id) return caseBrief;
    }
    return null;
  }

  List<CaseBrief> searchCases(String query) {
    final q = _tokens(query);
    if (q.isEmpty) return cases;
    final scored =
        cases
            .map((c) => MapEntry(c, _overlap(q, _tokens(_caseText(c)))))
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  List<Topic> searchTopics(String query) {
    final q = _tokens(query);
    if (q.isEmpty) return topics;
    final scored =
        topics
            .map((t) => MapEntry(t, _overlap(q, _tokens(_topicText(t)))))
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Ask the backend; if offline, answer from cached verified topics or refuse.
  /// Report an error on any content or answer. Never gated behind an account:
  /// the reader who spots wrong law is often the least likely to have signed up.
  Future<bool> reportError(String targetType, String targetId, String message) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$kBaseUrl/v1/error-reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'target_type': targetType,
              'target_id': targetId,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Incognito Ask: when on, the server neither caches nor logs the question.
  Map<String, String> _incognitoHeader() =>
      appSettings.incognito ? const {'X-KYR-Incognito': '1'} : const {};

  Future<AskResponse> ask(String question) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$kBaseUrl/v1/ask'),
            headers: {'Content-Type': 'application/json', ..._incognitoHeader()},
            body: jsonEncode({'question': question}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return AskResponse.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // fall through to offline answer
    }
    return _offlineAsk(question);
  }

  Future<AskResponse> askCompany(String question) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$kBaseUrl/v1/company/ask'),
            headers: {'Content-Type': 'application/json', ..._incognitoHeader()},
            body: jsonEncode({'question': question}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return AskResponse.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Company answers require the separately reviewed server-side index.
    }
    return const AskResponse(
      refused: true,
      answer:
          'I cannot verify this company-law question while offline. Please '
          'consult a qualified Nigerian company-law practitioner or company secretary.',
      citations: [],
      relatedTopicIds: [],
      disclaimer: _disclaimer,
    );
  }

  Future<AskResponse> askStudents(String question) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$kBaseUrl/v1/students/ask'),
            headers: {'Content-Type': 'application/json', ..._incognitoHeader()},
            body: jsonEncode({'question': question}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return AskResponse.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // fall through to offline case search
    }
    return _offlineAskStudents(question);
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
      buffer.write(
        '\n\nKey points:\n${best.rights.map((r) => '- $r').join('\n')}',
      );
    }
    return AskResponse(
      refused: false,
      answer: buffer.toString(),
      citations: best.citations,
      relatedTopicIds: results.skip(1).take(2).map((t) => t.id).toList(),
      disclaimer: _disclaimer,
    );
  }

  AskResponse _offlineAskStudents(String question) {
    final results = searchCases(question);
    if (results.isEmpty || results.first.citations.isEmpty) {
      return const AskResponse(
        refused: true,
        answer:
            "I could not find this in the verified case-law materials available "
            "offline. Check a licensed law report or ask your lecturer.",
        citations: [],
        relatedTopicIds: [],
        disclaimer: _disclaimer,
      );
    }
    final best = results.first;
    final buffer = StringBuffer(
      '${best.name}\n\n${best.summary}\n\nRatio:\n${best.ratio}',
    );
    return AskResponse(
      refused: false,
      answer: buffer.toString(),
      citations: best.citations,
      relatedTopicIds: results.skip(1).take(2).map((c) => c.id).toList(),
      disclaimer: _disclaimer,
    );
  }

  String _topicText(Topic t) =>
      '${t.title} ${t.summary} ${t.bodyPlain} ${t.rights.join(' ')} ${t.doList.join(' ')}';

  String _caseText(CaseBrief c) =>
      '${c.name} ${c.court} ${c.year} ${c.areaOfLaw} ${c.summary} ${c.facts} '
      '${c.holding} ${c.ratio} ${c.issues.join(' ')} '
      '${c.interpretations.map((i) => i.body).join(' ')}';

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
