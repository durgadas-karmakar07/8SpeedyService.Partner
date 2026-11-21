import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../models/models.dart';
import '../services/job_live.dart';
import '../services/partner_service.dart';
import '../widgets/speedy_loader.dart';

/// In-app chat with the customer of the active job. Messages are private to
/// this booking; payment IDs and links are blocked by the server.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.mechanicId,
    required this.title,
  });

  final String bookingId;
  final String mechanicId;
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final PartnerService _api = PartnerService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _open = true;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;
  JobLive? _live;

  static const List<String> _quick = <String>[
    'I am on my way',
    'I will reach in 10 minutes',
    'I have reached. Where are you?',
    'Please share a nearby landmark',
    'Work is done',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _load(silent: true),
    );
    _live = JobLive(
      bookingId: widget.bookingId,
      mechanicId: widget.mechanicId,
      onChat: (_) => _load(silent: true),
    )..start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _live?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final thread = await _api.getMessages(widget.bookingId);
      if (!mounted) return;
      final grew = thread.messages.length != _messages.length;
      setState(() {
        _messages = thread.messages;
        _open = thread.open;
        _loading = false;
      });
      if (grew) _toBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorHelper.friendly(e))));
      }
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await _api.sendMessage(widget.bookingId, text);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      _input.clear();
      setState(() {
        _messages = <ChatMessage>[..._messages, msg];
        _sending = false;
      });
      _toBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHelper.friendly(e))));
    }
  }

  String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              _open ? 'Customer chat' : 'Chat closed',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: WheelLoader(size: 40))
                : _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Send the customer a quick update. Never ask for advance payment — '
                        'the customer pays after the work.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          if (_open) _composer() else _closed(),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.senderRole == 'mechanic';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? PartnerConstants.darkColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                m.body,
                style: TextStyle(
                  color: mine ? Colors.white : PartnerConstants.darkColor,
                  fontSize: 14.5,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _time(m.createdAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: mine ? Colors.white60 : const Color(0xFF94A3B8),
                  ),
                ),
                if (mine) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    m.readAt != null
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: m.readAt != null
                        ? const Color(0xFF7DD3FC)
                        : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quick.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(
                    _quick[i],
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: _sending ? null : () => _send(_quick[i]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: PartnerConstants.primaryColor,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const WheelLoader(size: 20, color: Colors.white)
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _closed() {
    return const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This chat is closed because the job has ended.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ),
    );
  }
}
