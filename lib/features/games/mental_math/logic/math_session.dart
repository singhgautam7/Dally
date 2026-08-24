/// A question the player got wrong, kept for the summary screen — the wrong
/// answer struck through with the right one beside it.
class MissedQuestion {
  const MissedQuestion({
    required this.prompt,
    required this.given,
    required this.correct,
    this.note,
  });

  final String prompt;
  final String given;
  final String correct;

  /// Sequence names the rule it was testing; the others leave this null.
  final String? note;
}

/// How a drill decides it is over. A round always ends by itself.
sealed class SessionLimit {
  const SessionLimit();
}

/// Fixed number of questions.
class QuestionLimit extends SessionLimit {
  const QuestionLimit(this.questions);
  final int questions;
}

/// Fixed wall time. The clock is paused whenever the app leaves the foreground,
/// so a backgrounded phone can never eat someone's 60 seconds.
class TimeLimit extends SessionLimit {
  const TimeLimit(this.seconds);
  final int seconds;
}

/// The running state of one Mental Math round, shared by all six drills.
/// Pure — it holds no clock of its own; the screen feeds it elapsed seconds.
class MathSession {
  MathSession({required this.limit});

  final SessionLimit limit;

  int asked = 0;
  int correct = 0;
  int streak = 0;
  int bestStreak = 0;
  int _elapsed = 0;
  final List<MissedQuestion> missed = [];

  /// Total answering time in milliseconds, for the average-response metric.
  int _responseMillis = 0;

  int get elapsedSeconds => _elapsed;

  int get wrong => asked - correct;

  /// `0.0 … 1.0`, or null before the first answer — never render a zero for
  /// something unearned.
  double? get accuracy => asked == 0 ? null : correct / asked;

  /// Mean response time in ms, or null before the first answer.
  double? get averageResponseMillis =>
      asked == 0 ? null : _responseMillis / asked;

  bool get isOver => switch (limit) {
        QuestionLimit(:final questions) => asked >= questions,
        TimeLimit(:final seconds) => _elapsed >= seconds,
      };

  /// How far through the round, `0.0 … 1.0`, for the progress bar.
  double get progress => switch (limit) {
        QuestionLimit(:final questions) => (asked / questions).clamp(0.0, 1.0),
        TimeLimit(:final seconds) => (_elapsed / seconds).clamp(0.0, 1.0),
      };

  /// Remaining seconds under a [TimeLimit], else null.
  int? get secondsLeft => switch (limit) {
        TimeLimit(:final seconds) => (seconds - _elapsed).clamp(0, seconds),
        QuestionLimit() => null,
      };

  void tick() => _elapsed++;

  /// Adopts the screen's clock, which pauses whenever the app is backgrounded —
  /// so a phone left face-down never eats someone's 60 seconds.
  void setElapsed(int seconds) => _elapsed = seconds < 0 ? 0 : seconds;

  /// Records one answer. A wrong answer costs the streak, never time.
  void answer({
    required bool wasCorrect,
    required int responseMillis,
    MissedQuestion? miss,
  }) {
    asked++;
    _responseMillis += responseMillis;
    if (wasCorrect) {
      correct++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
      if (miss != null) missed.add(miss);
    }
  }
}
