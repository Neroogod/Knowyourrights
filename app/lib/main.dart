import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'account_client.dart';
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
      home: const AccountGate(),
    );
  }
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key});

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  final AccountClient _accounts = AccountClient();
  bool _loading = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    var ready = false;
    try {
      if (await _accounts.isSignedIn) {
        final profile = await _accounts.profile();
        final contacts = await _accounts.contacts();
        ready =
            profile.emailVerified &&
            profile.onboardingComplete &&
            contacts.any((contact) => contact.status == 'verified');
      }
    } catch (_) {
      await _accounts.signOut();
    }
    if (mounted) {
      setState(() {
        _ready = ready;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_ready) {
      return HomeShell(onSignedOut: () => setState(() => _ready = false));
    }
    return CustodyOnboardingScreen(
      accounts: _accounts,
      appRegistration: true,
      onCompleted: () => setState(() => _ready = true),
    );
  }
}

class HomeShell extends StatefulWidget {
  final VoidCallback? onSignedOut;
  const HomeShell({this.onSignedOut, super.key});

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
      CompaniesScreen(repo: _repo),
      StudentsScreen(repo: _repo),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const _BrandSeal(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Know Your Rights',
                    style: serifStyle(size: 18, color: p.ink),
                  ),
                  Text(
                    'Nigeria · 1999 Constitution',
                    style: TextStyle(
                      fontSize: 11,
                      color: p.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_repo.loadedFromCache)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: p.greenTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: p.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(onSignedOut: widget.onSignedOut),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Rights',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Emergency',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Ask',
          ),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Help'),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            label: 'Company',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: 'Students',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onSignedOut;
  const ProfileScreen({this.onSignedOut, super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AccountClient _accounts = AccountClient();
  AccountProfile? _profile;
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _accounts.profile();
    final contacts = await _accounts.contacts();
    if (mounted) {
      setState(() {
        _profile = profile;
        _contacts = contacts;
      });
    }
  }

  Future<void> _signOut() async {
    await _accounts.signOut();
    widget.onSignedOut?.call();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  profile.fullName ?? 'Your profile',
                  style: serifStyle(size: 27, color: p.ink),
                ),
                const SizedBox(height: 16),
                KyrCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Account'),
                      Text(
                        profile.email,
                        style: TextStyle(fontSize: 15, color: p.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.emailVerified
                            ? 'Email verified'
                            : 'Email verification pending',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: profile.emailVerified ? p.green : p.sos,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SectionLabel('Phone'),
                      Text(
                        profile.phone ?? '—',
                        style: TextStyle(fontSize: 15, color: p.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Emergency contact'),
                const SizedBox(height: 8),
                ..._contacts.map(
                  (contact) => KyrCard(
                    accent: contact.status == 'verified' ? p.green : p.sos,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: serifStyle(size: 17, color: p.ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          contact.phone,
                          style: TextStyle(fontSize: 14, color: p.muted),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          contact.status == 'verified'
                              ? 'Verified and connected to Custody Alert'
                              : contact.status,
                          style: TextStyle(
                            fontSize: 12,
                            color: contact.status == 'verified'
                                ? p.green
                                : p.sos,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                OutlinedButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
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
      MaterialPageRoute(
        builder: (_) => ScenarioDetailScreen(scenario: s, repo: repo),
      ),
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
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IN AN EMERGENCY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: p.onSos.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Do you know your rights right now?',
                style: serifStyle(size: 23, color: p.onSos, height: 1.15),
              ),
              const SizedBox(height: 14),
              Material(
                color: p.onSos,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openScenario(context, 'being-arrested'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "I'm being arrested",
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: p.sosDeep,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: p.sosDeep,
                          size: 20,
                        ),
                      ],
                    ),
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
                    .map(
                      (t) => Material(
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
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              t.$2,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: p.onSos,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        KyrCard(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CustodyAlertScreen())),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.sosTint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.sos.withValues(alpha: 0.18),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: p.sos,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custody Alert',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set up a verified contact and share your location in danger',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        KyrCard(
          onTap: () => onTab(3),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: p.green, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Ask a question in your own words…',
                  style: TextStyle(fontSize: 14.5, color: p.faint),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const SectionLabel('Your rights'),
        const SizedBox(height: 8),
        ...featured.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TopicCard(topic: t),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => onTab(1),
            child: Text(
              'See all ${repo.topics.length} rights',
              style: TextStyle(color: p.green, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class CustodyAlertScreen extends StatefulWidget {
  const CustodyAlertScreen({super.key});

  @override
  State<CustodyAlertScreen> createState() => _CustodyAlertScreenState();
}

class _CustodyAlertScreenState extends State<CustodyAlertScreen> {
  final AccountClient _accounts = AccountClient();
  EmergencyContact? _contact;
  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    try {
      final contacts = await _accounts.contacts();
      final verified = contacts.where(
        (contact) => contact.status == 'verified',
      );
      if (mounted) setState(() => _contact = verified.firstOrNull);
    } catch (_) {
      // No authenticated/verified setup yet.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _prepareAlert() async {
    if (_opening) return;
    setState(() => _opening = true);
    var ok = false;
    try {
      ok = await prepareCustodyAlert(phone: _contact?.phone);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the messaging app.')),
      );
    }
  }

  Future<void> _sendAutomaticAlert() async {
    final contact = _contact;
    if (contact == null || _opening) return;
    setState(() => _opening = true);
    Position? position;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
      final key = 'alert-${DateTime.now().microsecondsSinceEpoch}';
      final response = await _accounts.sendAlert(
        contactId: contact.id,
        idempotencyKey: key,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
      );
      if (mounted) {
        final suffix = response['location_shared'] == true
            ? ' Your last known location was included.'
            : ' It was sent without location.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Custody Alert sent.$suffix')));
      }
    } catch (_) {
      try {
        await prepareCustodyAlert(phone: contact.phone);
      } catch (_) {
        // The existing SMS fallback button remains available for another try.
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Scaffold(
      appBar: AppBar(title: const Text('Custody Alert')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.sosTint, shape: BoxShape.circle),
            child: Icon(
              Icons.notifications_active_outlined,
              color: p.sos,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tell someone you are in custody',
            style: serifStyle(size: 26, color: p.ink, height: 1.15),
          ),
          const SizedBox(height: 8),
          Text(
            _contact == null
                ? 'Set up and verify an emergency contact before enabling automatic alerts.'
                : 'Press and hold to notify ${_contact!.name}. The app requests '
                      'your location only when you trigger the alert.',
            style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          AccentSurface(
            accent: p.sos,
            child: Text(
              custodyAlertMessage,
              style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 17, color: p.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _contact == null
                      ? 'Your contact must affirmatively confirm before receiving alerts.'
                      : 'Location is captured once at trigger time. If permission is denied, '
                            'the alert is sent without it.',
                  style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_contact == null)
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CustodyOnboardingScreen(accounts: _accounts),
                  ),
                );
                await _loadContact();
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Set up Custody Alert'),
            )
          else
            GestureDetector(
              onLongPress: _opening ? null : _sendAutomaticAlert,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  color: _opening ? p.faint : p.sos,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _opening ? 'Sending alert…' : 'Press and hold to send alert',
                  style: TextStyle(
                    color: p.onSos,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: p.sos,
              foregroundColor: p.onSos,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: _opening ? null : _prepareAlert,
            icon: const Icon(Icons.sms_outlined),
            label: Text(_opening ? 'Opening messages…' : 'Send by SMS'),
          ),
          const SizedBox(height: 10),
          Text(
            'If you are in immediate danger, call 112 when it is safe to do so.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.faint),
          ),
        ],
      ),
    );
  }
}

class CustodyOnboardingScreen extends StatefulWidget {
  final AccountClient accounts;
  final bool appRegistration;
  final VoidCallback? onCompleted;
  const CustodyOnboardingScreen({
    required this.accounts,
    this.appRegistration = false,
    this.onCompleted,
    super.key,
  });

  @override
  State<CustodyOnboardingScreen> createState() =>
      _CustodyOnboardingScreenState();
}

class _CustodyOnboardingScreenState extends State<CustodyOnboardingScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    for (final controller in [
      _email,
      _password,
      _fullName,
      _phone,
      _contactName,
      _contactPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      final emailToken = await widget.accounts.register(email, password);
      if (emailToken != null) {
        await widget.accounts.verifyEmail(emailToken);
      }
      await widget.accounts.login(email, password);
      await widget.accounts.saveProfile(_fullName.text, _phone.text.trim());
      final (_, contactToken) = await widget.accounts.addContact(
        _contactName.text,
        _contactPhone.text.trim(),
      );
      if (contactToken == null) {
        setState(() {
          _message =
              'Verification messages were sent. Finish email and contact '
              'verification before using automatic alerts.';
        });
        return;
      }
      await widget.accounts.verifyContact(contactToken);
      if (mounted) {
        if (widget.appRegistration) {
          widget.onCompleted?.call();
        } else {
          Navigator.of(context).pop();
        }
      }
    } on AccountApiError catch (error) {
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.accounts.login(_email.text.trim(), _password.text);
      final profile = await widget.accounts.profile();
      final contacts = await widget.accounts.contacts();
      final ready =
          profile.onboardingComplete &&
          contacts.any((contact) => contact.status == 'verified');
      if (!ready) {
        setState(() {
          _message =
              'This account still needs a completed profile and verified '
              'emergency contact.';
        });
        return;
      }
      widget.onCompleted?.call();
    } on AccountApiError catch (error) {
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Scaffold(
      appBar: widget.appRegistration
          ? null
          : AppBar(title: const Text('Set up Custody Alert')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          widget.appRegistration ? 54 : 8,
          16,
          32,
        ),
        children: [
          if (widget.appRegistration) ...[
            Row(
              children: [
                const _BrandSeal(),
                const SizedBox(width: 10),
                Text(
                  'Know Your Rights',
                  style: serifStyle(size: 22, color: p.ink),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          Text(
            widget.appRegistration
                ? 'Create your profile'
                : 'Create your safety profile',
            style: serifStyle(size: 27, color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(
            widget.appRegistration
                ? 'Register to personalize the app and connect a verified emergency '
                      'contact to Custody Alert.'
                : 'Your email and emergency contact must be verified before automatic '
                      'alerts are enabled.',
            style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Account'),
          _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
          _field(_password, 'Password (at least 12 characters)', obscure: true),
          const SectionLabel('Your details'),
          _field(_fullName, 'Full name'),
          _field(_phone, 'Phone number', keyboardType: TextInputType.phone),
          const SectionLabel('Emergency contact'),
          _field(_contactName, 'Contact name'),
          _field(
            _contactPhone,
            'Contact phone number',
            keyboardType: TextInputType.phone,
          ),
          if (_message != null) ...[
            Text(
              _message!,
              style: TextStyle(fontSize: 13, color: p.sos, height: 1.4),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: _busy ? null : _completeSetup,
            child: Text(_busy ? 'Setting up…' : 'Create and verify setup'),
          ),
          if (widget.appRegistration) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _signIn,
              child: const Text('Already registered? Sign in'),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'In production, verification links are delivered by email and SMS. '
            'Local development verifies them through the non-sending adapter.',
            style: TextStyle(fontSize: 11.5, color: p.faint, height: 1.35),
          ),
        ],
      ),
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: topic)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryTag(topic.category),
              const SizedBox(width: 8),
              if (topic.status == 'verified') const VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            topic.title,
            style: serifStyle(size: 17.5, color: p.ink, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            topic.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.35),
          ),
        ],
      ),
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
    return Column(
      children: [
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
                  child: Text(
                    'No matching rights found.',
                    style: TextStyle(color: p.faint),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  itemCount: topics.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => TopicCard(topic: topics[i]),
                ),
        ),
      ],
    );
  }
}

class TopicDetailScreen extends StatelessWidget {
  final Topic topic;
  const TopicDetailScreen({required this.topic, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final quoted = topic.citations.where(
      (c) => c.quote != null && c.quote!.isNotEmpty,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              CategoryTag(topic.category),
              const SizedBox(width: 8),
              if (topic.status == 'verified') const VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            topic.title,
            style: serifStyle(size: 26, color: p.ink, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            topic.summary,
            style: serifStyle(
              size: 17,
              weight: FontWeight.w500,
              color: p.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            topic.bodyPlain,
            style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          InfoBlock(
            title: 'Your rights',
            items: topic.rights,
            kind: BlockKind.rights,
          ),
          if (topic.rights.isNotEmpty) const SizedBox(height: 10),
          InfoBlock(
            title: 'What to do',
            items: topic.doList,
            kind: BlockKind.dos,
          ),
          if (topic.doList.isNotEmpty) const SizedBox(height: 10),
          InfoBlock(
            title: 'What not to do',
            items: topic.dontList,
            kind: BlockKind.donts,
          ),
          if (topic.commonSituations.isNotEmpty) ...[
            const SizedBox(height: 10),
            InfoBlock(
              title: 'When this right matters',
              items: topic.commonSituations,
              kind: BlockKind.rights,
            ),
          ],
          if (topic.wordsToUse.isNotEmpty) ...[
            const SizedBox(height: 10),
            InfoBlock(
              title: 'Words you can use',
              items: topic.wordsToUse,
              kind: BlockKind.dos,
            ),
          ],
          if (topic.ifViolated.isNotEmpty) ...[
            const SizedBox(height: 10),
            InfoBlock(
              title: 'If this right is violated',
              items: topic.ifViolated,
              kind: BlockKind.donts,
            ),
          ],
          const SizedBox(height: 18),
          const SectionLabel('Sources'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: topic.citations.map((c) => CitationChip(c)).toList(),
          ),
          ...quoted.map(
            (c) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: p.line, width: 2)),
                ),
                child: Text(
                  '“${c.quote}”',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: p.muted,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
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
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Companies

class CompaniesScreen extends StatelessWidget {
  final ContentRepository repo;
  const CompaniesScreen({required this.repo, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text(
          'Company compliance',
          style: serifStyle(size: 26, color: p.ink, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(
          'Source-grounded CAMA information for Nigerian companies. '
          'The starter content is pending lawyer review.',
          style: TextStyle(fontSize: 14, color: p.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        KyrCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CompanyAskScreen(repo: repo)),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: p.green, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Ask a company-law question',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: p.green, size: 19),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Obligations'),
        const SizedBox(height: 8),
        if (repo.obligations.isEmpty)
          Text(
            'No company obligations are available in this content pack.',
            style: TextStyle(color: p.muted),
          )
        else
          ...repo.obligations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KyrCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ObligationDetailScreen(obligation: item),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryTag(item.category),
                        const SizedBox(width: 8),
                        if (item.status == 'verified') const VerifiedBadge(),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.title,
                      style: serifStyle(size: 17.5, color: p.ink, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: p.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const SectionLabel('Checklists'),
        const SizedBox(height: 8),
        ...repo.companyChecklists.map(
          (checklist) => KyrCard(
            accent: p.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checklist.title,
                  style: serifStyle(size: 18, color: p.ink, height: 1.2),
                ),
                const SizedBox(height: 5),
                Text(
                  checklist.description,
                  style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                ...checklist.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_box_outline_blank_rounded,
                          size: 19,
                          color: p.green,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: p.ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CompanyAskScreen extends StatefulWidget {
  final ContentRepository repo;
  const CompanyAskScreen({required this.repo, super.key});

  @override
  State<CompanyAskScreen> createState() => _CompanyAskScreenState();
}

class _CompanyAskScreenState extends State<CompanyAskScreen> {
  final _controller = TextEditingController();
  AskResponse? _response;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    setState(() => _loading = true);
    final response = await widget.repo.askCompany(question);
    if (mounted) {
      setState(() {
        _response = response;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final response = _response;
    return Scaffold(
      appBar: AppBar(title: const Text('Company questions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Ask about company compliance',
            style: serifStyle(size: 24, color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Answers use only lawyer-verified company material. Draft content is excluded.',
            style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _ask(),
            decoration: const InputDecoration(
              hintText: 'When must my company file an annual return?',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loading ? null : _ask,
            child: Text(_loading ? 'Checking…' : 'Ask'),
          ),
          if (response != null) ...[
            const SizedBox(height: 16),
            AccentSurface(
              accent: response.refused ? p.sos : p.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response.refused
                        ? "I can't verify this yet."
                        : 'Grounded answer',
                    style: serifStyle(size: 17, color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    response.answer,
                    style: TextStyle(fontSize: 14, color: p.ink, height: 1.45),
                  ),
                  if (response.citations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: response.citations
                          .map((c) => CitationChip(c))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    response.disclaimer,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.faint,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ObligationDetailScreen extends StatelessWidget {
  final Obligation obligation;
  const ObligationDetailScreen({required this.obligation, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              CategoryTag(obligation.category),
              const SizedBox(width: 8),
              if (obligation.status == 'verified') const VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            obligation.title,
            style: serifStyle(size: 26, color: p.ink, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            obligation.summary,
            style: TextStyle(fontSize: 15, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Applies to: ${obligation.appliesTo.join(', ')}',
            style: TextStyle(fontSize: 13, color: p.faint),
          ),
          const SizedBox(height: 16),
          InfoBlock(
            title: 'What the company must do',
            items: obligation.requirements,
            kind: BlockKind.dos,
          ),
          const SizedBox(height: 18),
          const SectionLabel('Sources'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: obligation.citations.map((c) => CitationChip(c)).toList(),
          ),
          if (obligation.status != 'verified') ...[
            const SizedBox(height: 18),
            Text(
              'Pending lawyer review. Use this as general legal information, not advice.',
              style: TextStyle(fontSize: 12.5, color: p.faint, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Students

class StudentsScreen extends StatefulWidget {
  final ContentRepository repo;
  const StudentsScreen({required this.repo, super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final cases = _query.trim().isEmpty
        ? widget.repo.cases
        : widget.repo.searchCases(_query);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text(
          'Case-law library',
          style: serifStyle(size: 26, color: p.ink, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(
          'Educational digests for law students: facts, issues, holding, ratio, '
          'and study notes. Proprietary law-report text is not copied — use a '
          'licensed report for the full judgment.',
          style: TextStyle(fontSize: 14, color: p.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        KyrCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentAskScreen(repo: widget.repo),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: p.green, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Ask about a case',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: p.green, size: 19),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search cases, courts, holdings…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Cases'),
        const SizedBox(height: 8),
        if (cases.isEmpty)
          Text(
            'No matching cases in this content pack.',
            style: TextStyle(color: p.muted),
          )
        else
          ...cases.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KyrCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaseDetailScreen(
                      caseBrief: item,
                      repo: widget.repo,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryTag(item.areaOfLaw),
                        const SizedBox(width: 8),
                        if (item.status == 'verified') const VerifiedBadge(),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.name,
                      style: serifStyle(size: 17.5, color: p.ink, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.court} · ${item.year}',
                      style: TextStyle(fontSize: 12.5, color: p.faint),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: p.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class StudentAskScreen extends StatefulWidget {
  final ContentRepository repo;
  const StudentAskScreen({required this.repo, super.key});

  @override
  State<StudentAskScreen> createState() => _StudentAskScreenState();
}

class _StudentAskScreenState extends State<StudentAskScreen> {
  final _controller = TextEditingController();
  AskResponse? _response;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    setState(() => _loading = true);
    final response = await widget.repo.askStudents(question);
    if (mounted) {
      setState(() {
        _response = response;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final response = _response;
    return Scaffold(
      appBar: AppBar(title: const Text('Case questions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Ask about case law',
            style: serifStyle(size: 24, color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Answers use only verified educational case digests. '
            'Always check a licensed law report for the full judgment.',
            style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _ask(),
            decoration: const InputDecoration(
              hintText: 'What did Agbakoba say about passport seizure?',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loading ? null : _ask,
            child: Text(_loading ? 'Checking…' : 'Ask'),
          ),
          if (response != null) ...[
            const SizedBox(height: 16),
            AccentSurface(
              accent: response.refused ? p.sos : p.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response.refused
                        ? "I can't verify this yet."
                        : 'Grounded study answer',
                    style: serifStyle(size: 17, color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    response.answer,
                    style: TextStyle(fontSize: 14, color: p.ink, height: 1.45),
                  ),
                  if (response.citations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: response.citations
                          .map((c) => CitationChip(c))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    response.disclaimer,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.faint,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CaseDetailScreen extends StatelessWidget {
  final CaseBrief caseBrief;
  final ContentRepository repo;
  const CaseDetailScreen({
    required this.caseBrief,
    required this.repo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final linkedTopics = caseBrief.linkedTopicIds
        .map(repo.topicById)
        .whereType<Topic>()
        .toList();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              CategoryTag(caseBrief.areaOfLaw),
              const SizedBox(width: 8),
              if (caseBrief.status == 'verified') const VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            caseBrief.name,
            style: serifStyle(size: 24, color: p.ink, height: 1.15),
          ),
          const SizedBox(height: 6),
          Text(
            '${caseBrief.court} · ${caseBrief.year}',
            style: TextStyle(fontSize: 13, color: p.faint),
          ),
          const SizedBox(height: 12),
          Text(
            caseBrief.summary,
            style: TextStyle(fontSize: 15, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Facts'),
          const SizedBox(height: 8),
          Text(
            caseBrief.facts,
            style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.45),
          ),
          const SizedBox(height: 16),
          InfoBlock(
            title: 'Issues',
            items: caseBrief.issues,
            kind: BlockKind.dos,
          ),
          const SizedBox(height: 16),
          const SectionLabel('Holding'),
          const SizedBox(height: 8),
          Text(
            caseBrief.holding,
            style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.45),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Ratio'),
          const SizedBox(height: 8),
          Text(
            caseBrief.ratio,
            style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.45),
          ),
          if (caseBrief.interpretations.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionLabel('Study notes'),
            const SizedBox(height: 8),
            ...caseBrief.interpretations.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KyrCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryTag(note.kind),
                      const SizedBox(height: 8),
                      Text(
                        note.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: p.ink,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (linkedTopics.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('Linked rights topics'),
            const SizedBox(height: 8),
            ...linkedTopics.map(
              (topic) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(topic.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TopicDetailScreen(topic: topic),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const SectionLabel('Sources'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: caseBrief.citations.map((c) => CitationChip(c)).toList(),
          ),
          if (caseBrief.sourceUrl != null) ...[
            const SizedBox(height: 14),
            Text(
              'Full judgment: use a licensed law-report service '
              '(link stored: ${caseBrief.sourceUrl}). '
              'This app does not copy proprietary report text.',
              style: TextStyle(fontSize: 12.5, color: p.faint, height: 1.4),
            ),
          ],
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
            child: Text(
              'Emergency guides · work offline',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
                color: p.sos,
              ),
            ),
          );
        }
        final s = scenarios[i - 1];
        return KyrCard(
          accent: p.sos,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScenarioDetailScreen(scenario: s, repo: repo),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.trigger,
                style: serifStyle(size: 17.5, color: p.ink, height: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                s.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ScenarioDetailScreen extends StatelessWidget {
  final Scenario scenario;
  final ContentRepository repo;
  const ScenarioDetailScreen({
    required this.scenario,
    required this.repo,
    super.key,
  });

  Future<void> _run(BuildContext context, StepActionTarget target) async {
    final failure = target.url != null
        ? 'Could not open the link.'
        : 'Could not open the phone app.';
    try {
      final ok = target.url != null
          ? await openLink(target.url!)
          : await dialNumber(target.phone);
      if (!ok && context.mounted) _toast(context, failure);
    } catch (_) {
      if (context.mounted) _toast(context, failure);
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
          Text(
            'EMERGENCY · WORKS OFFLINE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
              color: p.sos,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scenario.trigger,
            style: serifStyle(size: 26, color: p.ink, height: 1.15),
          ),
          const SizedBox(height: 8),
          Text(
            scenario.description,
            style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          ...scenario.steps.asMap().entries.map((e) {
            final step = e.value;
            final target = resolveStepAction(
              step.action,
              step.value,
              repo.directory,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        color: p.onGreen,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            step.text,
                            style: TextStyle(
                              fontSize: 15,
                              color: p.ink,
                              height: 1.45,
                            ),
                          ),
                        ),
                        if (target != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: target.urgent
                                    ? p.sos
                                    : p.green,
                                foregroundColor: target.urgent
                                    ? p.onSos
                                    : p.onGreen,
                              ),
                              onPressed: () => _run(context, target),
                              icon: Icon(
                                target.url != null
                                    ? Icons.open_in_new_rounded
                                    : Icons.call_rounded,
                                size: 18,
                              ),
                              label: Text(target.label),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SectionLabel('Grounded in'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: scenario.citations
                .map((c) => CitationChip(c, withSource: false))
                .toList(),
          ),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Learn more'),
            const SizedBox(height: 8),
            ...linked.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TopicCard(topic: t),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'This is legal information, not legal advice.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: p.faint,
            ),
          ),
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _ask(),
                decoration: const InputDecoration(
                  hintText: 'e.g. Can the police search my phone?',
                ),
              ),
            ),
            const SizedBox(width: 9),
            FilledButton(
              onPressed: _asking ? null : () => _ask(),
              child: const Text('Ask'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_asking)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        if (r != null && !_asking) _AnswerCard(response: r),
        const SizedBox(height: 18),
        const SectionLabel('Try asking'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (s) => ActionChip(
                  label: Text(s),
                  onPressed: () => _ask(s),
                  backgroundColor: p.card,
                  side: BorderSide(color: p.line),
                  labelStyle: TextStyle(fontSize: 13, color: p.ink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              )
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response.refused
                ? "I can't verify this yet."
                : "Here's what the law says.",
            style: serifStyle(
              size: 17,
              color: response.refused ? p.sosInk : p.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            response.answer,
            style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.5),
          ),
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Text(
              response.disclaimer,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: p.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Directory

class DirectoryScreen extends StatelessWidget {
  final ContentRepository repo;
  const DirectoryScreen({required this.repo, super.key});

  Future<void> _launch(
    BuildContext context,
    Future<bool> action,
    String onError,
  ) async {
    try {
      final ok = await action;
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(onError)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(onError)));
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Get help', style: serifStyle(size: 24, color: p.ink)),
              const SizedBox(height: 4),
              Text(
                'Emergency lines and legal-aid organisations.',
                style: TextStyle(fontSize: 14, color: p.muted),
              ),
            ],
          );
        }
        final e = entries[i - 1];
        final urgent = e.entryType == 'emergency';
        return KyrCard(
          accent: urgent ? p.sos : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${e.entryType.replaceAll('_', ' ')}${e.state != null ? ' · ${e.state}' : ''}',
                style: TextStyle(fontSize: 12, color: p.faint),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (e.phone != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: urgent ? p.sos : p.green,
                        foregroundColor: urgent ? p.onSos : p.onGreen,
                      ),
                      onPressed: () => _launch(
                        context,
                        dialNumber(e.phone),
                        'Could not open the phone app.',
                      ),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text('Call ${e.phone}'),
                    ),
                  if (e.url != null)
                    OutlinedButton.icon(
                      onPressed: () => _launch(
                        context,
                        openLink(e.url!),
                        'Could not open the link.',
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Website'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
