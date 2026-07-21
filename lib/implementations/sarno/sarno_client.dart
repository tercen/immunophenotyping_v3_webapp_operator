import 'dart:convert';
import 'package:http/http.dart' as http;

/// Connection + scope for talking to a Sarno board. In a served app these come
/// from the injected `sarno-*` meta tags via [configFromMetaTags]
/// (`bootstrap.dart`); in dev/tests construct one directly.
class SarnoConfig {
  final String boardUrl;
  final String token;
  final String? projectId;
  final String branch;

  const SarnoConfig({
    required this.boardUrl,
    required this.token,
    this.projectId,
    this.branch = 'main',
  });

  String get base => boardUrl.endsWith('/')
      ? boardUrl.substring(0, boardUrl.length - 1)
      : boardUrl;

  /// The username this capability token authenticates as, parsed from the
  /// token payload (`user` claim). Capability tokens are `<payload>.<sig>`;
  /// the payload is base64url JSON. Falls back to `null` if unparseable.
  String? get username {
    try {
      final part = token.split('.').first;
      final norm = base64Url.normalize(part);
      final claims = jsonDecode(utf8.decode(base64Url.decode(norm)));
      final u = (claims is Map) ? claims['user'] : null;
      return (u is String && u.isNotEmpty) ? u : null;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'SarnoConfig(board: $base, project: $projectId, branch: $branch)';
}

/// A tool-level error from the board `/mcp` endpoint.
class McpException implements Exception {
  final int code;
  final String message;
  McpException(this.code, this.message);
  @override
  String toString() => 'McpException($code): $message';
}

/// Sarno board client: REST `/api/*` for CRUD + JSON-RPC `/mcp` for compute and
/// data. Both authenticate with the same capability (Bearer) token — the
/// `sarno-board-token` the board injects into a served app.
class SarnoClient {
  final SarnoConfig config;
  final http.Client _http;
  int _id = 0;

  SarnoClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Map<String, String> get _authHeader =>
      {'authorization': 'Bearer ${config.token}'};

  // ---- /mcp JSON-RPC (compute + branch data) ----

  /// Call an MCP tool; unwraps the board's `result.content[0].text` JSON
  /// envelope. Throws [McpException] on a JSON-RPC error or a tool `isError`.
  Future<dynamic> mcp(String name, Map<String, dynamic> arguments) async {
    final resp = await _http.post(
      Uri.parse('${config.base}/mcp'),
      headers: {..._authHeader, 'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': ++_id,
        'method': 'tools/call',
        'params': {'name': name, 'arguments': arguments},
      }),
    );
    if (resp.statusCode != 200) {
      throw McpException(resp.statusCode, 'HTTP ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(resp.body);
    final error = (body is Map) ? body['error'] : null;
    if (error is Map) {
      throw McpException((error['code'] as num?)?.toInt() ?? -1,
          error['message']?.toString() ?? 'unknown /mcp error');
    }
    final result = (body as Map)['result'];
    if (result is Map && result['isError'] == true) {
      final txt = (result['content'] as List?)?.first?['text']?.toString() ?? '';
      throw McpException(-1, txt);
    }
    if (result is Map && result['content'] is List) {
      final content = result['content'] as List;
      if (content.isNotEmpty &&
          content.first is Map &&
          (content.first as Map)['text'] != null) {
        final text = (content.first as Map)['text'] as String;
        try {
          return jsonDecode(text);
        } catch (_) {
          return text;
        }
      }
    }
    return result;
  }

  // ---- REST /api/* (CRUD) ----

  Future<dynamic> _restGet(String path) async {
    final resp = await _http.get(Uri.parse('${config.base}$path'),
        headers: _authHeader);
    if (resp.statusCode >= 400) {
      throw McpException(resp.statusCode, 'GET $path -> ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  Future<dynamic> _restPostJson(String path, Map<String, dynamic> body) async {
    final resp = await _http.post(Uri.parse('${config.base}$path'),
        headers: {..._authHeader, 'content-type': 'application/json'},
        body: jsonEncode(body));
    if (resp.statusCode >= 400) {
      throw McpException(resp.statusCode, 'POST $path -> ${resp.body}');
    }
    return jsonDecode(resp.body);
  }

  /// List org slugs the user can see (used as "teams" in the UI).
  Future<List<String>> listOrgs() async {
    final data = await _restGet('/api/orgs');
    final items = (data is Map ? (data['data'] ?? data['orgs'] ?? data['items']) : data);
    if (items is! List) return const [];
    return items
        .map((o) => (o is Map ? (o['slug'] ?? o['name']) : o)?.toString())
        .whereType<String>()
        .toList();
  }

  /// Create a project. `owner` is `user:<sub>` or `org:<slug>`. Returns its id.
  Future<String> createProject(
      {required String owner, required String slug, String? displayName}) async {
    final data = await _restPostJson('/api/projects', {
      'owner': owner,
      'slug': slug,
      if (displayName != null) 'display_name': displayName,
    });
    final obj = (data is Map && data['data'] is Map) ? data['data'] : data;
    final id = (obj is Map) ? (obj['id'] ?? obj['project_id']) : null;
    if (id == null) throw McpException(-1, 'createProject: no id in $data');
    return id.toString();
  }

  /// Multipart-upload raw bytes to a project. Returns the created document id.
  Future<String> uploadFile(
      String projectId, String filename, List<int> bytes) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('${config.base}/api/projects/$projectId/upload'))
      ..headers.addAll(_authHeader)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await _http.send(req);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 400) {
      throw McpException(resp.statusCode, 'upload -> ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    final obj = (data is Map && data['data'] is Map) ? data['data'] : data;
    final id = (obj is Map) ? obj['id'] : null;
    if (id == null) throw McpException(-1, 'uploadFile: no id in $data');
    return id.toString();
  }

  void close() => _http.close();
}
