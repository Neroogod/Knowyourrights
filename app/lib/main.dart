import 'package:flutter/material.dart';

import 'actions.dart';
import 'api_client.dart';
import 'models.dart';

void main() {
  runApp(const KnowYourRightsApp());
}

const Color kGreen = Color(0xFF0B6B3A);
const Color kGreenDark = Color(0xFF084D2A);

class KnowYourRightsApp extends StatelessWidget {
  const KnowYourRightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KnowYourRights',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ContentRepository _repo = ContentRepository();
  int _index = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.load().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AskScreen(repo: _repo),
      RightsScreen(repo: _repo),
      ScenariosScreen(repo: _repo),
      DirectoryScreen(repo: _repo),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: const Text('KnowYourRights'),
        bottom: _repo.loadedFromCache
            ? const PreferredSize(
                preferredSize: Size.fromHeight(24),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Offline mode - showing saved content',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.question_answer_outlined), label: 'Ask'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Rights'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Emergencies'),
          NavigationDestination(icon: Icon(Icons.contact_phone_outlined), label: 'Get help'),
        ],
      ),
    );
  }
}

class CitationChip extends StatelessWidget {
  final Citation citation;
  const CitationChip(this.citation, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF7F1),
        border: Border.all(color: const Color(0xFFD7EBE0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${citation.sourceName.split(' ').first} ${citation.locator}',
          style: const TextStyle(color: kGreenDark, fontSize: 12)),
    );
  }
}

class AskScreen extends StatefulWidget {
  final ContentRepository repo;
  const AskScreen({required this.repo, super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _controller = TextEditingController();
  AskResponse? _response;
  bool _asking = false;

  static const List<String> _suggestions = [
    'Can the police search my phone?',
    'What are my rights when arrested?',
    'How long can I be detained?',
    'Am I allowed to remain silent?',
  ];

  Future<void> _ask([String? preset]) async {
    final q = (preset ?? _controller.text).trim();
    if (q.isEmpty) return;
    if (preset != null) _controller.text = preset;
    setState(() => _asking = true);
    final resp = await widget.repo.ask(q);
    if (mounted) {
      setState(() {
        _response = resp;
        _asking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _response;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Ask a question',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Answers come only from verified law, always with citations. '
          'If it is not sure, it will say so.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                hintText: 'e.g. Can the police search my phone?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: _asking ? null : () => _ask(),
            child: const Text('Ask'),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          children: _suggestions
              .map((s) => Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ActionChip(label: Text(s), onPressed: () => _ask(s)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        if (_asking) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (r != null && !_asking)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: r.refused ? const Color(0xFFB3261E) : kGreen,
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(r.answer, style: const TextStyle(fontSize: 15)),
                  ),
                  Wrap(children: r.citations.map((c) => CitationChip(c)).toList()),
                  const SizedBox(height: 10),
                  Text(r.disclaimer,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class RightsScreen extends StatefulWidget {
  final ContentRepository repo;
  const RightsScreen({required this.repo, super.key});

  @override
  State<RightsScreen> createState() => _RightsScreenState();
}

class _RightsScreenState extends State<RightsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final topics = widget.repo.searchTopics(_query);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search your rights...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: topics.length,
            itemBuilder: (_, i) {
              final t = topics[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(t.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: t.status == 'verified'
                      ? const Icon(Icons.verified, color: kGreen, size: 20)
                      : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: t)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TopicDetailScreen extends StatelessWidget {
  final Topic topic;
  const TopicDetailScreen({required this.topic, super.key});

  Widget _bulletSection(String title, List<String> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 6),
        ...items.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('- $r'),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: kGreen, foregroundColor: Colors.white, title: Text(topic.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(topic.summary, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Text(topic.bodyPlain, style: const TextStyle(color: Colors.black87, height: 1.4)),
          _bulletSection('Your rights', topic.rights, Icons.gavel, kGreen),
          _bulletSection('What to do', topic.doList, Icons.check_circle, kGreen),
          _bulletSection("What NOT to do", topic.dontList, Icons.cancel, const Color(0xFFB3261E)),
          const SizedBox(height: 16),
          const Text('Sources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Wrap(children: topic.citations.map((c) => CitationChip(c)).toList()),
          const SizedBox(height: 16),
          Text('Reviewed by: ${topic.reviewedBy ?? '-'}  ${topic.reviewedAt ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class ScenariosScreen extends StatelessWidget {
  final ContentRepository repo;
  const ScenariosScreen({required this.repo, super.key});

  @override
  Widget build(BuildContext context) {
    final scenarios = repo.scenarios;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: scenarios.length,
      itemBuilder: (_, i) {
        final s = scenarios[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.warning_amber, color: Color(0xFFB3261E)),
            title: Text(s.trigger, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ScenarioDetailScreen(scenario: s, repo: repo)),
            ),
          ),
        );
      },
    );
  }
}

class ScenarioDetailScreen extends StatelessWidget {
  final Scenario scenario;
  final ContentRepository repo;
  const ScenarioDetailScreen({required this.scenario, required this.repo, super.key});

  Future<void> _call(BuildContext context, String? value) async {
    final target = callTargetFor(value);
    try {
      final ok = await dialNumber(target.number);
      if (!ok && context.mounted) {
        _toast(context, 'Could not open the phone app. ${target.label}.');
      }
    } catch (_) {
      if (context.mounted) _toast(context, 'Could not open the phone app. ${target.label}.');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final linked = scenario.linkedTopicIds
        .map((id) => repo.topics.where((t) => t.id == id))
        .expand((e) => e)
        .toList();

    return Scaffold(
      appBar: AppBar(backgroundColor: kGreen, foregroundColor: Colors.white, title: Text(scenario.trigger)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(scenario.description, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          ...scenario.steps.asMap().entries.map((e) {
            final step = e.value;
            final isCall = step.action == 'call';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: kGreen,
                        child: Text('${e.key + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(step.text, style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                  if (isCall)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 8),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        onPressed: () => _call(context, step.value),
                        icon: const Icon(Icons.call, size: 18),
                        label: Text(callTargetFor(step.value).label),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Wrap(children: scenario.citations.map((c) => CitationChip(c)).toList()),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Learn more', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            ...linked.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined, color: kGreen),
                  title: Text(t.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: t)),
                  ),
                )),
          ],
          const SizedBox(height: 16),
          const Text(
            'This is legal information, not legal advice.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class DirectoryScreen extends StatelessWidget {
  final ContentRepository repo;
  const DirectoryScreen({required this.repo, super.key});

  @override
  Widget build(BuildContext context) {
    final entries = repo.directory;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.contact_phone, color: kGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text([e.entryType, if (e.state != null) e.state!].join('  -  '),
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  if (e.phone != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      onPressed: () => _launch(context, dialNumber(e.phone), 'Could not open the phone app.'),
                      icon: const Icon(Icons.call, size: 18),
                      label: Text('Call ${e.phone}'),
                    ),
                  if (e.url != null)
                    OutlinedButton.icon(
                      onPressed: () => _launch(context, openLink(e.url!), 'Could not open the link.'),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Website'),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launch(BuildContext context, Future<bool> action, String onError) async {
    try {
      final ok = await action;
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(onError)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(onError)));
      }
    }
  }
}
