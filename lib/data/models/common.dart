class ApiResponse<T> {
  final T data;

  const ApiResponse({required this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse(data: fromJsonT(json['data']));
  }
}

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return PaginatedResponse(
      data: (json['data'] as List).map(fromJsonT).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

class ApiError {
  final String error;
  final String code;
  final Map<String, dynamic>? details;

  const ApiError({
    required this.error,
    required this.code,
    this.details,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      error: json['error'] as String? ?? 'Unknown error',
      code: json['code'] as String? ?? 'UNKNOWN',
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => '$code: $error';
}
