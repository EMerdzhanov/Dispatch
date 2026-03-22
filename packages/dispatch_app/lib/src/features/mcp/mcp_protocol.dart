import 'dart:convert';

/// JSON-RPC 2.0 protocol types for MCP.

class McpRequest {
  final String method;
  final Map<String, dynamic> params;
  final dynamic id;

  McpRequest({required this.method, this.params = const {}, this.id});

  factory McpRequest.fromJson(Map<String, dynamic> json) {
    return McpRequest(
      method: json['method'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
      id: json['id'],
    );
  }
}

class McpResponse {
  final dynamic id;
  final Map<String, dynamic>? result;
  final McpError? error;

  McpResponse({this.id, this.result, this.error});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'jsonrpc': '2.0', 'id': id};
    if (error != null) {
      json['error'] = error!.toJson();
    } else {
      json['result'] = result ?? {};
    }
    return json;
  }

  String toJsonString() => jsonEncode(toJson());

  factory McpResponse.success(dynamic id, Map<String, dynamic> result) =>
      McpResponse(id: id, result: result);

  factory McpResponse.error(dynamic id, int code, String message) =>
      McpResponse(id: id, error: McpError(code: code, message: message));

  factory McpResponse.methodNotFound(dynamic id, String method) =>
      McpResponse.error(id, -32601, 'Method not found: $method');

  factory McpResponse.invalidParams(dynamic id, String message) =>
      McpResponse.error(id, -32602, message);

  factory McpResponse.internalError(dynamic id, String message) =>
      McpResponse.error(id, -32603, message);
}

class McpError {
  final int code;
  final String message;

  McpError({required this.code, required this.message});

  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}

class McpNotification {
  final String method;
  final Map<String, dynamic> params;

  McpNotification({required this.method, required this.params});

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
      };

  String toJsonString() => jsonEncode(toJson());

  String toSseEvent() => 'data: ${toJsonString()}\n\n';
}
