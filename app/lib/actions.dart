// One-tap actions for scenarios and the directory: dialing a phone number and
// opening a link. Scenario steps carry a semantic call `value` (e.g.
// "emergency_line") which `callTargetFor` maps to a label and a concrete number
// where one is known. `lawyer`/`trusted_contact` have no stored number in the
// MVP, so they open the phone dialer for the user to place the call.

import 'package:url_launcher/url_launcher.dart';

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
