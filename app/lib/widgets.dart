// Shared components of the design system. The trust signals live here: the
// Verified seal and the citation chip are the two objects that carry the
// product's core promise, so they are designed once and reused everywhere.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';
import 'theme.dart';

/// The brass Verified seal. Brass is reserved for this and nothing else.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: p.goldTint,
        border: Border.all(color: p.gold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 13, color: p.goldInk),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: p.goldInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small uppercase category tag. Pass [danger] for emergency contexts.
class CategoryTag extends StatelessWidget {
  final String label;
  final bool danger;
  const CategoryTag(this.label, {this.danger = false, super.key});

  static String prettify(String raw) {
    final words = raw.split('-').map((w) => w == 'and' ? '&' : w).join(' ');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: danger ? p.sosTint : p.greenTint,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        prettify(label).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: danger ? p.sos : p.green,
        ),
      ),
    );
  }
}

/// A constitutional locator, set in monospace so it reads as a precise citation.
class CitationChip extends StatelessWidget {
  final Citation citation;
  final bool withSource;
  const CitationChip(this.citation, {this.withSource = true, super.key});

  static String shortSource(String name) =>
      name.toLowerCase().contains('constitution') ? '1999 Constitution' : name;

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final label = withSource
        ? '${shortSource(citation.sourceName)} · ${citation.locator}'
        : citation.locator;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: p.greenTint,
        border: Border.all(color: p.green.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: monoStyle(size: 11.5, color: p.green)),
    );
  }
}

/// An uppercase section label used to break up long screens.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: context.kyr.faint,
        ),
      ),
    );
  }
}

/// A rounded surface with an optional coloured accent rule down its left edge.
///
/// Flutter cannot paint a `Border` with a non-uniform colour together with a
/// `borderRadius`, so the rule is drawn as a clipped stripe inside a uniformly
/// bordered box rather than as a thicker left `BorderSide`.
class AccentSurface extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  static const double _ruleWidth = 3;

  const AccentSurface({
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(15, 14, 15, 14),
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    final EdgeInsets pad = EdgeInsets.fromLTRB(
      padding.left + (accent != null ? _ruleWidth : 0),
      padding.top,
      padding.right,
      padding.bottom,
    );

    final Widget content = Stack(
      children: [
        Padding(padding: pad, child: child),
        if (accent != null)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _ruleWidth,
            child: ColoredBox(color: accent!),
          ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: p.card.withValues(alpha: 0.76),
              border: Border.all(color: p.line.withValues(alpha: 0.76)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: onTap == null
                ? content
                : Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: onTap, child: content),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Which meaning an [InfoBlock] carries; drives its accent rule colour.
enum BlockKind { rights, dos, donts }

/// A bulleted block with a semantic accent rule: brass for rights, green for
/// what to do, red for what not to do.
class InfoBlock extends StatelessWidget {
  final String title;
  final List<String> items;
  final BlockKind kind;
  const InfoBlock({
    required this.title,
    required this.items,
    required this.kind,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final p = context.kyr;
    final (Color accent, IconData icon) = switch (kind) {
      BlockKind.rights => (p.gold, Icons.diamond_outlined),
      BlockKind.dos => (p.green, Icons.check_rounded),
      BlockKind.donts => (p.sos, Icons.close_rounded),
    };
    final Color iconColor = kind == BlockKind.rights ? p.goldInk : accent;

    return AccentSurface(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: p.faint,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 15, color: iconColor),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 14.5,
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
    );
  }
}

/// A tappable surface card used for topics and scenarios.
class KyrCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accent;
  const KyrCard({required this.child, this.onTap, this.accent, super.key});

  @override
  Widget build(BuildContext context) {
    return AccentSurface(accent: accent, onTap: onTap, child: child);
  }
}

/// A quiet "report an error" affordance for any content or answer surface. Report-
/// an-error is on every content screen and is never gated behind an account.
class ReportErrorButton extends StatelessWidget {
  final String targetType;
  final String targetId;
  const ReportErrorButton({
    required this.targetType,
    required this.targetId,
    super.key,
  });

  Future<void> _open(BuildContext context) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report an error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What looks wrong? Quote the part that seems incorrect if you can. '
              'A reviewer will look at it.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 4000,
              decoration: const InputDecoration(hintText: 'Describe the problem'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (message == null || message.length < 3 || !context.mounted) return;
    final ok = await ContentRepository().reportError(targetType, targetId, message);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Thank you — a reviewer will look at this.' : 'Could not send the report. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kyr;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _open(context),
        icon: Icon(Icons.flag_outlined, size: 16, color: p.faint),
        label: Text(
          'Report an error on this page',
          style: TextStyle(fontSize: 12.5, color: p.faint),
        ),
      ),
    );
  }
}
