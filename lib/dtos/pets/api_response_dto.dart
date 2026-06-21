class ApiResponseDto<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponseDto({required this.success, this.message, this.data});
}
