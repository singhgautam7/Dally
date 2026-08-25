import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'word_list.dart';

/// The bundled word data, loaded once and shared by every Word game. Reading
/// two text assets is fast but not free, so it is cached for the app's life
/// rather than re-read per round.
final wordListProvider = FutureProvider<WordList>((ref) => WordList.load());
