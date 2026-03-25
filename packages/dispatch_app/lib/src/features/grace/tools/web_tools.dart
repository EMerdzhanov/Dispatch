import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';

List<GraceToolEntry> webTools() => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'web_fetch',
          description:
              'Fetch a URL and return its content. '
              'Only http:// and https:// schemes are allowed.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL to fetch.',
              },
              'method': {
                'type': 'string',
                'description':
                    'HTTP method (GET, POST, PUT, DELETE, etc.). Defaults to GET.',
              },
              'headers': {
                'type': 'object',
                'description': 'Custom HTTP headers as key-value pairs.',
                'additionalProperties': {'type': 'string'},
              },
              'body': {
                'type': 'string',
                'description': 'Request body for POST/PUT requests.',
              },
            },
            'required': ['url'],
          },
        ),
        handler: _webFetch,
        timeout: const Duration(seconds: 20),
      ),
    ];

Future<Map<String, dynamic>> _webFetch(
    Ref ref, Map<String, dynamic> params) async {
  final urlString = params['url'] as String? ?? '';
  final method =
      (params['method'] as String?)?.toUpperCase() ?? 'GET';
  final customHeaders = params['headers'] as Map<String, dynamic>?;
  final body = params['body'] as String?;

  // Parse and validate URL
  final Uri uri;
  try {
    uri = Uri.parse(urlString);
  } catch (e) {
    return {'error': 'Invalid URL: $e'};
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return {
      'error':
          'Only http:// and https:// schemes are allowed. Got: ${uri.scheme}://',
    };
  }

  const maxBody = 20000;

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.openUrl(method, uri);

    // Apply custom headers
    if (customHeaders != null) {
      for (final entry in customHeaders.entries) {
        request.headers.set(entry.key, entry.value.toString());
      }
    }

    // Write body if provided
    if (body != null && body.isNotEmpty) {
      final bodyBytes = utf8.encode(body);
      request.headers.contentLength = bodyBytes.length;
      request.add(bodyBytes);
    }

    final response =
        await request.close().timeout(const Duration(seconds: 15));

    final responseBody =
        await response.transform(utf8.decoder).join().timeout(
              const Duration(seconds: 15),
            );

    final truncated = responseBody.length > maxBody;
    final content =
        truncated ? responseBody.substring(0, maxBody) : responseBody;

    final contentType = response.headers.contentType?.toString() ?? 'unknown';

    return {
      'status_code': response.statusCode,
      'content_type': contentType,
      'body': content,
      'truncated': truncated,
    };
  } on SocketException catch (e) {
    return {'error': 'Connection failed: $e'};
  } on HttpException catch (e) {
    return {'error': 'HTTP error: $e'};
  } on TimeoutException {
    return {'error': 'Request timed out after 15 seconds'};
  } catch (e) {
    return {'error': 'Fetch failed: $e'};
  } finally {
    client.close();
  }
}
