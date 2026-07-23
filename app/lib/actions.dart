// One-tap actions for scenarios and the directory: dialing a phone number and
// opening a link. Scenario steps carry a semantic call `value` (e.g.
// "emergency_line") which `callTargetFor` maps to a label and a concrete number
// where one is known. `lawyer`/`trusted_contact` have no stored number in the
// MVP, so they open the phone dialer for the user to place the call.

import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

const String custodyAlertMessage =
    'I am being arrested or held in police custody. Please contact me, find out '
    'where I am being held, and help me reach a lawyer. This alert was prepared '
    'with the Know Your Rights Nigeria app.';

/// A call the UI can offer: a human label and an optional concrete number.
/// A null [number] means "open the dialer" (no stored number to pre-fill).
class CallTarget {
  final String label;
  final String? number;
  const CallTarget(this.label, this.number);
}

/// Map a scenario step's call `value` to what the button should say and dial.
CallTarget callTargetFor(String? value) {
  switch (value) {
    case 'emergency_line':
      return const CallTarget('Call 112 (national emergency)', '112');
    case 'lawyer':
      return const CallTarget('Call your lawyer', null);
    case 'trusted_contact':
      return const CallTarget('Call someone you trust', null);
    default:
      return const CallTarget('Call', null);
  }
}

/// What a scenario step's action should offer the user.
///
/// Steps do not only name the semantic contacts above: some point at a
/// directory entry (by id, e.g. "nhrc", or by type, e.g. "legal_aid") and some
/// carry `action: "link"` with a URL. Those are resolved against the loaded
/// directory so the button dials a real number where one exists, opens the
/// organisation's site where it does not, and never presents a dead control.
class StepActionTarget {
  final String label;
  final String? phone;
  final String? url;
  final bool urgent;

  const StepActionTarget({
    required this.label,
    this.phone,
    this.url,
    this.urgent = false,
  });

  /// True when there is nothing concrete to open, so we fall back to the dialer.
  bool get opensEmptyDialer => phone == null && url == null;
}

DirectoryEntry? _lookup(String value, List<DirectoryEntry> directory) {
  for (final e in directory) {
    if (e.id == value) return e;
  }
  for (final e in directory) {
    if (e.entryType == value) return e;
  }
  return null;
}

/// Resolve a step's `action`/`value` into a concrete, launchable button.
StepActionTarget? resolveStepAction(
  String? action,
  String? value,
  List<DirectoryEntry> directory,
) {
  if (action == null) return null;

  if (action == 'link') {
    if (value == null || value.isEmpty) return null;
    return StepActionTarget(label: 'Open link', url: value);
  }
  if (action != 'call') return null;

  switch (value) {
    case 'emergency_line':
      return const StepActionTarget(
        label: 'Call 112 (national emergency)',
        phone: '112',
        urgent: true,
      );
    case 'lawyer':
      return const StepActionTarget(label: 'Call your lawyer');
    case 'trusted_contact':
      return const StepActionTarget(label: 'Call someone you trust');
  }

  final entry = value == null ? null : _lookup(value, directory);
  if (entry != null) {
    if (entry.phone != null && entry.phone!.isNotEmpty) {
      return StepActionTarget(
        label: 'Call ${entry.name}',
        phone: entry.phone,
        urgent: entry.entryType == 'emergency',
      );
    }
    if (entry.url != null && entry.url!.isNotEmpty) {
      return StepActionTarget(label: 'Open ${entry.name}', url: entry.url);
    }
    return StepActionTarget(label: 'Call ${entry.name}');
  }
  return const StepActionTarget(label: 'Call');
}

/// Launch the phone dialer. With no [number], opens an empty dialer so the user
/// can enter the number themselves. Returns false if no dialer is available.
Future<bool> dialNumber(String? number) {
  final uri = (number == null || number.isEmpty)
      ? Uri(scheme: 'tel')
      : Uri(scheme: 'tel', path: number);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Open a web link in the default browser. Returns false if it cannot be opened.
Future<bool> openLink(String url) {
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Build an SMS composer URI without choosing a recipient or sending anything.
Uri buildCustodyAlertUri({String message = custodyAlertMessage}) {
  return Uri(scheme: 'sms', queryParameters: {'body': message});
}

/// Open the device SMS composer with the custody-alert text pre-filled.
Future<bool> prepareCustodyAlert() {
  return launchUrl(
    buildCustodyAlertUri(),
    mode: LaunchMode.externalApplication,
  );
}
