import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts Supabase / network errors into short messages for SnackBars.
class ErrorHelper {
  ErrorHelper._();

  static String friendly(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is SocketException || error is TimeoutException) {
      return 'Weak internet connection. Check your network and try again.';
    }
    if (error is AuthException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    if (error is PostgrestException) {
      final message = error.message.trim();
      if (error.code == 'PGRST202') {
        return 'The server is being updated. Please try again in a few minutes.';
      }
      if (error.code == '28000' || error.code == 'PGRST301') {
        return 'Your session has expired. Please log in again.';
      }
      // Messages raised by our SQL functions are already user friendly.
      if (message.isNotEmpty &&
          !message.contains('violates') &&
          !message.contains('permission denied')) {
        return message;
      }
      return fallback;
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        return details['error'] as String;
      }
      return fallback;
    }
    if (error is StateError) {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException')) {
      return 'Weak internet connection. Check your network and try again.';
    }
    return fallback;
  }

  /// True when the server says the session / mechanic account is gone.
  static bool isAuthProblem(Object error) {
    if (error is PostgrestException) {
      return error.code == '28000' || error.code == 'PGRST301';
    }
    return error is AuthException;
  }
}

/// Small display helpers shared by screens.
class Fmt {
  Fmt._();

  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String ago(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  static String dateTime(DateTime? time) {
    if (time == null) return '';
    final t = time.toLocal();
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '${t.day} ${months[t.month - 1]}, $h:$m $ap';
  }
}
