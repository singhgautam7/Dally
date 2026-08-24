/// A tiny, safe arithmetic evaluator shared by every Mental Math game.
///
/// One implementation, so precedence is defined in exactly one place and no
/// game has to parse arithmetic of its own. It handles `+ - × ÷` (in both ASCII
/// and typographic forms), unary minus and parentheses, with the usual
/// precedence: parentheses, then `× ÷`, then `+ −`, left-associative.
///
/// Arithmetic is done over exact rationals, so `1 ÷ 3 × 3` is exactly `1` and a
/// generated puzzle can never be rejected by float drift. Division by zero
/// returns null rather than throwing — a player can type it, and it must show
/// as invalid, not crash.
library;

/// An exact fraction. Kept private to the evaluator; callers see [num].
class _Rational {
  _Rational(this.numerator, this.denominator) {
    assert(denominator != 0);
    if (denominator < 0) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final g = _gcd(numerator.abs(), denominator);
    if (g > 1) {
      numerator ~/= g;
      denominator ~/= g;
    }
  }

  _Rational.whole(int value) : numerator = value, denominator = 1;

  int numerator;
  int denominator;

  bool get isInteger => denominator == 1;

  num get value => isInteger ? numerator : numerator / denominator;

  _Rational operator +(_Rational o) =>
      _Rational(numerator * o.denominator + o.numerator * denominator,
          denominator * o.denominator);

  _Rational operator -(_Rational o) =>
      _Rational(numerator * o.denominator - o.numerator * denominator,
          denominator * o.denominator);

  _Rational operator *(_Rational o) =>
      _Rational(numerator * o.numerator, denominator * o.denominator);

  /// Null on division by zero.
  _Rational? divide(_Rational o) => o.numerator == 0
      ? null
      : _Rational(numerator * o.denominator, denominator * o.numerator);

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }
}

/// The four operators a Mental Math game can offer.
enum MathOp {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const MathOp(this.symbol);
  final String symbol;

  /// Applies the operator, or null when the result isn't defined (÷ 0) or isn't
  /// a whole number — mental-math answers are always integers.
  int? applyExact(int a, int b) => switch (this) {
        MathOp.add => a + b,
        MathOp.subtract => a - b,
        MathOp.multiply => a * b,
        MathOp.divide => (b == 0 || a % b != 0) ? null : a ~/ b,
      };
}

/// Evaluates [source], returning null when it is malformed, incomplete, or
/// divides by zero. Never throws.
num? evalExpression(String source) {
  try {
    final parser = _Parser(source);
    final value = parser._expression();
    if (value == null) return null;
    parser._skipSpace();
    // Trailing junk means the whole thing is invalid, not partially valid.
    return parser._atEnd ? value.value : null;
  } catch (_) {
    return null;
  }
}

/// Evaluates [source] and returns it only when the result is a whole number —
/// the form every Mental Math answer takes.
int? evalInteger(String source) {
  final v = evalExpression(source);
  if (v == null) return null;
  if (v is int) return v;
  return v == v.roundToDouble() ? v.round() : null;
}

class _Parser {
  _Parser(this.source);

  final String source;
  int _pos = 0;

  bool get _atEnd => _pos >= source.length;

  void _skipSpace() {
    while (!_atEnd && source[_pos] == ' ') {
      _pos++;
    }
  }

  String? _peek() {
    _skipSpace();
    return _atEnd ? null : source[_pos];
  }

  /// expression := term (('+' | '−') term)*
  _Rational? _expression() {
    var left = _term();
    if (left == null) return null;
    while (true) {
      final c = _peek();
      if (c == '+' || c == '-' || c == '−') {
        _pos++;
        final right = _term();
        if (right == null) return null;
        left = c == '+' ? left! + right : left! - right;
      } else {
        return left;
      }
    }
  }

  /// term := factor (('×' | '÷') factor)*
  _Rational? _term() {
    var left = _factor();
    if (left == null) return null;
    while (true) {
      final c = _peek();
      if (c == '*' || c == '×' || c == 'x') {
        _pos++;
        final right = _factor();
        if (right == null) return null;
        left = left! * right;
      } else if (c == '/' || c == '÷') {
        _pos++;
        final right = _factor();
        if (right == null) return null;
        final divided = left!.divide(right);
        if (divided == null) return null;
        left = divided;
      } else {
        return left;
      }
    }
  }

  /// factor := '-'? (number | '(' expression ')')
  _Rational? _factor() {
    final c = _peek();
    if (c == null) return null;
    if (c == '-' || c == '−') {
      _pos++;
      final inner = _factor();
      return inner == null ? null : _Rational.whole(0) - inner;
    }
    if (c == '(') {
      _pos++;
      final inner = _expression();
      if (inner == null) return null;
      if (_peek() != ')') return null;
      _pos++;
      return inner;
    }
    return _number();
  }

  _Rational? _number() {
    _skipSpace();
    final start = _pos;
    while (!_atEnd && _isDigit(source[_pos])) {
      _pos++;
    }
    if (_pos == start) return null;
    final digits = int.tryParse(source.substring(start, _pos));
    return digits == null ? null : _Rational.whole(digits);
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}
