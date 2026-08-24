import '../../../../core/util/dally_random.dart';

/// Picking needs at least two options; below that the button is disabled and an
/// empty state says so.
const int minChoices = 2;

/// Picks one option, or null when there aren't enough to choose between.
int? pickChoice(DallyRandom rng, List<String> options) =>
    options.length < minChoices ? null : rng.nextInt(options.length);
