import 'package:flutter/material.dart';

import 'actions.dart';
import 'api_client.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  runApp(const KnowYourRightsApp());
}

class KnowYourRightsApp extends StatelessWidget {
  const KnowYourRightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Know Your Rights',
      debugShowCheckedModeBanner: false,
      theme: buildKyrTheme(Brightness.light),
      darkTheme: buildKyrTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
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

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final pages = [
      HomeScreen(repo: _repo, onTab: _goToTab),
      RightsScreen(repo: _repo),
      ScenariosScreen(repo: _repo),
      AskScreen(repo: _repo),
      DirectoryScreen(repo: _repo),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const _BrandSeal(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Know Your Rights', style: serifStyle(size: 18, color: p.ink)),
                Text('Nigeria · 1999 Constitution',
                    style: TextStyle(fontSize: 11, color: p.muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_repo.loadedFromCache)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration:
                  BoxDecoration(color: p.greenTint, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: p.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Offline',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.green)),
              ]),
            ),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Rights'),
          NavigationDestination(icon: Icon(Icons.warning_amber_rounded), label: 'Emergency'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Ask'),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Help'),
        ],
      ),
    );
  }
}

class _BrandSeal extends StatelessWidget {
  const _BrandSeal();

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [p.gold, p.goldTint, p.gold, p.goldInk, p.gold],
          startAngle: 0.6,
          endAngle: 6.9,
        ),
      ),
      child: Icon(Icons.balance_rounded, size: 16, color: p.greenDeep),
    );
  }
}

// ---------------------------------------------------------------- Home

class HomeScreen extends StatelessWidget {
  final ContentRepository repo;
  final ValueChanged<int> onTab;
  const HomeScreen({required this.repo, required this.onTab, super.key});

  static const List<(String, String)> _triggers = [
    ('police-want-to-search-phone', 'Police want my phone'),
    ('checkpoint-stop', 'Stopped at a checkpoint'),
    ('held-too-long-in-detention', "I'm being detained"),
    ('life-in-danger', 'My life is in danger'),
  ];

  void _openScenario(BuildContext context, String id) {
    final s = repo.scenarioById(id);
    if (s == null) {
      onTab(2);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScenarioDetailScreen(scenario: s, repo: repo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final featured = repo.topics.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // The arrest moment leads the app - it is the thing people open it for.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.sos, p.sosDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: p.sos.withValues(alpha: 0.32),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('IN AN EMERGENCY',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    color: p.onSos.withValues(alpha: 0.9))),
            const SizedBox(height: 4),
            Text('Do you know your rights right now?',
                style: serifStyle(size: 23, color: p.onSos, height: 1.15)),
            const SizedBox(height: 14),
            Material(
              color: p.onSos,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openScenario(context, 'being-arrested'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(children: [
                    Expanded(
                      child: Text("I'm being arrested",
                          style: TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w800, color: p.sosDeep)),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: p.sosDeep, size: 20),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 3.1,
              children: _triggers
                  .map((t) => Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openScenario(context, t.$1),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: Text(t.$2,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.onSos)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Custody Alert - designed, not yet wired (see the full product spec).
        KyrCard(
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: p.sosTint,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: p.sos.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 4)],
              ),
              child: Icon(Icons.notifications_active_outlined, color: p.sos, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Custody Alert',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 2),
                Text('One tap tells your people where you are. (Coming soon)',
                    style: TextStyle(fontSize: 13, color: p.muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        KyrCard(
          onTap: () => onTab(3),
          child: Row(children: [
            Icon(Icons.search_rounded, color: p.green, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Text('Ask a question in your own words…',
                  style: TextStyle(fontSize: 14.5, color: p.faint)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        const SectionLabel('Your rights'),
        const SizedBox(height: 8),
        ...featured.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TopicCard(topic: t),
            )),
        Center(
          child: TextButton(
            onPressed: () => onTab(1),
            child: Text('See all ${repo.topics.length} rights',
                style: TextStyle(color: p.green, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Rights

class TopicCard extends StatelessWidget {
  final Topic topic;
  const TopicCard({required this.topic, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return KyrCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: topic))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CategoryTag(topic.category),
          const SizedBox(width: 8),
          if (topic.status == 'verified') const VerifiedBadge(),
        ]),
        const SizedBox(height: 7),
        Text(topic.title, style: serifStyle(size: 17.5, color: p.ink, height: 1.2)),
        const SizedBox(height: 4),
        Text(topic.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.35)),
      ]),
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
    final p = context.kyr;
    final topics = widget.repo.searchTopics(_query);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search your rights…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      Expanded(
        child: topics.isEmpty
            ? Center(
                child: Text('No matching rights found.',
                    style: TextStyle(color: p.faint)),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                itemCount: topics.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => TopicCard(topic: topics[i]),
              ),
      ),
    ]);
  }
}

class TopicDetailScreen extends StatelessWidget {
  final Topic topic;
  const TopicDetailScreen({required this.topic, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final quoted = topic.citations.where((c) => c.quote != null && c.quote!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(children: [
            CategoryTag(topic.category),
            const SizedBox(width: 8),
            if (topic.status == 'verified') const VerifiedBadge(),
          ]),
          const SizedBox(height: 10),
          Text(topic.title, style: serifStyle(size: 26, color: p.ink, height: 1.15)),
          const SizedBox(height: 10),
          Text(topic.summary,
              style: serifStyle(size: 17, weight: FontWeight.w500, color: p.ink, height: 1.4)),
          const SizedBox(height: 10),
          Text(topic.bodyPlain, style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.5)),
          const SizedBox(height: 16),
          InfoBlock(title: 'Your rights', items: topic.rights, kind: BlockKind.rights),
          if (topic.rights.isNotEmpty) const SizedBox(height: 10),
          InfoBlock(title: 'What to do', items: topic.doList, kind: BlockKind.dos),
          if (topic.doList.isNotEmpty) const SizedBox(height: 10),
          InfoBlock(title: 'What not to do', items: topic.dontList, kind: BlockKind.donts),
          const SizedBox(height: 18),
          const SectionLabel('Sources'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: topic.citations.map((c) => CitationChip(c)).toList(),
          ),
          ...quoted.map((c) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: p.line, width: 2)),
                  ),
                  child: Text('“${c.quote}”',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          color: p.muted,
                          height: 1.45)),
                ),
              )),
          const SizedBox(height: 18),
          Row(children: [
            if (topic.status == 'verified') ...[
              const VerifiedBadge(),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                'Reviewed by ${topic.reviewedBy ?? '—'}'
                '${topic.reviewedAt != null ? ' · ${topic.reviewedAt}' : ''}',
                style: TextStyle(fontSize: 12, color: p.faint),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Emergencies

class ScenariosScreen extends StatelessWidget {
  final ContentRepository repo;
  const ScenariosScreen({required this.repo, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final scenarios = repo.scenarios;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: scenarios.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('Emergency guides · work offline',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    color: p.sos)),
          );
        }
        final s = scenarios[i - 1];
        return KyrCard(
          accent: p.sos,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ScenarioDetailScreen(scenario: s, repo: repo)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.trigger, style: serifStyle(size: 17.5, color: p.ink, height: 1.2)),
            const SizedBox(height: 4),
            Text(s.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.35)),
          ]),
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
    final p = context.kyr;
    final linked = scenario.linkedTopicIds
        .map(repo.topicById)
        .whereType<Topic>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text('EMERGENCY · WORKS OFFLINE',
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w800, color: p.sos)),
          const SizedBox(height: 6),
          Text(scenario.trigger, style: serifStyle(size: 26, color: p.ink, height: 1.15)),
          const SizedBox(height: 8),
          Text(scenario.description,
              style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.45)),
          const SizedBox(height: 20),
          ...scenario.steps.asMap().entries.map((e) {
            final step = e.value;
            final isCall = step.action == 'call';
            final target = callTargetFor(step.value);
            final bool urgent = step.value == 'emergency_line';
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: p.green.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text('${e.key + 1}',
                      style: TextStyle(
                          color: p.onGreen, fontSize: 13.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(step.text,
                          style: TextStyle(fontSize: 15, color: p.ink, height: 1.45)),
                    ),
                    if (isCall)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: urgent ? p.sos : p.green,
                            foregroundColor: urgent ? p.onSos : p.onGreen,
                          ),
                          onPressed: () => _call(context, step.value),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: Text(target.label),
                        ),
                      ),
                  ]),
                ),
              ]),
            );
          }),
          const SectionLabel('Grounded in'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
                scenario.citations.map((c) => CitationChip(c, withSource: false)).toList(),
          ),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Learn more'),
            const SizedBox(height: 8),
            ...linked.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TopicCard(topic: t),
                )),
          ],
          const SizedBox(height: 12),
          Text('This is legal information, not legal advice.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: p.faint)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Ask

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
    'Do I have to pay for bail?',
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final r = _response;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text('Ask a question', style: serifStyle(size: 24, color: p.ink)),
        const SizedBox(height: 6),
        Text(
          'Answers come only from verified law, always with citations. '
          'If it cannot verify, it refuses — it never guesses.',
          style: TextStyle(fontSize: 14, color: p.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(hintText: 'e.g. Can the police search my phone?'),
            ),
          ),
          const SizedBox(width: 9),
          FilledButton(onPressed: _asking ? null : () => _ask(), child: const Text('Ask')),
        ]),
        const SizedBox(height: 16),
        if (_asking)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        if (r != null && !_asking) _AnswerCard(response: r),
        const SizedBox(height: 18),
        const SectionLabel('Try asking'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () => _ask(s),
                    backgroundColor: p.card,
                    side: BorderSide(color: p.line),
                    labelStyle: TextStyle(fontSize: 13, color: p.ink),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final AskResponse response;
  const _AnswerCard({required this.response});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final accent = response.refused ? p.sos : p.green;
    return AccentSurface(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          response.refused ? "I can't verify this yet." : "Here's what the law says.",
          style: serifStyle(size: 17, color: response.refused ? p.sosInk : p.ink),
        ),
        const SizedBox(height: 8),
        Text(response.answer, style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.5)),
        if (response.citations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: response.citations.map((c) => CitationChip(c)).toList(),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
          child: Text(response.disclaimer,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: p.faint)),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Directory

class DirectoryScreen extends StatelessWidget {
  final ContentRepository repo;
  const DirectoryScreen({required this.repo, super.key});

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

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final entries = repo.directory;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Get help', style: serifStyle(size: 24, color: p.ink)),
            const SizedBox(height: 4),
            Text('Emergency lines and legal-aid organisations.',
                style: TextStyle(fontSize: 14, color: p.muted)),
          ]);
        }
        final e = entries[i - 1];
        final urgent = e.entryType == 'emergency';
        return KyrCard(
          accent: urgent ? p.sos : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 3),
            Text(
              '${e.entryType.replaceAll('_', ' ')}${e.state != null ? ' · ${e.state}' : ''}',
              style: TextStyle(fontSize: 12, color: p.faint),
            ),
            const SizedBox(height: 11),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (e.phone != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: urgent ? p.sos : p.green,
                    foregroundColor: urgent ? p.onSos : p.onGreen,
                  ),
                  onPressed: () =>
                      _launch(context, dialNumber(e.phone), 'Could not open the phone app.'),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text('Call ${e.phone}'),
                ),
              if (e.url != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      _launch(context, openLink(e.url!), 'Could not open the link.'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Website'),
                ),
            ]),
          ]),
        );
      },
    );
  }
}
