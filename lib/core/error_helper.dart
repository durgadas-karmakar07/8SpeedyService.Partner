import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts Supabase / network errors into short messages for SnackBars.
class ErrorHelper {
  ErrorHelper._();

  static String friendly(
    Object error, {
    String fallback = 'Kuch galat ho gaya. Please dobara try karein.',
  }) {
    if (error is SocketException || error is TimeoutException) {
      return 'Internet connection weak hai. Network check karke retry karein.';
    }
    if (error is AuthException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    if (error is PostgrestException) {
      final message = error.message.trim();
      if (error.code == '28000' || error.code == 'PGRST301') {
        return 'Session expire ho gaya. Please dobara login karein.';
      }
      // Messages raised by our SQL functions are already user friendly.
      if (message.isNotEmpty &&
          !message.contains('violates') &&
          !message.contains('permission denied')) {
        return message;
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
      return 'Internet connection weak hai. Network check karke retry karein.';
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
    if (diff.inSeconds < 60) return 'abhi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min pehle';
    if (diff.inHours < 24) return '${diff.inHours} ghante pehle';
    return '${diff.inDays} din pehle';
  }

  static String dateTime(DateTime? time) {
    if (time == null) return '';
    final t = time.toLocal();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '${t.day} ${months[t.month - 1]}, $h:$m $ap';
  }
}
