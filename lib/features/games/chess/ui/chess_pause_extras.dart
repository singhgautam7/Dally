import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import 'chess_pieces.dart';

/// The preview handed to the shared [showStylePicker] — the existing piece
/// artwork, unchanged. The picker shell itself is now
/// `core/widgets/style_picker_sheet.dart`, shared with every other game.
Widget chessStylePreview(BuildContext context, String groupId, String styleId) => PieceGlyph(
      piece: const Piece(color: Side.white, role: Role.knight),
      style: pieceStyleFromId(styleId),
      size: 36,
    );
