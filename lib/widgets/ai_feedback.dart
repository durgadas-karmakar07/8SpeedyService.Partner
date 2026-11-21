import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/error_helper.dart';

/// Reasons a user can report an AI answer for (values match the
/// `ai_submit_feedback` RPC).
const List<(String, String, IconData)> kAiReportReasons =
    <(String, String, IconData)>[
      ('wrong', 'Wrong or misleading', Icons.rule_rounded),
      ('unsafe', 'Unsafe advice', Icons.health_and_safety_rounded),
      ('offensive', 'Offensive or inappropriate', Icons.report_rounded),
    ];

/// "Was this helpful?" + "Report" row shown under every AI answer.
///
/// Google Play's AI-generated content policy requires that users can flag
/// offensive or unsafe AI output without leaving the app. The choice is saved
/// on the user's own `ai_requests` row (server RPC `ai_submit_feedback`), where
/// the team reviews reports.
class AiFeedbackBar extends StatefulWidget {
  const AiFeedbackBar({super.key, required this.onSubmit});

  /// Sends `feedback` (`helpful`, `not_helpful`, `wrong`, `unsafe`,
  /// `offensive`) with an optional note.
  final Future<void> Function(String feedback, String? note) onSubmit;

  @override
  State<AiFeedbackBar> createState() => _AiFeedbackBarState();
}

class _AiFeedbackBarState extends State<AiFeedbackBar> {
  static const Color _navy = Color(0xFF1E293B);
  static const Color _orange = Color(0xFFFF5722);
  static const Color _muted = Color(0xFF64748B);

  String? _sent;
  bool _busy = false;

  bool get _reported =>
      _sent != null && _sent != 'helpful' && _sent != 'not_helpful';

  Future<void> _send(String feedback, [String? note]) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      await widget.onSubmit(feedback, note);
      if (!mounted) return;
      setState(() {
        _sent = feedback;
        _busy = false;
      });
      if (_reported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks. Our team will review this answer.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHelper.friendly(
              e,
              fallback: 'Could not send your feedback. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _report() async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ReportSheet(),
    );
    if (result == null || !mounted) return;
    final note = result.$2.trim();
    await _send(result.$1, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              sent == null
                  ? 'Was this helpful?'
                  : _reported
                  ? 'Reported — thank you'
                  : 'Thanks for your feedback',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ),
          if (sent == null) ...<Widget>[
            IconButton(
              tooltip: 'Helpful',
              onPressed: _busy ? null : () => _send('helpful'),
              icon: const Icon(Icons.thumb_up_alt_outlined, size: 20),
              color: _muted,
            ),
            IconButton(
              tooltip: 'Not helpful',
              onPressed: _busy ? null : () => _send('not_helpful'),
              icon: const Icon(Icons.thumb_down_alt_outlined, size: 20),
              color: _muted,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                _reported
                    ? Icons.flag_rounded
                    : sent == 'helpful'
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_down_alt_rounded,
                size: 20,
                color: _orange,
              ),
            ),
          if (!_reported)
            TextButton.icon(
              onPressed: _busy ? null : _report,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Report'),
              style: TextButton.styleFrom(foregroundColor: _muted),
            ),
        ],
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _note = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Report this answer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tell us what is wrong. Our team reviews every report and improves the assistant.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              ...kAiReportReasons.map((r) {
                final selected = _reason == r.$1;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    r.$3,
                    color: selected
                        ? const Color(0xFFFF5722)
                        : const Color(0xFF94A3B8),
                  ),
                  title: Text(
                    r.$2,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? const Color(0xFFFF5722)
                        : const Color(0xFFCBD5E1),
                  ),
                  onTap: () => setState(() => _reason = r.$1),
                );
              }),
              const SizedBox(height: 4),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Tell us more (optional)',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop((_reason!, _note.text)),
                child: const Text('Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
