import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';

/// The one bottom sheet in the app.
///
/// Every sheet Dally raises — pause, exit confirm, how-to, style picker, theme
/// difficulty, filters, the storage-error sheet — wears the same chrome, so
/// this is the only place it is spelled out. The hairline border is not
/// decoration: on AMOLED the sheet's fill is the same black as the screen
/// behind it, and without the edge there is no sheet.
Future<T?> showDallySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  final t = context.tokens;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: t.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: t.border),
    ),
    builder: builder,
  );
}
