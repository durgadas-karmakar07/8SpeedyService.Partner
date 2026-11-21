import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Live updates for the mechanic's active job over PRIVATE Realtime
/// Broadcast topics (authorised by RLS on realtime.messages):
///
///   `booking:{id}`                 -> 'booking' (customer cancelled, status changed)
///   `booking:{id}:m:{mechanicId}`  -> 'chat'    (new customer message)
///
/// The job screen keeps polling as a safety net.
class JobLive {
  JobLive({
    required this.bookingId,
    required this.mechanicId,
    this.onStatus,
    this.onChat,
  });

  final String bookingId;
  final String mechanicId;
  final void Function()? onStatus;
  final void Function(String senderRole)? onChat;

  SupabaseClient get _client => Supabase.instance.client;
  final List<RealtimeChannel> _channels = <RealtimeChannel>[];

  static Map<String, dynamic> _unwrap(Map<String, dynamic> message) {
    final inner = message['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : message;
  }

  void start() {
    try {
      _channels.add(
        _client
            .channel(
              'booking:$bookingId',
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(event: 'booking', callback: (_) => onStatus?.call())
            .subscribe(),
      );
      _channels.add(
        _client
            .channel(
              'booking:$bookingId:m:$mechanicId',
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(
              event: 'chat',
              callback: (m) =>
                  onChat?.call(_unwrap(m)['sender_role']?.toString() ?? ''),
            )
            .subscribe(),
      );
    } catch (_) {
      // Realtime unavailable: polling continues.
    }
  }

  Future<void> dispose() async {
    final list = List<RealtimeChannel>.of(_channels);
    _channels.clear();
    for (final c in list) {
      try {
        await _client.removeChannel(c);
      } catch (_) {}
    }
  }
}
