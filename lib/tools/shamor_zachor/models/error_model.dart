import 'package:easy_localization/easy_localization.dart' hide TextDirection;

/// Enumeration of possible error types in Shamor Zachor
enum ShamorZachorErrorType {
  /// Asset file not found
  missingAsset,

  /// JSON parsing error
  parseError,

  /// Local storage not available
  storageUnavailable,

  /// Network error (future use)
  networkError,

  /// Invalid data format
  invalidData,

  /// Permission denied
  permissionDenied,

  /// Unknown error
  unknown,
}

/// Represents an error that occurred in Shamor Zachor
class ShamorZachorError {
  final ShamorZachorErrorType type;
  final String message;
  final String? details;
  final Object? originalError;
  final StackTrace? stackTrace;

  const ShamorZachorError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
    this.stackTrace,
  });

  /// Create an error from an exception
  factory ShamorZachorError.fromException(
    Object exception, {
    StackTrace? stackTrace,
    ShamorZachorErrorType? type,
    String? customMessage,
  }) {
    final errorType = type ?? _inferErrorType(exception);
    final message = customMessage ?? _getDefaultMessage(errorType);

    return ShamorZachorError(
      type: errorType,
      message: message,
      details: exception.toString(),
      originalError: exception,
      stackTrace: stackTrace,
    );
  }

  /// Get user-friendly Hebrew message
  String get userFriendlyMessage {
    switch (type) {
      case ShamorZachorErrorType.missingAsset:
        return 'shamor_zachor.error.missing_asset'.tr();
      case ShamorZachorErrorType.parseError:
        return 'shamor_zachor.error.parse_error'.tr();
      case ShamorZachorErrorType.storageUnavailable:
        return 'shamor_zachor.error.storage_unavailable'.tr();
      case ShamorZachorErrorType.networkError:
        return 'shamor_zachor.error.network_error'.tr();
      case ShamorZachorErrorType.invalidData:
        return 'shamor_zachor.error.invalid_data'.tr();
      case ShamorZachorErrorType.permissionDenied:
        return 'shamor_zachor.error.permission_denied'.tr();
      case ShamorZachorErrorType.unknown:
        return 'shamor_zachor.error.unknown'.tr();
    }
  }

  /// Check if this error is recoverable
  bool get isRecoverable {
    switch (type) {
      case ShamorZachorErrorType.networkError:
      case ShamorZachorErrorType.storageUnavailable:
        return true;
      case ShamorZachorErrorType.missingAsset:
      case ShamorZachorErrorType.parseError:
      case ShamorZachorErrorType.invalidData:
      case ShamorZachorErrorType.permissionDenied:
      case ShamorZachorErrorType.unknown:
        return false;
    }
  }

  /// Get suggested action for the user
  String? get suggestedAction {
    switch (type) {
      case ShamorZachorErrorType.networkError:
        return 'shamor_zachor.error.action_network'.tr();
      case ShamorZachorErrorType.storageUnavailable:
        return 'shamor_zachor.error.action_storage'.tr();
      case ShamorZachorErrorType.missingAsset:
        return 'shamor_zachor.error.action_missing_asset'.tr();
      case ShamorZachorErrorType.parseError:
      case ShamorZachorErrorType.invalidData:
        return 'shamor_zachor.error.action_parse_invalid'.tr();
      case ShamorZachorErrorType.permissionDenied:
        return 'shamor_zachor.error.action_permission'.tr();
      case ShamorZachorErrorType.unknown:
        return 'shamor_zachor.error.action_unknown'.tr();
    }
  }

  @override
  String toString() {
    return 'ShamorZachorError(type: $type, message: $message, details: $details)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShamorZachorError &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message &&
          details == other.details;

  @override
  int get hashCode => type.hashCode ^ message.hashCode ^ details.hashCode;
}

/// Infer error type from exception
ShamorZachorErrorType _inferErrorType(Object exception) {
  final exceptionString = exception.toString().toLowerCase();

  if (exceptionString.contains('asset') || exceptionString.contains('file')) {
    return ShamorZachorErrorType.missingAsset;
  }
  if (exceptionString.contains('json') || exceptionString.contains('format')) {
    return ShamorZachorErrorType.parseError;
  }
  if (exceptionString.contains('storage') ||
      exceptionString.contains('preferences')) {
    return ShamorZachorErrorType.storageUnavailable;
  }
  if (exceptionString.contains('network') ||
      exceptionString.contains('connection')) {
    return ShamorZachorErrorType.networkError;
  }
  if (exceptionString.contains('permission')) {
    return ShamorZachorErrorType.permissionDenied;
  }

  return ShamorZachorErrorType.unknown;
}

/// Get default message for error type
String _getDefaultMessage(ShamorZachorErrorType type) {
  switch (type) {
    case ShamorZachorErrorType.missingAsset:
      return 'Missing asset file';
    case ShamorZachorErrorType.parseError:
      return 'Data parsing error';
    case ShamorZachorErrorType.storageUnavailable:
      return 'Storage unavailable';
    case ShamorZachorErrorType.networkError:
      return 'Network error';
    case ShamorZachorErrorType.invalidData:
      return 'Invalid data';
    case ShamorZachorErrorType.permissionDenied:
      return 'Permission denied';
    case ShamorZachorErrorType.unknown:
      return 'Unknown error';
  }
}
