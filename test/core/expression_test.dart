import 'package:dally/core/util/expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evalExpression', () {
    test('respects × ÷ over + −', () {
      expect(evalExpression('2 + 3 × 4'), 14);
      expect(evalExpression('12 ÷ 4 + 1'), 4);
      expect(evalExpression('2 + 12 ÷ 4'), 5);
    });

    test('parentheses override precedence', () {
      expect(evalExpression('(2 + 3) × 4'), 20);
      expect(evalExpression('((1 + 1))'), 2);
    });

    test('subtraction and division are left-associative', () {
      expect(evalExpression('10 − 3 − 2'), 5);
      expect(evalExpression('100 ÷ 5 ÷ 2'), 10);
    });

    test('exact rationals — no float drift', () {
      expect(evalExpression('1 ÷ 3 × 3'), 1);
      expect(evalExpression('10 ÷ 4'), 2.5);
    });

    test('unary minus', () {
      expect(evalExpression('-5 + 8'), 3);
      expect(evalExpression('3 × -2'), -6);
    });

    test('accepts ASCII operators too', () {
      expect(evalExpression('2 + 3 * 4'), 14);
      expect(evalExpression('8 / 2'), 4);
    });

    test('division by zero is null, not a throw', () {
      expect(evalExpression('4 ÷ 0'), isNull);
      expect(evalExpression('1 ÷ (2 − 2)'), isNull);
    });

    test('malformed input is null', () {
      for (final bad in ['', '2 +', '+ 2', '(2 + 3', '2 3', 'abc', '2 ** 3']) {
        expect(evalExpression(bad), isNull, reason: bad);
      }
    });

    test('evalInteger rejects fractional results', () {
      expect(evalInteger('10 ÷ 4'), isNull);
      expect(evalInteger('10 ÷ 5'), 2);
    });
  });

  group('MathOp.applyExact', () {
    test('division must be exact', () {
      expect(MathOp.divide.applyExact(9, 3), 3);
      expect(MathOp.divide.applyExact(10, 3), isNull);
      expect(MathOp.divide.applyExact(5, 0), isNull);
    });

    test('the other three always apply', () {
      expect(MathOp.add.applyExact(2, 3), 5);
      expect(MathOp.subtract.applyExact(2, 3), -1);
      expect(MathOp.multiply.applyExact(4, 3), 12);
    });
  });
}
