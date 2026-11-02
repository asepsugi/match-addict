import 'package:match_addict/features/live/live_host_controller.dart';
import 'package:match_addict/features/live/live_view_controller.dart';

/// Live score di HP host dengan keadaan tetap (sheet 12c/12d, menu 12f), tanpa relay.
class ShownLive extends LiveHostController {
  final LiveHost? live;
  ShownLive(this.live);

  @override
  LiveHost? build() => live;
}

/// Halaman penonton dengan keadaan tetap (12h–12o), tanpa mengecek relay.
class Watching extends LiveViewController {
  final LiveView view;
  Watching(this.view);

  @override
  LiveView? build() => view;

  /// Relay menjawab lain di tengah test (mis. live dihentikan).
  void show(LiveView next) => state = next;
}
