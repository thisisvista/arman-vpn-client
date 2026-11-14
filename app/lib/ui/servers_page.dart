import 'dart:async';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'browser_signin.dart';
import 'widgets.dart';

/// The server list, one choice in one list: Recommended and Fastest, which
/// the app picks, then the locations with their real delay. A tap on a row
/// chooses it (`proxy.country`: empty for Mozilla's recommended location,
/// `fastest` for the lowest real delay, otherwise a country).
class ServersPage extends StatefulWidget {
  const ServersPage({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<ServersPage> createState() => _ServersPageState();
}

/// How old measured delays are before the page measures them again when
/// it opens.
const _pingStale = Duration(minutes: 10);

class _ServersPageState extends State<ServersPage> {
  List<Location>? _locations;
  DateTime? _pingedAt;
  String _country = '';
  bool _testing = false;

  /// The choice being saved ('' recommended, 'fastest', or a code).
  String? _busy;
  String? _summary;

  CoreController get _core => widget.core;

  /// No account yet: the delays cannot be measured (Mozilla's servers
  /// answer only an account's pass), so the page says to add one instead.
  bool get _noAccounts => _core.status?.totalAccounts == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _core.call((api) => api.locations());
      final config = await _core.settings();
      if (!mounted) return;
      setState(() {
        _locations = list.locations;
        _pingedAt = list.pingedAt;
        if (config['proxy'] case {'country': final String country}) {
          _country = country;
        }
      });
      // Delays measured a while ago, or never: measured again at once (the
      // core does it also while the proxy is off).
      final at = _pingedAt;
      if (!_noAccounts &&
          (at == null || DateTime.now().difference(at) > _pingStale)) {
        unawaited(_test());
      }
    } on CoreApiException catch (e) {
      if (mounted) showError(context, e.message);
    } on CoreUnavailable {
      // The shell shows it.
    }
  }

  Future<void> _choose(String country) async {
    if (_busy != null || _country.toLowerCase() == country.toLowerCase()) {
      return;
    }
    setState(() => _busy = country);
    final ok = await runShowingErrors(
      context,
      () => _core.setLocation(country),
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (ok) _country = country;
    });
  }

  Future<void> _test() async {
    final l = AppLocalizations.of(context);
    final codes = [
      for (final loc in _locations ?? const <Location>[]) loc.code,
    ];
    setState(() {
      _testing = true;
      _summary = null;
    });
    try {
      final result = await _core.call((api) => api.pingLocations(codes));
      final tested = {for (final loc in result.locations) loc.code: loc};
      if (!mounted) return;
      setState(() {
        _locations = [
          for (final loc in _locations ?? const <Location>[])
            tested[loc.code] ?? loc,
        ];
        _pingedAt = result.pingedAt ?? DateTime.now();
        final answered = result.locations.where((loc) => loc.answered).length;
        _summary = l.delaySummary(answered, result.locations.length);
      });
    } on CoreApiException {
      // The core's own words are for the log; the user gets what to do.
      if (mounted) showError(context, l.delayTestFailed);
    } on CoreUnavailable catch (e) {
      if (mounted) showError(context, describeProblem(l, e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Every country, without Mozilla's recommended location (the choice
  /// above), fastest first, then by name in the app's language.
  List<Location> _countries(AppLocalizations l) {
    final list = [
      for (final loc in _locations ?? const <Location>[])
        if (!isRecommendedPlace(loc.code)) loc,
    ];
    list.sort((a, b) {
      final da = a.answered ? a.pingMs : 1 << 30;
      final db = b.answered ? b.pingMs : 1 << 30;
      if (da != db) return da.compareTo(db);
      return nameSortKey(
        l.localeName,
        locationName(l, a.code, a.name),
      ).compareTo(nameSortKey(l.localeName, locationName(l, b.code, b.name)));
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final chosen = _country.toLowerCase();
    final countries = _countries(l);
    final recommended = (_locations ?? const <Location>[])
        .where((loc) => isRecommendedPlace(loc.code))
        .firstOrNull;
    final delayLine =
        _summary ??
        (_pingedAt == null ? null : l.testedAgo(formatAgo(l, _pingedAt!)));
    final noAccounts = _noAccounts;
    return ListView(
      padding: pagePadding(context),
      children: [
        PageTitle(l.navServers),
        if (noAccounts) ...[
          NoAccountsPanel(
            onAdd: () => startAddAccount(context, _core, widget.settings),
          ),
          const SizedBox(height: 12),
        ],
        _SectionHeader(title: l.autoSection),
        Row(
          children: [
            Expanded(
              child: _AutoModeCard(
                title: l.modeRecommended,
                subtitle: l.modeRecommendedHint,
                icon: Icons.auto_awesome_rounded,
                tint: const Color(0xFFEDE5FF),
                ink: const Color(0xFF6941A5),
                selected: chosen == '',
                busy: _busy == '',
                delay: recommended == null
                    ? null
                    : _Delay(location: recommended, testing: _testing),
                onTap: () => _choose(''),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AutoModeCard(
                title: l.modeFastest,
                subtitle: l.modeFastestHint,
                icon: Icons.bolt_rounded,
                tint: const Color(0xFFE1F7EA),
                ink: const Color(0xFF18794E),
                selected: chosen == 'fastest',
                busy: _busy == 'fastest',
                onTap: () => _choose('fastest'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: l.locationsSection,
          action: TextButton.icon(
            onPressed: !_testing && _locations != null && !noAccounts
                ? _test
                : null,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed_rounded, size: 18),
            label: Text(_testing ? l.testingDelay : l.testDelay),
          ),
        ),
        if (delayLine != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Text(delayLine, style: muted),
          ),
        if (_locations == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (countries.isEmpty)
          Panel(child: Text(l.noServers, style: muted))
        else
          _ChoiceCard(
            children: [
              for (final loc in countries)
                _ChoiceRow(
                  leading: CountryFlag(code: loc.code, width: 36),
                  title: locationName(l, loc.code, loc.name),
                  subtitle: _subtitle(loc),
                  delay: _Delay(location: loc, testing: _testing),
                  selected: chosen == loc.code.toLowerCase(),
                  busy: _busy?.toLowerCase() == loc.code.toLowerCase(),
                  onTap: () => _choose(loc.code),
                ),
            ],
          ),
      ],
    );
  }

  /// A location's second line: its city when it says more than the
  /// country.
  String? _subtitle(Location loc) =>
      loc.city.isNotEmpty && loc.city != loc.name ? loc.city : null;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Rows of choices in one card, divided by thin lines.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    ),
  );
}

/// Compact side-by-side automatic choices with the agreed Vista colors.
class _AutoModeCard extends StatelessWidget {
  const _AutoModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.ink,
    required this.selected,
    required this.busy,
    required this.onTap,
    this.delay,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color ink;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final Widget? delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? ink : ink.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: ink, size: 20),
                  const Spacer(),
                  if (busy)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink,
                      ),
                    )
                  else
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: ink,
                      size: 19,
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ink.withValues(alpha: 0.82),
                ),
              ),
              if (delay != null) ...[
                const SizedBox(height: 7),
                DefaultTextStyle.merge(
                  style: TextStyle(color: ink),
                  child: delay!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


/// One choice: what it is, its delay, and a radio mark; a tap chooses it.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.leading,
    required this.title,
    required this.selected,
    required this.busy,
    required this.onTap,
    this.subtitle,
    this.delay,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? delay;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (delay != null) ...[const SizedBox(width: 10), delay!],
              const SizedBox(width: 6),
              SizedBox.square(
                dimension: 24,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(3),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? scheme.primary : scheme.outline,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A location's real delay as a small badge in its color. While the delays
/// are measured, a small spinner instead of the last results, which may be
/// old (a measurement while offline answers nothing). A location that did
/// not answer is grey, not red: it says nothing is wrong with the app.
class _Delay extends StatelessWidget {
  const _Delay({required this.location, required this.testing});

  final Location location;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final loc = location;
    final (text, color) = testing
        ? ('', muted)
        : loc.answered
        ? (l.milliseconds(loc.pingMs), delayColor(loc.pingMs))
        : loc.pingError.isNotEmpty
        ? (l.noAnswer, muted)
        : ('—', muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: testing
          ? SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: muted),
            )
          : Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
