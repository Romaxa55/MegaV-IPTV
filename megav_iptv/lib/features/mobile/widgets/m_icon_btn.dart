import 'package:flutter/material.dart';

/// Mobile icon-button with optional caption label.
///
/// Used by mobile screens (top bar, hero overlays, player controls) where the
/// touch target must satisfy the 44×44 px Material guideline (Req 7.2).
/// The minimum tap region is enforced via `BoxConstraints(minWidth: 44,
/// minHeight: 44)` so the surrounding [InkWell] hit-tests an area no
/// smaller than the recommendation, even when the visual icon is 24 px.
class MIconBtn extends StatelessWidget {
  const MIconBtn({super.key, required this.icon, this.onTap, this.label});

  final IconData icon;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(label!, style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
