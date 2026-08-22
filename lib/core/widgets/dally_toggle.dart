import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/motion.dart';
import '../theme/type_scale.dart';

/// A labelled on/off row: title + optional subtitle on the left, a pill switch
/// on the right. On = accent track with an onAccent knob; off = surfaceAlt track
/// with a faint knob.
class DallyToggle extends StatelessWidget {
  const DallyToggle({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: DallyType.bodyStrong.copyWith(color: t.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Switch(value: value, tokens: t),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.tokens});
  final bool value;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final reduce = reduceMotionOf(context);
    return AnimatedContainer(
      duration: reduce ? Duration.zero : Motion.quick,
      curve: Motion.curve,
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? t.accent : t.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: value ? null : Border.all(color: t.border),
      ),
      child: AnimatedAlign(
        duration: reduce ? Duration.zero : Motion.quick,
        curve: Motion.curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: value ? 22 : 20,
          height: value ? 22 : 20,
          decoration: BoxDecoration(
            color: value ? t.onAccent : t.textFaint,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
