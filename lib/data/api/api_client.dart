import 'package:dio/dio.dart';

import '../models/index.dart';

class ApiException implements Exception {
  final String message;
  final String code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.details,
  });

  factory ApiException.fromResponse(Map<String, dynamic> json, int? statusCode) {
    return ApiException(
      message: json['error'] as String? ?? 'Request failed',
      code: json['code'] as String? ?? 'UNKNOWN',
      statusCode: statusCode,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  factory ApiException.network(String message) {
    return ApiException(message: message, code: 'NETWORK_ERROR');
  }

  @override
  String toString() => '$code: $message';
}

// Auth and token refresh are delegated to callbacks supplied by the app so this
// class stays free of Riverpod and storage concerns.
class ApiClient {
  ApiClient({
    required this._getBaseUrl,
    required this._getAccessToken,
    required this._onUnauthorized,
    required this._onAuthFailure,
  }) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = _getBaseUrl();
          final token = _getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: _onError,
      ),
    );
  }

  final String Function() _getBaseUrl;
  final String? Function() _getAccessToken;
  final Future<bool> Function() _onUnauthorized;
  final void Function() _onAuthFailure;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final shouldRetry = status == 401 &&
        err.requestOptions.extra['_retried'] != true &&
        err.requestOptions.extra['_noAuthRetry'] != true;
    if (shouldRetry) {
      err.requestOptions.extra['_retried'] = true;
      final refreshed = await _onUnauthorized();
      if (refreshed) {
        try {
          final response = await _retry(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          // fall through to failure handling below
        }
      }
      _onAuthFailure();
    }

    if (err.response != null) {
      ApiError? apiError;
      try {
        apiError = ApiError.fromJson(err.response!.data as Map<String, dynamic>);
      } catch (_) {
        apiError = null;
      }
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          error: apiError != null
              ? ApiException(
                  message: apiError.error,
                  code: apiError.code,
                  statusCode: status,
                  details: apiError.details,
                )
              : ApiException(
                  message: err.message ?? 'Request failed',
                  code: 'HTTP_$status',
                  statusCode: status,
                ),
        ),
      );
    }

    return handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: ApiException.network(err.message ?? 'Network error'),
      ),
    );
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = _getAccessToken();
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: {
          ...requestOptions.headers,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  // Runs a request and normalises errors. The interceptor rejects with a
  // DioException that carries an ApiException in its error field, so we unwrap
  // it here to keep ApiException as the public failure contract.
  Future<T> _run<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) decode,
  ) async {
    try {
      final response = await request();
      return decode(response.data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.network(e.message ?? 'Network error');
    }
  }

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic) fromJsonT,
  }) async {
    return _run(() => _dio.get(path, queryParameters: query), fromJsonT);
  }

  Future<T> _post<T>(
    String path, {
    dynamic body,
    required T Function(dynamic) fromJsonT,
  }) async {
    return _run(() => _dio.post(path, data: body), fromJsonT);
  }

  // Auth

  Future<AuthResponse> login(LoginRequest request) async {
    final data = await _post<dynamic>(
      '/auth/login',
      body: request.toJson(),
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<AuthResponse>.fromJson(
      data as Map<String, dynamic>,
      (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  Future<RegisterResponse> register(RegisterRequest request) async {
    final data = await _post<dynamic>(
      '/auth/register',
      body: request.toJson(),
      fromJsonT: (json) => json,
    );
    final json = data as Map<String, dynamic>;
    final payload = json['data'] as Map<String, dynamic>? ?? json;
    return RegisterResponse.fromJson(payload);
  }

  Future<void> logout() async {
    await _run(() => _dio.post('/auth/logout'), (_) => null);
  }

  // Used by the auth notifier to refresh the session; performs no auth header.
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final data = await _run(
      () => _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'_noAuthRetry': true}),
      ),
      (json) => json,
    );
    final wrapped = ApiResponse<AuthResponse>.fromJson(
      data as Map<String, dynamic>,
      (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  Future<FullUser> getCurrentUser() async {
    final data = await _get<dynamic>('/users/me', fromJsonT: (json) => json);
    final wrapped = ApiResponse<FullUser>.fromJson(
      data as Map<String, dynamic>,
      (json) => FullUser.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  // Communities

  Future<List<Community>> getMyCommunities() async {
    final data = await _get<dynamic>('/communities', fromJsonT: (json) => json);
    final wrapped = ApiResponse<List<Community>>.fromJson(
      data as Map<String, dynamic>,
      (json) => (json as List)
          .map((item) => Community.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    return wrapped.data;
  }

  // Channels

  Future<List<Channel>> getChannels(String communityId) async {
    final data = await _get<dynamic>(
      '/channels/communities/$communityId/channels',
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<List<Channel>>.fromJson(
      data as Map<String, dynamic>,
      (json) => (json as List)
          .map((item) => Channel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    return wrapped.data;
  }

  // Messages

  Future<List<Message>> getMessages(
    String channelId, {
    int? limit,
    String? before,
    String? after,
  }) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit.toString();
    if (before != null) query['before'] = before;
    if (after != null) query['after'] = after;

    final data = await _get<dynamic>(
      '/messages/channels/$channelId/messages',
      query: query,
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<List<Message>>.fromJson(
      data as Map<String, dynamic>,
      (json) => (json as List)
          .map((item) => Message.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    return wrapped.data;
  }

  Future<Message> sendMessage(String channelId, SendMessageRequest request) async {
    final data = await _post<dynamic>(
      '/messages/channels/$channelId/messages',
      body: request.toJson(),
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<Message>.fromJson(
      data as Map<String, dynamic>,
      (json) => Message.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  Future<Message> editMessage(String messageId, String content) async {
    final data = await _run(
      () => _dio.patch('/messages/$messageId', data: {'content': content}),
      (json) => json,
    );
    final wrapped = ApiResponse<Message>.fromJson(
      data as Map<String, dynamic>,
      (json) => Message.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  Future<void> deleteMessage(String messageId) async {
    await _run(() => _dio.delete('/messages/$messageId'), (_) => null);
  }

  Future<void> markChannelRead(String channelId) async {
    await _run(() => _dio.post('/channels/$channelId/read'), (_) => null);
  }

  Future<UnreadCounts> getChannelUnreadCounts(String communityId) async {
    final data = await _get<dynamic>(
      '/channels/communities/$communityId/unread',
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<UnreadCounts>.fromJson(
      data as Map<String, dynamic>,
      (json) => UnreadCounts.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  // Direct messages

  Future<List<DMConversation>> getDmConversations() async {
    final data = await _get<dynamic>('/dms/conversations', fromJsonT: (json) => json);
    final wrapped = ApiResponse<List<RawDmConversation>>.fromJson(
      data as Map<String, dynamic>,
      (json) => (json as List)
          .map((item) => RawDmConversation.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    return wrapped.data.map(mapDmConversation).toList();
  }

  Future<DMConversation> createDmConversation(String userId) async {
    final data = await _post<dynamic>(
      '/dms/conversations',
      body: {'userId': userId},
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<RawDmConversation>.fromJson(
      data as Map<String, dynamic>,
      (json) => RawDmConversation.fromJson(json as Map<String, dynamic>),
    );
    return mapDmConversation(wrapped.data);
  }

  Future<List<Message>> getDmMessages(
    String conversationId, {
    int? limit,
    String? before,
    String? after,
  }) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit.toString();
    if (before != null) query['before'] = before;
    if (after != null) query['after'] = after;

    final data = await _get<dynamic>(
      '/dms/conversations/$conversationId/messages',
      query: query,
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<List<RawDmMessage>>.fromJson(
      data as Map<String, dynamic>,
      (json) => (json as List)
          .map((item) => RawDmMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    return wrapped.data.map(mapDmMessage).toList();
  }

  Future<Message> sendDmMessage(
    String conversationId,
    String content, {
    String? replyToId,
    List<String>? attachments,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (replyToId != null) body['replyToId'] = replyToId;
    if (attachments != null) body['attachments'] = attachments;
    final data = await _post<dynamic>(
      '/dms/conversations/$conversationId/messages',
      body: body,
      fromJsonT: (json) => json,
    );
    final wrapped = ApiResponse<RawDmMessage>.fromJson(
      data as Map<String, dynamic>,
      (json) => RawDmMessage.fromJson(json as Map<String, dynamic>),
    );
    return mapDmMessage(wrapped.data);
  }

  Future<void> markDmRead(String conversationId) async {
    await _run(
      () => _dio.post('/dms/conversations/$conversationId/read'),
      (_) => null,
    );
  }

  // Notifications

  Future<List<Notification>> getNotifications({
    int? limit,
    String? before,
  }) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit.toString();
    if (before != null) query['before'] = before;

    final data = await _get<dynamic>(
      '/notifications',
      query: query,
      fromJsonT: (json) => json,
    );
    final wrapped = PaginatedResponse<Notification>.fromJson(
      data as Map<String, dynamic>,
      (json) => Notification.fromJson(json as Map<String, dynamic>),
    );
    return wrapped.data;
  }

  Future<void> markNotificationRead(String id) async {
    await _run(
      () => _dio.post('/notifications/$id/read'),
      (_) => null,
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _run(
      () => _dio.post('/notifications/read'),
      (_) => null,
    );
  }

  // Status

  // Probes a backend for reachability. Mirrors the web client, hitting the
  // root /health endpoint (not /api/v1) so it works before auth.
  Future<bool> checkHealth(String baseUrl) async {
    final trimmed = baseUrl.replaceAll(RegExp(r'/+\$'), '');
    try {
      final response = await _dio.get(
        '$trimmed/health',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          extra: {'_noAuthRetry': true},
        ),
      );
      return response.statusCode != null && response.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateStatus(String status) async {
    await _run(
      () => _dio.put('/users/me/status', data: {'status': status}),
      (_) => null,
    );
  }
}
