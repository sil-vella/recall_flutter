import '../../../../../../tools/logging/logger.dart';

enum WebSocketError {
  noConnectionModule,
  noValidToken,
  connectionFailed,
  unknownError
}

class WebSocketResult {
  final bool success;
  final WebSocketError? errorId;
  final String? errorMessage;
  final dynamic data;

  WebSocketResult({
    required this.success, 
    this.errorId,
    this.errorMessage,
    this.data
  });

  static String getErrorMessage(WebSocketError error) {
    switch (error) {
      case WebSocketError.noConnectionModule:
        return "Connection module not available";
      case WebSocketError.noValidToken:
        return "Authentication token expired or invalid";
      case WebSocketError.connectionFailed:
        return "Failed to establish WebSocket connection";
      case WebSocketError.unknownError:
        return "An unknown error occurred";
    }
  }
}

class ResultHandler {
  static final Logger _log = Logger();

  WebSocketResult createSuccessResult({dynamic data}) {
    return WebSocketResult(
      success: true,
      data: data
    );
  }

  WebSocketResult createErrorResult(WebSocketError error, {String? customMessage}) {
    final message = customMessage ?? WebSocketResult.getErrorMessage(error);
    _log.error("❌ WebSocket error: $message");
    
    return WebSocketResult(
      success: false,
      errorId: error,
      errorMessage: message
    );
  }

  WebSocketResult createUnknownErrorResult(String errorMessage) {
    _log.error("❌ WebSocket unknown error: $errorMessage");
    
    return WebSocketResult(
      success: false,
      errorId: WebSocketError.unknownError,
      errorMessage: errorMessage
    );
  }
} 