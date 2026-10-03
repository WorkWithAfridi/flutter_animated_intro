/// Animated screen walkthroughs with configurable playback rules.
///
/// Mount an IntroFlow to render the tour, describe its steps with IntroStep,
/// and use IntroTarget wrappers or existing GlobalKeys to locate real widgets.
/// The host app owns controller disposal, localization, and persistent history.
library;

export 'src/controller.dart';
export 'src/flow.dart';
export 'src/history.dart';
export 'src/models.dart';
export 'src/target.dart';
export 'src/auto_play.dart';
