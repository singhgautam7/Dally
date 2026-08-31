import 'package:dally/core/game/player_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('player identities', () {
    test('every subset is distinct in both colour and shape', () {
      for (var n = 2; n <= 4; n++) {
        final seats = identitiesFor(n);
        expect(seats, hasLength(n));
        expect(seats.map((s) => s.color).toSet(), hasLength(n),
            reason: '$n seats must not share a colour');
        expect(seats.map((s) => s.shape).toSet(), hasLength(n),
            reason: '$n seats must not share a shape — greyscale must still read');
      }
    });

    test('seat indices are 0..n-1 in order', () {
      for (var n = 2; n <= 4; n++) {
        expect(identitiesFor(n).map((s) => s.index), List.generate(n, (i) => i));
      }
    });

    test('two players avoid the red/green pair', () {
      final two = identitiesFor(2);
      expect(two.map((s) => s.name), ['Coral', 'Cobalt']);
    });

    test('shape mapping is stable per colour across subset sizes', () {
      final byName = <String, PlayerShape>{};
      for (var n = 2; n <= 4; n++) {
        for (final seat in identitiesFor(n)) {
          expect(byName.putIfAbsent(seat.name, () => seat.shape), seat.shape,
              reason: '${seat.name} must keep one shape everywhere');
        }
      }
    });

    test('every shape produces a non-empty path', () {
      for (final shape in PlayerShape.values) {
        final bounds = playerShapePath(shape, const Offset(20, 20), 10).getBounds();
        expect(bounds.width, greaterThan(0));
        expect(bounds.height, greaterThan(0));
      }
    });
  });
}
