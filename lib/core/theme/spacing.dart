import 'package:flutter/widgets.dart';

/// The 8pt spacing scale and radii from `Dally Foundations.dc.html`.
/// No widget may use a raw numeric `EdgeInsets`/`SizedBox` — spacing comes from
/// here so the grid stays consistent.
class Insets {
  Insets._();

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;

  /// Boards keep at least [s5] of margin from the screen edge.
  static const double boardMargin = s5;
}

/// Corner radii. `containers 14 · cells 9 · chips/toggles 999`.
class Radii {
  Radii._();

  static const double container = 14;
  static const double cell = 9;
  static const double pill = 999;

  static const Radius containerR = Radius.circular(container);
  static const Radius cellR = Radius.circular(cell);
  static const Radius pillR = Radius.circular(pill);

  static const BorderRadius containerBR = BorderRadius.all(containerR);
  static const BorderRadius cellBR = BorderRadius.all(cellR);
  static const BorderRadius pillBR = BorderRadius.all(pillR);
}

/// Convenience gap widgets so layouts stay token-driven and `const`.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key}) : _horizontal = false;
  const Gap.h(this.size, {super.key}) : _horizontal = true;

  final double size;
  final bool _horizontal;

  @override
  Widget build(BuildContext context) =>
      _horizontal ? SizedBox(width: size) : SizedBox(height: size);
}
