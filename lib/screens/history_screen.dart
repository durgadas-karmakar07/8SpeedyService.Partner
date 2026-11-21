import 'package:material_ui/material_ui.dart';

import '../core/constants.dart';
import '../core/error_helper.dart';
import '../core/vehicle_view.dart';
import '../models/models.dart';
import '../services/partner_service.dart';
import 'login_screen.dart';
import '../widgets/speedy_loader.dart';

/// Stats (today / week / total / rating) and past jobs with customer reviews.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.profile});

  final MechanicProfile profile;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final PartnerService _api = PartnerService();
  PartnerStats? _stats;
  List<JobHistoryItem> _items = const <JobHistoryItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _api.getStats(),
        _api.getHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as PartnerStats;
        _items = results[1] as List<JobHistoryItem>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHelper.friendly(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & Jobs')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: PartnerConstants.primaryColor,
                  child: Icon(Icons.engineering_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        p.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          if (p.shopName != null) p.shopName!,
                          p.phone,
                        ].join(' • '),
                        style: TextStyle(color: Colors.blueGrey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...<Widget>[
              ErrorBox(message: _error!),
              const SizedBox(height: 12),
            ],
            if (_loading && _stats == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: RoadLoader(messages: <String>['Loading your jobs…']),
                ),
              ),
            if (_stats != null) _statsGrid(_stats!),
            const SizedBox(height: 20),
            const Text(
              'Recent jobs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (!_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No jobs yet. Go online to get your first job!',
                  textAlign: TextAlign.center,
                ),
              ),
            ..._items.map(_historyTile),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(PartnerStats s) {
    Widget tile(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFF0F172A),
                PartnerConstants.darkColor,
                Color(0xFF334155),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Earnings this month',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${s.monthEarnings}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${s.monthCompleted} jobs • ₹${s.totalEarnings} all time',
                style: const TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 110, child: _WeekChart(days: s.daily)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            tile(
              'Today',
              '₹${s.todayEarnings}',
              Icons.today_rounded,
              PartnerConstants.primaryColor,
            ),
            const SizedBox(width: 10),
            tile(
              'This week',
              '₹${s.weekEarnings}',
              Icons.date_range_rounded,
              PartnerConstants.successColor,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            tile(
              'Rating (${s.ratingCount})',
              s.rating.toStringAsFixed(1),
              Icons.star_rounded,
              Colors.amber.shade700,
            ),
            const SizedBox(width: 10),
            tile(
              'Jobs finished',
              '${s.completionRate}%',
              Icons.verified_rounded,
              const Color(0xFF2563EB),
            ),
          ],
        ),
        if (s.completionRate < 80)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Tip: releasing accepted jobs lowers your completion rate. More than 3 releases in 24 hours pauses new jobs for 12 hours.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ),
      ],
    );
  }

  Widget _historyTile(JobHistoryItem j) {
    final vehicle = PartnerConstants.vehicleFor(j.vehicleType);
    final cancelled = !j.isCompleted;
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: SizedBox(
          width: 56,
          child: VehicleImage(
            category: j.vehicleType,
            bodyType: j.vehicleBodyType,
            height: 34,
          ),
        ),
        title: Text(
          j.vehicleLabel != null
              ? vehicleName(j.vehicleLabel, j.vehicleType)
              : (j.issueTags.isEmpty ? vehicle.title : j.issueTags.join(', ')),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(j.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(Fmt.dateTime(j.when), style: const TextStyle(fontSize: 12)),
            if (j.repairAmount != null)
              Text(
                'Bill: ₹${j.repairAmount}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: PartnerConstants.successColor,
                ),
              ),
            if (j.reviewTags.isNotEmpty)
              Text(
                j.reviewTags.join(' • '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
              ),
            if (j.reviewText != null)
              Text(
                '“${j.reviewText}”',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        trailing: cancelled
            ? const Text(
                'Cancelled',
                style: TextStyle(
                  color: PartnerConstants.dangerColor,
                  fontWeight: FontWeight.w700,
                ),
              )
            : j.rating != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${j.rating}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade700,
                    size: 18,
                  ),
                ],
              )
            : const Icon(
                Icons.check_circle_rounded,
                color: PartnerConstants.successColor,
              ),
      ),
    );
  }
}

/// Simple 7-day bar chart of daily earnings (last 7 days, today on the right).
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<DailyEarning> days;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final byDay = <String, DailyEarning>{
      for (final d in days) '${d.day.year}-${d.day.month}-${d.day.day}': d,
    };
    final series = List<({String label, int earnings, int jobs})>.generate(7, (
      i,
    ) {
      final day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - i));
      final d = byDay['${day.year}-${day.month}-${day.day}'];
      const names = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return (
        label: names[day.weekday - 1],
        earnings: d?.earnings ?? 0,
        jobs: d?.jobs ?? 0,
      );
    });
    final maxValue = series.fold<int>(
      0,
      (m, e) => e.earnings > m ? e.earnings : m,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: series.map((e) {
        final ratio = maxValue == 0 ? 0.0 : e.earnings / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (e.jobs > 0)
                  Text(
                    '${e.jobs}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 8 + 66 * ratio,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: e.earnings > 0
                          ? const <Color>[
                              Color(0xFFFF7A45),
                              PartnerConstants.primaryColor,
                            ]
                          : <Color>[Colors.white24, Colors.white24],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
