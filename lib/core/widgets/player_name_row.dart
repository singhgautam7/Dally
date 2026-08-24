import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// One numbered name field with a remove control — the row Mafia's player list
/// is built from, and the same row Bottle Spinner's setup uses under a
/// different header.
class PlayerNameRow extends StatelessWidget {
  const PlayerNameRow({
    super.key,
    required this.index,
    required this.controller,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    this.hintPrefix = 'Player',
  });

  final int index;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final String hintPrefix;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.s2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('${index + 1}',
                style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.words,
              maxLength: 16,
              style: DallyType.body.copyWith(fontSize: 16, color: t.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: '$hintPrefix ${index + 1}',
                hintStyle: DallyType.body.copyWith(fontSize: 16, color: t.textFaint),
                filled: true,
                fillColor: t.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (canRemove)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, size: 18, color: t.textFaint),
              splashRadius: 18,
            ),
        ],
      ),
    );
  }
}
