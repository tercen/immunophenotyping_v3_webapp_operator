import 'package:web/web.dart' as web;
import 'sarno_client.dart';

/// Reads the board-injected `<meta name="sarno-*">` tags. Returns null when the
/// required tags are absent (app not served by a Sarno board).
SarnoConfig? readSarnoMetaTags() {
  String? meta(String name) =>
      web.document.querySelector('meta[name="$name"]')?.getAttribute('content');

  final url = meta('sarno-board-url');
  final token = meta('sarno-board-token');
  if (url == null || url.isEmpty || token == null || token.isEmpty) {
    return null;
  }
  final pid = meta('sarno-project-id');
  final branch = meta('sarno-branch');
  return SarnoConfig(
    boardUrl: url,
    token: token,
    projectId: (pid == null || pid.isEmpty) ? null : pid,
    branch: (branch == null || branch.isEmpty) ? 'main' : branch,
  );
}
