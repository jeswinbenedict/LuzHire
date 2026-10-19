import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/content.dart';
import '../../core/shell/destinations.dart';
import '../../core/shell/shell_common.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Frame for /me/* pages: title + scrollable section tabs + content.
class CandidateArea extends StatelessWidget {
  const CandidateArea({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndexFor(candidateDestinations, location);
    return LuzContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My LuzHire', style: context.luzText.h3),
          const SizedBox(height: LuzSpace.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.all(4),
            child: LuzSegmented<String>(
              segments: [
                for (final d in candidateDestinations)
                  (value: d.path, label: d.label, icon: d.icon),
              ],
              selected: selected >= 0
                  ? candidateDestinations[selected].path
                  : '/me',
              onChanged: (path) => context.go(path),
            ),
          ),
          const SizedBox(height: LuzSpace.lg),
          Expanded(child: child),
        ],
      ),
    );
  }
}
