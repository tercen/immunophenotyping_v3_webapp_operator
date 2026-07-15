import 'sarno_client.dart';
import 'bootstrap_stub.dart' if (dart.library.js_interop) 'bootstrap_web.dart';

/// Builds a [SarnoConfig] from the `sarno-*` meta tags the board injects into a
/// served app's index.html. Returns null if the tags are absent (i.e. not
/// being served by a Sarno board), so callers can fall back to another backend.
SarnoConfig? sarnoConfigFromMetaTags() => readSarnoMetaTags();
