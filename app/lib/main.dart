import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_client.dart';
import 'actions.dart';
import 'api_client.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

final ValueNotifier<ThemeMode> kyrThemeMode = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kSupabaseConfigured) {
    await Supabase.initialize(
      url: kSupabaseUrl,
      publishableKey: kSupabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  final preferences = await SharedPreferences.getInstance();
  if (kSupabaseConfigured &&
      preferences.getBool('kyr_keep_signed_in') == false &&
      Supabase.instance.client.auth.currentSession != null) {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  }
  kyrThemeMode.value = preferences.getBool('kyr_dark_mode') == true
      ? ThemeMode.dark
      : ThemeMode.light;
  runApp(const KnowYourRightsApp());
}

class KnowYourRightsApp extends StatelessWidget {
  const KnowYourRightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: kyrThemeMode,
      builder: (_, mode, _) => MaterialApp(
        title: 'Know Your Rights',
        debugShowCheckedModeBanner: false,
        theme: buildKyrTheme(Brightness.light),
        darkTheme: buildKyrTheme(Brightness.dark),
        themeMode: mode,
        home: const AccountGate(),
      ),
    );
  }
}

Future<void> toggleKyrTheme() async {
  final dark = kyrThemeMode.value != ThemeMode.dark;
  kyrThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool('kyr_dark_mode', dark);
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: toggleKyrTheme,
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
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
  bool _openCustodyAlert = false;

  @override
  void initState() {
    super.initState();
    _configureShortcuts();
    _checkSetup();
  }

  Future<void> _configureShortcuts() async {
    try {
      const actions = QuickActions();
      await actions.initialize((shortcutType) {
        if (shortcutType != 'custody_alert' && shortcutType != 'safe_walk') {
          return;
        }
        _openCustodyAlert = true;
        _openPendingShortcut();
      });
      await actions.setShortcutItems([
        const ShortcutItem(
          type: 'custody_alert',
          localizedTitle: 'Custody Alert',
        ),
        const ShortcutItem(
          type: 'safe_walk',
          localizedTitle: 'Start Safe Walk',
        ),
      ]);
    } on PlatformException {
      // Optional on simulators and unsupported platforms.
    }
  }

  void _openPendingShortcut() {
    if (!_ready || !_openCustodyAlert || !mounted) return;
    _openCustodyAlert = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CustodyAlertScreen()));
    });
  }

  Future<void> _checkSetup() async {
    var ready = false;
    try {
      if (await _accounts.isSignedIn) {
        await _accounts.retryQueuedAlerts();
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
      _openPendingShortcut();
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
    final pages =
        <Widget>[
              HomeScreen(repo: _repo, onTab: _goToTab),
              RightsScreen(repo: _repo),
              ScenariosScreen(repo: _repo),
              AskScreen(repo: _repo),
              MoreScreen(repo: _repo),
            ]
            .map(
              (page) => Material(type: MaterialType.transparency, child: page),
            )
            .toList();

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
          const ThemeToggleButton(),
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
      body: _GlassBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: p.line.withValues(alpha: 0.72)),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: p.ink.withValues(alpha: 0.12),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _goToTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
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
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
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

  Future<void> _manageSessions() async {
    final sessions = await _accounts.sessions();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signed-in devices'),
        content: SizedBox(
          width: 420,
          child: sessions.isEmpty
              ? const Text(
                  'This device will appear after its next API request.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sessions
                      .map(
                        (session) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.devices_outlined),
                          title: Text(session['device_name'] as String),
                          subtitle: Text(
                            session['current'] == true
                                ? 'Current session'
                                : 'Last active ${session['last_seen_at']}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _accounts.signOutOtherDevices();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sign out other devices'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail() async {
    final currentPassword = await _confirmSensitiveAction(
      'Confirm before changing email',
    );
    if (currentPassword == null || currentPassword.isEmpty) return;
    await _accounts.reauthenticateWithPassword(currentPassword);
    if (!mounted) return;
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'New email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    try {
      await _accounts.changeEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Confirm the change from both your old and new email addresses.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<String?> _confirmSensitiveAction(String title) async {
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            labelText: 'Confirm your current password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    password.dispose();
    return value;
  }

  Future<void> _exportAccount() async {
    final password = await _confirmSensitiveAction('Export your data');
    if (password == null || password.isEmpty) return;
    try {
      await _accounts.reauthenticateWithPassword(password);
      final export = const JsonEncoder.withIndent(
        '  ',
      ).convert(await _accounts.exportAccount());
      await Clipboard.setData(ClipboardData(text: export));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account export was copied securely.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final password = await _confirmSensitiveAction('Delete your account');
    if (password == null || password.isEmpty) return;
    try {
      await _accounts.reauthenticateWithPassword(password);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permanently delete account?'),
          content: const Text(
            'This removes your profile, contacts, alert history, and managed '
            'sign-in. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep account'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _accounts.deleteAccount();
      widget.onSignedOut?.call();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _addEmergencyContact() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    var whatsapp = false;
    var useEmail = false;
    final values = await showDialog<(String, String, String?, List<String>)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add emergency contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Contact name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: whatsapp,
                  onChanged: (value) =>
                      setDialogState(() => whatsapp = value ?? false),
                  title: const Text('Also use WhatsApp'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: useEmail,
                  onChanged: (value) =>
                      setDialogState(() => useEmail = value ?? false),
                  title: const Text('Also use email'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final channels = <String>['sms'];
                if (whatsapp) channels.add('whatsapp');
                if (useEmail) channels.add('email');
                Navigator.pop(context, (
                  name.text.trim(),
                  phone.text.trim(),
                  email.text.trim().isEmpty ? null : email.text.trim(),
                  channels,
                ));
              },
              child: const Text('Send invitation'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    email.dispose();
    if (values == null || values.$1.length < 2 || values.$2.length < 8) return;
    try {
      final (_, token) = await _accounts.addContact(
        values.$1,
        values.$2,
        email: values.$3,
        channels: values.$4,
      );
      if (token != null) await _accounts.verifyContact(token);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              token == null
                  ? 'Invitation sent. This contact must confirm consent.'
                  : 'Development contact verified.',
            ),
          ),
        );
      }
    } on AccountApiError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removeEmergencyContact(EmergencyContact contact) async {
    await _accounts.removeContact(contact.id);
    await _load();
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
                        const SizedBox(height: 5),
                        Text(
                          'Channels: ${contact.channels.join(', ')}',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _removeEmergencyContact(contact),
                            child: const Text('Remove'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_contacts.length < 3) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addEmergencyContact,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                      _contacts.isEmpty
                          ? 'Add emergency contact'
                          : 'Add another contact',
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionLabel('Security and privacy'),
                const SizedBox(height: 8),
                KyrCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.alternate_email_rounded),
                        title: const Text('Change email address'),
                        subtitle: const Text(
                          'Requires confirmation from both email addresses',
                        ),
                        onTap: _changeEmail,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices_outlined),
                        title: const Text('Signed-in devices'),
                        onTap: _manageSessions,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('Export my data'),
                        onTap: _exportAccount,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline, color: p.sos),
                        title: Text(
                          'Delete account',
                          style: TextStyle(color: p.sos),
                        ),
                        onTap: _deleteAccount,
                      ),
                    ],
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

class _GlassBackdrop extends StatelessWidget {
  final Widget child;
  const _GlassBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(p.paper, p.greenTint, 0.24)!,
            p.paper,
            Color.lerp(p.paper, p.goldTint, 0.22)!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -90,
            top: 45,
            child: _GlowOrb(color: p.green.withValues(alpha: 0.12), size: 260),
          ),
          Positioned(
            right: -110,
            bottom: 70,
            child: _GlowOrb(color: p.gold.withValues(alpha: 0.13), size: 290),
          ),
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  final ContentRepository repo;
  const MoreScreen({required this.repo, super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final destinations = [
      (
        Icons.call_outlined,
        'Get help',
        'Emergency lines and legal-aid organisations',
        DirectoryScreen(repo: repo),
      ),
      (
        Icons.business_outlined,
        'Company',
        'Company-law obligations and checklists',
        CompaniesScreen(repo: repo),
      ),
      (
        Icons.school_outlined,
        'Students',
        'Case briefs and study tools',
        StudentsScreen(repo: repo),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text('More', style: serifStyle(size: 30, color: p.ink)),
        const SizedBox(height: 6),
        Text(
          'Help, specialist tools, and learning resources.',
          style: TextStyle(color: p.muted, fontSize: 14),
        ),
        const SizedBox(height: 18),
        ...destinations.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: KyrCard(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => item.$4)),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.greenTint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.$1, color: p.green),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: serifStyle(size: 17, color: p.ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.faint),
                ],
              ),
            ),
          ),
        ),
      ],
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
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 3, 2, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR RIGHTS · YOUR SAFETY',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: p.green,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Know what to do when it matters.',
                style: serifStyle(size: 29, color: p.ink, height: 1.08),
              ),
            ],
          ),
        ),
        // The arrest moment leads the app - it is the thing people open it for.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.green, p.greenDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: p.green.withValues(alpha: 0.28),
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
                'IMMEDIATE GUIDANCE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: p.onGreen.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Are you dealing with the police right now?',
                style: serifStyle(size: 24, color: p.onGreen, height: 1.15),
              ),
              const SizedBox(height: 14),
              Material(
                color: p.onGreen,
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
              Column(
                children: [
                  for (var row = 0; row < 2; row++) ...[
                    Row(
                      children: [
                        for (var column = 0; column < 2; column++) ...[
                          if (column > 0) const SizedBox(width: 9),
                          Expanded(
                            child: SizedBox(
                              height: 58,
                              child: _EmergencyShortcut(
                                label: _triggers[row * 2 + column].$2,
                                onTap: () => _openScenario(
                                  context,
                                  _triggers[row * 2 + column].$1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (row == 0) const SizedBox(height: 9),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        KyrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                          'Alert your emergency contact and share your location when available.',
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.sos,
                        foregroundColor: p.onSos,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustodyAlertScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Send alert'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: p.sos),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustodyAlertScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('Send SMS'),
                    ),
                  ),
                ],
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

class _EmergencyShortcut extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EmergencyShortcut({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.kyr.onGreen,
            ),
          ),
        ),
      ),
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
  final TextEditingController _station = TextEditingController();
  EmergencyContact? _contact;
  List<EmergencyContact> _contacts = [];
  Map<String, dynamic>? _lastAlert;
  Map<String, dynamic>? _activeCheckIn;
  bool _loading = true;
  bool _opening = false;

  @override
  void dispose() {
    _station.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    try {
      final contacts = await _accounts.contacts();
      final verified = contacts
          .where((contact) => contact.status == 'verified')
          .take(3)
          .toList();
      if (mounted) {
        setState(() {
          _contacts = verified;
          _contact = verified.firstOrNull;
        });
      }
      final checkIn = await _accounts.activeCheckIn();
      if (mounted) setState(() => _activeCheckIn = checkIn);
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

  Future<void> _sendAutomaticAlert({bool isTest = false}) async {
    final contacts = _contacts;
    if (contacts.isEmpty || _opening) return;
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
      final responses = <Map<String, dynamic>>[];
      for (var index = 0; index < contacts.length; index++) {
        responses.add(
          await _accounts.sendAlert(
            contactId: contacts[index].id,
            idempotencyKey: '$key-$index',
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracy: position?.accuracy,
            stationName: _station.text.trim().isEmpty
                ? null
                : _station.text.trim(),
            isTest: isTest,
          ),
        );
      }
      final response = responses.first;
      if (mounted) {
        setState(() => _lastAlert = response);
        final failed = responses
            .where((item) => item['status'] == 'failed')
            .length;
        final delivered = responses
            .where((item) => item['status'] == 'delivered')
            .length;
        final suffix = response['location_shared'] == true
            ? ' Your last known location was included.'
            : ' It was sent without location.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTest
                  ? 'Test alert sent to ${contacts.length} '
                        '${contacts.length == 1 ? 'contact' : 'contacts'}.'
                  : failed > 0
                  ? 'Sent to ${contacts.length - failed} of ${contacts.length} contacts. '
                        'Use SMS fallback for anyone not reached.'
                  : delivered == contacts.length
                  ? 'Delivery confirmed for all ${contacts.length} contacts.$suffix'
                  : 'The provider accepted alerts for all ${contacts.length} contacts; '
                        'delivery is not yet confirmed.$suffix',
            ),
          ),
        );
        if (failed > 0) {
          final failedIndex = responses.indexWhere(
            (item) => item['status'] == 'failed',
          );
          final direct = await sendCustodyAlertDirect(
            phone: contacts[failedIndex].phone,
          );
          if (!direct) {
            await prepareCustodyAlert(phone: contacts[failedIndex].phone);
          }
        }
      }
    } catch (_) {
      try {
        final direct = await sendCustodyAlertDirect(
          phone: contacts.first.phone,
        );
        if (!direct) await prepareCustodyAlert(phone: contacts.first.phone);
      } catch (_) {
        // The existing SMS fallback button remains available for another try.
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _confirmAutomaticAlert() async {
    final contact = _contact;
    if (contact == null) {
      await _setUpContact();
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlertCountdownSheet(
        contactName: _contacts.map((item) => item.name).join(', '),
      ),
    );
    if (confirmed == true && mounted) await _sendAutomaticAlert();
  }

  Future<void> _sendTestAlert() async {
    if (_contacts.isEmpty) {
      await _setUpContact();
      return;
    }
    await _sendAutomaticAlert(isTest: true);
  }

  Future<void> _refreshAlert() async {
    final id = _lastAlert?['id'] as String?;
    if (id == null || _opening) return;
    setState(() => _opening = true);
    try {
      final response = await _accounts.getAlert(id);
      if (mounted) setState(() => _lastAlert = response);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _updateAlert(String action) async {
    final id = _lastAlert?['id'] as String?;
    if (id == null || _opening) return;
    setState(() => _opening = true);
    try {
      final response = switch (action) {
        'cancel' => await _accounts.cancelAlert(id),
        'resolve' => await _accounts.resolveAlert(id),
        'retry' => await _accounts.retryAlert(id),
        _ => throw ArgumentError('unknown alert action'),
      };
      if (mounted) setState(() => _lastAlert = response);
    } on AccountApiError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _setUpContact() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustodyOnboardingScreen(accounts: _accounts),
      ),
    );
    if (mounted) await _loadContact();
  }

  Future<void> _showAlertHistory() async {
    final alerts = await _accounts.alertHistory();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(
                'Alert delivery history',
                style: serifStyle(size: 24, color: context.kyr.ink),
              ),
              const SizedBox(height: 12),
              if (alerts.isEmpty)
                const Text('No alerts have been sent yet.')
              else
                ...alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KyrCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${alert['is_test'] == true ? 'TEST · ' : ''}'
                            '${alert['contact_name'] ?? 'Emergency contact'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${alert['status']} · ${alert['triggered_at']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.kyr.muted,
                            ),
                          ),
                          if (alert['station_name'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Station: ${alert['station_name']}'),
                          ],
                          const SizedBox(height: 8),
                          ...(alert['deliveries'] as List? ?? []).map(
                            (delivery) => Text(
                              '${delivery['channel']}: ${delivery['status']} '
                              '(${delivery['attempts']} attempt'
                              '${delivery['attempts'] == 1 ? '' : 's'})',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.kyr.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _armSafeWalk() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Start Safe Walk',
                style: serifStyle(size: 24, color: context.kyr.ink),
              ),
              const SizedBox(height: 7),
              Text(
                'If you do not check in before the timer ends, the server will '
                'alert all verified contacts—even if this phone is offline.',
                style: TextStyle(color: context.kyr.muted, height: 1.4),
              ),
              const SizedBox(height: 15),
              for (final option in const [5, 15, 30, 60])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, option),
                    child: Text('$option minutes'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null) return;
    final result = await _accounts.armCheckIn(
      minutes,
      stationName: _station.text.trim().isEmpty ? null : _station.text.trim(),
    );
    if (mounted) setState(() => _activeCheckIn = result);
  }

  Future<void> _markSafe() async {
    final id = _activeCheckIn?['id'] as String?;
    if (id == null) return;
    final result = await _accounts.completeCheckIn(id);
    if (mounted) setState(() => _activeCheckIn = result);
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
                : 'Alert ${_contacts.length} verified '
                      '${_contacts.length == 1 ? 'contact' : 'contacts'} after a short safety countdown. The app '
                      'requests your location only when you trigger the alert.',
            style: TextStyle(fontSize: 14.5, color: p.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _station,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Station name (optional)',
              hintText: 'e.g. Area F Police Station',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
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
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.sos,
                      foregroundColor: p.onSos,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _opening
                        ? null
                        : (_contact == null
                              ? _setUpContact
                              : _confirmAutomaticAlert),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(_opening ? 'Sending…' : 'Alert'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.sos,
                      side: BorderSide(color: p.sos.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _opening ? null : _prepareAlert,
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(_opening ? 'Opening…' : 'SMS'),
                  ),
                ),
              ],
            ),
          if (!_loading && _contact == null) ...[
            const SizedBox(height: 10),
            Text(
              'Alert will guide you through connecting an emergency contact. '
              'SMS opens a message you can address yourself.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.35),
            ),
          ],
          if (!_loading && _contact != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _opening ? null : _sendTestAlert,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Send clearly labelled test alert'),
              ),
            ),
          ],
          if (_lastAlert != null) ...[
            const SizedBox(height: 16),
            _AlertStatusCard(
              alert: _lastAlert!,
              busy: _opening,
              onRefresh: _refreshAlert,
              onAction: _updateAlert,
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _opening ? null : _showAlertHistory,
            icon: const Icon(Icons.history_rounded),
            label: const Text('View alert history'),
          ),
          const SizedBox(height: 14),
          AccentSurface(
            accent: p.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: p.green),
                    const SizedBox(width: 9),
                    Text(
                      'Safe Walk timer',
                      style: TextStyle(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _activeCheckIn?['status'] == 'armed'
                      ? 'Armed until ${_activeCheckIn?['due_at']}. Check in before then.'
                      : 'Arm a server-owned timer before entering a risky situation.',
                  style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4),
                ),
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _activeCheckIn?['status'] == 'armed'
                        ? _markSafe
                        : _armSafeWalk,
                    icon: Icon(
                      _activeCheckIn?['status'] == 'armed'
                          ? Icons.check_circle_outline
                          : Icons.timer_outlined,
                    ),
                    label: Text(
                      _activeCheckIn?['status'] == 'armed'
                          ? "I'm safe — stop timer"
                          : 'Start Safe Walk',
                    ),
                  ),
                ),
              ],
            ),
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

class _AlertCountdownSheet extends StatefulWidget {
  final String contactName;
  const _AlertCountdownSheet({required this.contactName});

  @override
  State<_AlertCountdownSheet> createState() => _AlertCountdownSheetState();
}

class _AlertCountdownSheetState extends State<_AlertCountdownSheet> {
  int _seconds = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: p.card.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 42,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Send custody alert?',
              style: serifStyle(size: 25, color: p.ink),
            ),
            const SizedBox(height: 7),
            Text(
              'This will notify your emergency contact and include your current '
              'location when permission is available.',
              style: TextStyle(color: p.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            AccentSurface(
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, color: p.green),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALERT RECIPIENT',
                          style: TextStyle(
                            color: p.faint,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.contactName,
                          style: TextStyle(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.sos,
                      foregroundColor: p.onSos,
                    ),
                    onPressed: _seconds == 0
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(
                      _seconds == 0 ? 'Send alert now' : 'Ready in $_seconds…',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertStatusCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final bool busy;
  final VoidCallback onRefresh;
  final ValueChanged<String> onAction;
  const _AlertStatusCard({
    required this.alert,
    required this.busy,
    required this.onRefresh,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final status = alert['status'] as String? ?? 'queued';
    final delivered = status == 'delivered';
    final failed = status == 'failed';
    final closed = status == 'cancelled' || status == 'resolved';
    final label = switch (status) {
      'queued' => 'Queued for the SMS provider',
      'sent' => 'Accepted by the SMS provider',
      'delivered' => 'Delivery confirmed',
      'failed' => 'Relay failed',
      'cancelled' => 'Alert cancelled',
      'resolved' => 'Marked safe',
      _ => status,
    };
    return AccentSurface(
      accent: delivered
          ? p.green
          : failed
          ? p.sos
          : p.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                delivered
                    ? Icons.check_circle_outline_rounded
                    : failed
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                color: delivered
                    ? p.green
                    : failed
                    ? p.sos
                    : p.goldInk,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Refresh delivery status',
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Text(
            delivered
                ? 'The delivery provider confirmed receipt.'
                : 'Provider acceptance is not the same as confirmed delivery.',
            style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4),
          ),
          if (!closed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (failed)
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => onAction('retry'),
                      child: const Text('Retry relay'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => onAction('cancel'),
                      child: const Text('False alarm'),
                    ),
                  ),
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onAction('resolve'),
                    child: const Text("I'm safe"),
                  ),
                ),
              ],
            ),
          ],
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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  bool _busy = false;
  bool _signInMode = false;
  bool _keepSignedIn = true;
  int _step = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadRememberedSignIn();
  }

  Future<void> _loadRememberedSignIn() async {
    final email = await widget.accounts.rememberedEmail;
    final keepSignedIn = await widget.accounts.keepSignedInPreference;
    if (!mounted) return;
    setState(() {
      if (_email.text.isEmpty && email != null) _email.text = email;
      _keepSignedIn = keepSignedIn;
    });
  }

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
      if (kSupabaseConfigured && emailToken == null) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'kyr_pending_profile',
          jsonEncode({
            'email': email.toLowerCase(),
            'full_name': _fullName.text.trim(),
            'phone': _phone.text.trim(),
            'contact_name': _contactName.text.trim(),
            'contact_phone': _contactPhone.text.trim(),
          }),
        );
        if (mounted) {
          setState(() {
            _signInMode = true;
            _message =
                'Check your email and open the verification link. Then return '
                'here and sign in to finish your safety profile.';
          });
        }
        return;
      }
      if (emailToken != null) {
        await widget.accounts.verifyEmail(emailToken);
      }
      await widget.accounts.login(email, password, keepSignedIn: _keepSignedIn);
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
    } on AuthException catch (error) {
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
      await widget.accounts.login(
        _email.text.trim(),
        _password.text,
        keepSignedIn: _keepSignedIn,
      );
      if (kSupabaseConfigured) {
        final preferences = await SharedPreferences.getInstance();
        final pendingJson = preferences.getString('kyr_pending_profile');
        if (pendingJson != null) {
          final pending = jsonDecode(pendingJson) as Map<String, dynamic>;
          if (pending['email'] == _email.text.trim().toLowerCase()) {
            await widget.accounts.saveProfile(
              pending['full_name'] as String,
              pending['phone'] as String,
            );
            await widget.accounts.addContact(
              pending['contact_name'] as String,
              pending['contact_phone'] as String,
            );
            await preferences.remove('kyr_pending_profile');
          }
        }
      }
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
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    final emailError = _validateField(email, 'Email address', kind: 'email');
    if (emailError != null) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final (message, developmentToken) = await widget.accounts
          .requestPasswordReset(email);
      if (!mounted) return;
      if (developmentToken == null) {
        setState(() => _message = message);
      } else {
        await _showDevelopmentReset(developmentToken);
      }
    } on AccountApiError catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDevelopmentReset(String token) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? dialogError;
    final reset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final p = context.kyr;
          return AlertDialog(
            title: Text(
              'Choose a new password',
              style: serifStyle(size: 22, color: p.ink),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Development mode received the reset link automatically.',
                  style: TextStyle(fontSize: 13, color: p.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    dialogError!,
                    style: TextStyle(fontSize: 12, color: p.sos),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (password.text.length < 12) {
                    setDialogState(
                      () => dialogError = 'Use at least 12 characters.',
                    );
                    return;
                  }
                  if (password.text != confirmation.text) {
                    setDialogState(
                      () => dialogError = 'The passwords do not match.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Reset password'),
              ),
            ],
          );
        },
      ),
    );
    if (reset == true) {
      try {
        await widget.accounts.resetPassword(token, password.text);
        if (mounted) {
          setState(() {
            _password.text = '';
            _message = 'Password reset. Sign in with your new password.';
          });
        }
      } on AccountApiError catch (error) {
        if (mounted) setState(() => _message = error.message);
      }
    }
    password.dispose();
    confirmation.dispose();
  }

  String? _validateField(String? value, String label, {String? kind}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (kind == 'email' && (!text.contains('@') || !text.contains('.'))) {
      return 'Enter a valid email address.';
    }
    if (kind == 'password' && text.length < 12) {
      return 'Use at least 12 characters.';
    }
    if (kind == 'phone' && !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(text)) {
      return 'Enter 8–15 digits, with an optional +.';
    }
    return null;
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
    String? kind,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        textInputAction: TextInputAction.next,
        autofillHints: switch (kind) {
          'email' => const [AutofillHints.email],
          'password' => const [AutofillHints.password],
          'phone' => const [AutofillHints.telephoneNumber],
          _ => const [AutofillHints.name],
        },
        validator: (value) => _validateField(value, label, kind: kind),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _nextStep() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _message = null;
      _step = (_step + 1).clamp(0, 2);
    });
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _signInMode = !_signInMode;
      _step = 0;
      _message = null;
    });
  }

  Widget _registrationFields() {
    return switch (_step) {
      0 => Column(
        key: const ValueKey('account-step'),
        children: [
          _field(
            _email,
            'Email address',
            keyboardType: TextInputType.emailAddress,
            kind: 'email',
          ),
          _field(_password, 'Password', obscure: true, kind: 'password'),
        ],
      ),
      1 => Column(
        key: const ValueKey('profile-step'),
        children: [
          _field(_fullName, 'Full name'),
          _field(
            _phone,
            'Phone number',
            keyboardType: TextInputType.phone,
            kind: 'phone',
          ),
        ],
      ),
      _ => Column(
        key: const ValueKey('contact-step'),
        children: [
          _field(_contactName, 'Emergency contact name'),
          _field(
            _contactPhone,
            'Emergency contact phone',
            keyboardType: TextInputType.phone,
            kind: 'phone',
          ),
        ],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final labels = ['Your account', 'Your details', 'Emergency contact'];
    return Scaffold(
      appBar: widget.appRegistration
          ? null
          : AppBar(title: const Text('Set up Custody Alert')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.paper, p.canvas, p.paper],
          ),
        ),
        child: SafeArea(
          top: widget.appRegistration,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              if (widget.appRegistration) ...[
                Row(
                  children: [
                    const _BrandSeal(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Know Your Rights',
                        style: serifStyle(size: 19, color: p.ink),
                      ),
                    ),
                    const ThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: 26),
              ],
              Text(
                _signInMode ? 'Welcome back' : 'Create your safety profile',
                style: serifStyle(size: 30, color: p.ink, height: 1.1),
              ),
              const SizedBox(height: 7),
              Text(
                _signInMode
                    ? 'Sign in to access your profile and safety tools.'
                    : 'Set up your account in three short steps. Your emergency '
                          'contact must consent before receiving alerts.',
                style: TextStyle(fontSize: 14, color: p.muted, height: 1.45),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.card.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.line),
                  boxShadow: [
                    BoxShadow(
                      color: p.ink.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_signInMode) ...[
                        Row(
                          children: List.generate(
                            3,
                            (index) => Expanded(
                              child: Container(
                                height: 5,
                                margin: EdgeInsets.only(
                                  right: index == 2 ? 0 : 7,
                                ),
                                decoration: BoxDecoration(
                                  color: index <= _step ? p.green : p.line,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'STEP ${_step + 1} OF 3 · ${labels[_step].toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: p.green,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _signInMode
                            ? Column(
                                key: const ValueKey('sign-in'),
                                children: [
                                  _field(
                                    _email,
                                    'Email address',
                                    keyboardType: TextInputType.emailAddress,
                                    kind: 'email',
                                  ),
                                  _field(
                                    _password,
                                    'Password',
                                    obscure: true,
                                    kind: 'password',
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _busy ? null : _forgotPassword,
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  CheckboxListTile(
                                    value: _keepSignedIn,
                                    onChanged: _busy
                                        ? null
                                        : (value) => setState(
                                            () => _keepSignedIn = value ?? true,
                                          ),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      'Keep me signed in',
                                      style: TextStyle(
                                        color: p.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Use only on a device you trust.',
                                      style: TextStyle(
                                        color: p.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _registrationFields(),
                      ),
                      if (_step == 2 && !_signInMode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: Text(
                            'They will receive a confirmation request before '
                            'Custody Alert is enabled.',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (_message != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: p.sosTint,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: p.sosInk,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          if (!_signInMode && _step > 0) ...[
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _step--),
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 9),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : _signInMode
                                  ? () {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        _signIn();
                                      }
                                    }
                                  : _step < 2
                                  ? _nextStep
                                  : () {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        _completeSetup();
                                      }
                                    },
                              child: Text(
                                _busy
                                    ? 'Please wait…'
                                    : _signInMode
                                    ? 'Sign in'
                                    : _step < 2
                                    ? 'Continue'
                                    : 'Create profile',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.appRegistration) ...[
                const SizedBox(height: 11),
                TextButton(
                  onPressed: _busy ? null : _toggleMode,
                  child: Text(
                    _signInMode
                        ? 'Create a new account'
                        : 'Already registered? Sign in',
                  ),
                ),
              ],
            ],
          ),
        ),
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
    final verified = repo.obligations
        .where((item) => item.status == 'verified')
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Company', style: serifStyle(size: 20, color: p.ink)),
        actions: const [ThemeToggleButton(), SizedBox(width: 6)],
      ),
      body: _GlassBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.green, p.greenDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: p.greenDeep.withValues(alpha: 0.24),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business_outlined, color: p.onGreen, size: 27),
                  const SizedBox(height: 18),
                  Text(
                    'COMPANY COMPLIANCE DESK',
                    style: TextStyle(
                      color: p.onGreen.withValues(alpha: 0.82),
                      fontSize: 10.5,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Stay on top of your\ncompany obligations.',
                    style: serifStyle(size: 28, color: p.onGreen, height: 1.08),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'Practical, source-grounded guidance built around CAMA '
                    'requirements for Nigerian companies.',
                    style: TextStyle(
                      color: p.onGreen.withValues(alpha: 0.78),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _CompanyMetric(
                        value: '${repo.obligations.length}',
                        label: 'Obligations',
                      ),
                      const SizedBox(width: 9),
                      _CompanyMetric(
                        value: '${repo.companyChecklists.length}',
                        label: 'Checklists',
                      ),
                      const SizedBox(width: 9),
                      _CompanyMetric(value: '$verified', label: 'Verified'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            KyrCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CompanyAskScreen(repo: repo)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.greenTint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: p.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask the company-law assistant',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Get an answer grounded in reviewed material',
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: p.green, size: 19),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: SectionLabel('Key obligations')),
                Text(
                  '${repo.obligations.length} items',
                  style: TextStyle(fontSize: 12, color: p.faint),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (repo.obligations.isEmpty)
              KyrCard(
                child: Text(
                  'No company obligations are available in this content pack.',
                  style: TextStyle(color: p.muted),
                ),
              )
            else
              ...repo.obligations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KyrCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ObligationDetailScreen(obligation: item),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: p.greenTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            color: p.green,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 7,
                                runSpacing: 5,
                                children: [
                                  CategoryTag(item.category),
                                  if (item.status == 'verified')
                                    const VerifiedBadge(),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                style: serifStyle(
                                  size: 17.5,
                                  color: p.ink,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: p.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.faint),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const SectionLabel('Practical checklists'),
            const SizedBox(height: 8),
            ...repo.companyChecklists.map(
              (checklist) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KyrCard(
                  accent: p.green,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              checklist.title,
                              style: serifStyle(
                                size: 18,
                                color: p.ink,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.greenTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${checklist.items.length} steps',
                              style: TextStyle(
                                fontSize: 11,
                                color: p.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        checklist.description,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: p.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...checklist.items
                          .take(4)
                          .map(
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
            ),
            const SizedBox(height: 6),
            Text(
              'Company-law information is general guidance. Confirm filing '
              'requirements and deadlines with CAC or a qualified adviser.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: p.faint, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyMetric extends StatelessWidget {
  final String value;
  final String label;
  const _CompanyMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Text(value, style: serifStyle(size: 19, color: p.onGreen)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: p.onGreen.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      ),
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
  String? _area;

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final searched = _query.trim().isEmpty
        ? widget.repo.cases
        : widget.repo.searchCases(_query);
    final areas = widget.repo.cases
        .map((item) => item.areaOfLaw)
        .toSet()
        .take(4)
        .toList();
    final cases = _area == null
        ? searched
        : searched.where((item) => item.areaOfLaw == _area).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student library',
          style: serifStyle(size: 20, color: p.ink),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 6)],
      ),
      body: _GlassBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.green, p.greenDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: p.greenDeep.withValues(alpha: 0.24),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.school_outlined, color: p.onGreen, size: 26),
                  const SizedBox(height: 18),
                  Text(
                    'CASE-LAW STUDY DESK',
                    style: TextStyle(
                      color: p.onGreen.withValues(alpha: 0.82),
                      fontSize: 10.5,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Understand the case,\nnot just the citation.',
                    style: serifStyle(size: 28, color: p.onGreen, height: 1.08),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    '${widget.repo.cases.length} educational digests with '
                    'facts, issues, holdings, ratios, and study notes.',
                    style: TextStyle(
                      color: p.onGreen.withValues(alpha: 0.78),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            KyrCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentAskScreen(repo: widget.repo),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.greenTint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: p.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask the case-law assistant',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Get an answer grounded in verified digests',
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
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
            if (areas.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All cases'),
                      selected: _area == null,
                      onSelected: (_) => setState(() => _area = null),
                    ),
                    for (final area in areas) ...[
                      const SizedBox(width: 7),
                      ChoiceChip(
                        label: Text(CategoryTag.prettify(area)),
                        selected: _area == area,
                        onSelected: (_) => setState(() => _area = area),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: SectionLabel('Case digests')),
                Text(
                  '${cases.length} ${cases.length == 1 ? 'case' : 'cases'}',
                  style: TextStyle(fontSize: 12, color: p.faint),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (cases.isEmpty)
              KyrCard(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, color: p.faint, size: 30),
                    const SizedBox(height: 9),
                    Text(
                      'No matching cases',
                      style: serifStyle(size: 18, color: p.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try a party name, court, legal issue, or holding.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                  ],
                ),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: p.greenTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.gavel_rounded,
                                size: 17,
                                color: p.green,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.year}',
                                style: monoStyle(
                                  size: 10.5,
                                  color: p.green,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 7,
                                runSpacing: 5,
                                children: [
                                  CategoryTag(item.areaOfLaw),
                                  if (item.status == 'verified')
                                    const VerifiedBadge(),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                style: serifStyle(
                                  size: 17.5,
                                  color: p.ink,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.court,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.faint,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: p.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: p.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Educational summaries are not substitutes for licensed law '
              'reports or legal advice.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: p.faint, height: 1.4),
            ),
          ],
        ),
      ),
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
          Text('Ask about case law', style: serifStyle(size: 24, color: p.ink)),
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

class DirectoryScreen extends StatefulWidget {
  final ContentRepository repo;
  const DirectoryScreen({required this.repo, super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  String _query = '';
  String? _type;

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
    final emergency = widget.repo.directory
        .where((entry) => entry.entryType == 'emergency')
        .toList();
    final entries = widget.repo.directory.where((entry) {
      if (entry.entryType == 'emergency') return false;
      if (_type != null && entry.entryType != _type) return false;
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          entry.name.toLowerCase().contains(query) ||
          (entry.state?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Get help', style: serifStyle(size: 20, color: p.ink)),
        actions: const [ThemeToggleButton(), SizedBox(width: 6)],
      ),
      body: _GlassBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.sos, p.sosDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: p.sos.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.emergency_outlined, color: p.onSos, size: 27),
                  const SizedBox(height: 17),
                  Text(
                    'IMMEDIATE DANGER',
                    style: TextStyle(
                      color: p.onSos.withValues(alpha: 0.82),
                      fontSize: 10.5,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Get urgent help now.',
                    style: serifStyle(size: 28, color: p.onSos),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Move somewhere safer if you can. Calling may not be safe '
                    'in every situation—use your judgment.',
                    style: TextStyle(
                      color: p.onSos.withValues(alpha: 0.8),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  if (emergency.isNotEmpty &&
                      emergency.first.phone != null) ...[
                    const SizedBox(height: 17),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.onSos,
                          foregroundColor: p.sosDeep,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _launch(
                          context,
                          dialNumber(emergency.first.phone),
                          'Could not open the phone app.',
                        ),
                        icon: const Icon(Icons.call_rounded, size: 19),
                        label: Text(
                          'Call ${emergency.first.phone}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 19),
            Text(
              'Legal and support directory',
              style: serifStyle(size: 23, color: p.ink),
            ),
            const SizedBox(height: 5),
            Text(
              'Find free legal aid and trusted rights organisations.',
              style: TextStyle(fontSize: 13.5, color: p.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search organisation or state',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 11),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All support'),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  const SizedBox(width: 7),
                  ChoiceChip(
                    label: const Text('Legal aid'),
                    selected: _type == 'legal_aid',
                    onSelected: (_) => setState(() => _type = 'legal_aid'),
                  ),
                  const SizedBox(width: 7),
                  ChoiceChip(
                    label: const Text('Rights groups'),
                    selected: _type == 'ngo',
                    onSelected: (_) => setState(() => _type = 'ngo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                const Expanded(child: SectionLabel('Available support')),
                Text(
                  '${entries.length} ${entries.length == 1 ? 'result' : 'results'}',
                  style: TextStyle(fontSize: 12, color: p.faint),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (entries.isEmpty)
              KyrCard(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 30, color: p.faint),
                    const SizedBox(height: 9),
                    Text(
                      'No matching support found',
                      style: serifStyle(size: 18, color: p.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try another organisation name or clear the filter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              )
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KyrCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                color: p.greenTint,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                entry.entryType == 'legal_aid'
                                    ? Icons.balance_rounded
                                    : Icons.volunteer_activism_outlined,
                                color: p.green,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.name,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                      color: p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${entry.entryType == 'legal_aid' ? 'Legal aid' : 'Rights organisation'}'
                                    '${entry.state != null ? ' · ${entry.state}' : ' · Nationwide'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (entry.phone != null || entry.url != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (entry.phone != null)
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _launch(
                                      context,
                                      dialNumber(entry.phone),
                                      'Could not open the phone app.',
                                    ),
                                    icon: const Icon(
                                      Icons.call_outlined,
                                      size: 17,
                                    ),
                                    label: const Text('Call'),
                                  ),
                                ),
                              if (entry.phone != null && entry.url != null)
                                const SizedBox(width: 8),
                              if (entry.url != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _launch(
                                      context,
                                      openLink(entry.url!),
                                      'Could not open the link.',
                                    ),
                                    icon: const Icon(
                                      Icons.language_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Website'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 7),
            Text(
              'Directory details may change. If a number does not connect, '
              'use the organisation’s official website to confirm it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: p.faint, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
