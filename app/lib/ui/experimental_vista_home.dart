import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'widgets.dart';

/// Experimental phone home based on the Vista dark V-emblem mockup.
/// Connection state, delay, and session start are always read from the core.
class ExperimentalVistaHome extends StatefulWidget {
  const ExperimentalVistaHome({
    super.key,
    required this.core,
    required this.onOpenServers,
    required this.onOpenAccounts,
    required this.onOpenSettings,
  });

  final CoreController core;
  final VoidCallback onOpenServers;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenSettings;

  @override
  State<ExperimentalVistaHome> createState() => _ExperimentalVistaHomeState();
}

class _ExperimentalVistaHomeState extends State<ExperimentalVistaHome>
    with SingleTickerProviderStateMixin {
  Timer? _clock;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _toggle(CoreStatus status, bool on) async {
    if (status.totalAccounts == 0) {
      widget.onOpenAccounts();
      return;
    }
    final switchSystemProxy = status.systemProxySupported &&
        !status.connectPending &&
        status.connectFailure.isEmpty;
    await runShowingErrors(context, () async {
      if (switchSystemProxy) {
        await widget.core.setSystemProxy(on ? 'clear' : 'set');
      } else {
        await widget.core.setOn(!on);
      }
      if (!on) {
        final next = widget.core.status;
        if (next != null && next.proxyOn && !next.connectPending) {
          unawaited(widget.core.runTest().catchError((_) {}));
        }
      }
    });
  }

  String _sessionTime(DateTime? startedAt) {
    if (startedAt == null) return '';
    final elapsed = DateTime.now().difference(startedAt);
    return formatDuration(
      AppLocalizations.of(context),
      elapsed.isNegative ? Duration.zero : elapsed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = widget.core.status;
    final theme = Theme.of(context);
    final baseText = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0A1024) : const Color(0xFFF4F6FB);
    final topBackground = isDark ? const Color(0xFF123348) : const Color(0xFFE8F1F7);
    final card = isDark ? const Color(0xFF1A1B32) : Colors.white;
    final border = isDark ? const Color(0x16FFFFFF) : const Color(0x180A1024);
    final foreground = isDark ? Colors.white : const Color(0xFF172033);
    final secondary = isDark ? const Color(0xFFB7C0D0) : const Color(0xFF536174);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF667085);

    if (status == null) {
      return ColoredBox(
        color: background,
        child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    final running = status.state.phase == Phase.running;
    final canSwitchSystem = status.systemProxySupported;
    final on = canSwitchSystem &&
            !status.connectPending &&
            status.connectFailure.isEmpty
        ? status.systemProxySet || status.tunMode
        : status.proxyOn;
    final confirming = status.connectPending ||
        (on &&
            running &&
            !canSwitchSystem &&
            !status.confirmedBy(widget.core.lastTest));
    final connected = on &&
        running &&
        (status.computerUsesVpn || !canSwitchSystem) &&
        !confirming;
    final look = PhaseLook.of(l, status);
    final accent = !on
        ? (isDark ? const Color(0xFF8D7AB8) : const Color(0xFFB8A2F5))
        : confirming
            ? const Color(0xFFFFB52E)
            : status.state.phase == Phase.error
                ? const Color(0xFFEF6475)
                : connected
                    ? const Color(0xFF00FFC8)
                    : const Color(0xFFF59E0B);
    final powerFill = connected
        ? const Color(0xFF00FFC8)
        : isDark
            ? const Color(0xFF171C2B)
            : Colors.white;
    final powerMark = connected ? const Color(0xFF00FFC8) : accent;
    final test = status.isCurrentTest(widget.core.lastTest)
        ? widget.core.lastTest
        : null;
    final failure = failureText(l, status.proxy, test);
    final failureMessage = status.connectPending
        ? ''
        : status.connectFailure.isNotEmpty
            ? failureCodeText(l, status.connectFailure)
            : failure.code.isNotEmpty || (test != null && !test.ok)
                ? failure.text
                : status.noNetwork && on
                    ? l.noNetwork
                    : '';
    final pingText = widget.core.testing
        ? l.testingDelay
        : test == null
            ? l.testConnection
            : !test.ok
                ? l.testFailed
                : l.milliseconds(test.responseMs);
    final pingColor = test == null
        ? muted
        : !test.ok
            ? const Color(0xFFEF6475)
            : delayColor(test.responseMs);
    final selection = status.selection.trim();
    final selectionLower = selection.toLowerCase();
    final automaticSelection = selection.isEmpty || selectionLower == 'fastest';
    final recommendedSelection = selection.isEmpty;
    final actualExit = connected ? status.exit : null;
    final hasActualExit = actualExit?.countryName.isNotEmpty == true;
    final serverName = automaticSelection && hasActualExit
        ? actualExit!.countryName
        : selectionLower == 'fastest'
            ? l.modeFastest
            : selection.isEmpty
                ? (status.selectionName.isNotEmpty
                    ? status.selectionName
                    : l.recommendedLocation)
                : status.selectionName.isNotEmpty
                    ? status.selectionName
                    : locationName(l, selection, selection);
    final flagCode = automaticSelection
        ? (hasActualExit ? actualExit!.countryCode.toUpperCase() : 'REC')
        : selection.toUpperCase();
    final account = status.activeAccount;
    final usage = account?.usage;
    final quotaProgress = usage == null || usage.unlimited || usage.limitBytes <= 0
        ? 0.0
        : (usage.usedBytes / usage.limitBytes).clamp(0.0, 1.0).toDouble();
    final stateLabel = confirming
        ? l.stateConnecting
        : connected
            ? l.stateConnected
            : look.label;
    // Respect the OS reduced-motion setting. Apart from accessibility,
    // this keeps widget tests and devices with animations disabled settled.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (confirming && !reduceMotion && !_floatController.isAnimating) {
      _floatController.repeat();
    } else if ((!confirming || reduceMotion) &&
        _floatController.isAnimating) {
      _floatController.stop();
      _floatController.value = 0.5;
    }
    final stateHint = !on
        ? l.tapToConnectPhone
        : look.hint.isNotEmpty
            ? look.hint
            : l.tapToDisconnectPhone;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.42),
            radius: 1.08,
            colors: [topBackground, background],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: const Center(
                        child: VistaCircuitMark(
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      'Vista ',
                      style: baseText.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'VPN',
                      style: baseText.titleLarge?.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    _HeaderButton(
                      icon: Icons.settings_rounded,
                      onTap: widget.onOpenSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 342,
                  child: Column(
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 300,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: connected ? 296 : 254,
                              height: connected ? 296 : 254,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accent.withValues(alpha: connected ? 0.16 : 0.055),
                                    accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            for (final ring in connected
                                ? [
                                    (size: 190.0, alpha: isDark ? 0.17 : 0.29),
                                    (size: 224.0, alpha: isDark ? 0.13 : 0.23),
                                    (size: 258.0, alpha: isDark ? 0.09 : 0.17),
                                    (size: 292.0, alpha: isDark ? 0.055 : 0.12),
                                  ]
                                : [
                                    (size: 166.0, alpha: isDark ? 0.15 : 0.27),
                                    (size: 190.0, alpha: isDark ? 0.10 : 0.19),
                                    (size: 214.0, alpha: isDark ? 0.065 : 0.12),
                                  ])
                              Container(
                                width: ring.size,
                                height: ring.size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (connected ? Colors.white : accent).withValues(
                                      alpha: ring.alpha,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                            AnimatedBuilder(
                              animation: _floatController,
                              builder: (context, child) {
                                final phase = _floatController.value * math.pi * 2;
                                final bob = confirming ? math.sin(phase) * 5.0 : 0.0;
                                final tilt = confirming ? math.sin(phase) * 0.012 : 0.0;
                                return Transform.translate(
                                  offset: Offset(0, bob),
                                  child: Transform.rotate(
                                    angle: tilt,
                                    child: child,
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              width: 154,
                              height: 154,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: connected
                                      ? [
                                          Color.lerp(powerFill, Colors.white, 0.10)!,
                                          powerFill,
                                          Color.lerp(powerFill, Colors.black, 0.10)!,
                                        ]
                                      : [
                                          powerFill,
                                          Color.lerp(powerFill, isDark ? const Color(0xFF22263A) : const Color(0xFFF5F2FF), 0.30)!,
                                        ],
                                ),
                                border: Border.all(
                                  color: (isDark ? Colors.white : accent).withValues(
                                  alpha: connected ? 0.28 : (isDark ? 0.10 : 0.22),
                                ),
                                width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: connected ? 0.28 : (isDark ? 0.07 : 0.15),
                                    ),
                                    blurRadius: 38,
                                    spreadRadius: 1,
                                  ),
                                  const BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 22,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: Tooltip(
                                  message: on
                                      ? l.tapToDisconnectPhone
                                      : l.tapToConnectPhone,
                                  child: InkWell(
                                    onTap: widget.core.switchingProxy
                                        ? null
                                        : () => _toggle(status, on),
                                    child: Center(
                                      child: Transform.translate(
                                        // The circuit artwork is optically a little
                                        // lower than its canvas center.
                                        offset: const Offset(0, -7),
                                        child: VistaCircuitMark(
                                          size: 128,
                                          color: powerMark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ),
                            ),
                            if (widget.core.switchingProxy)
                              const SizedBox(
                                width: 174,
                                height: 174,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        stateLabel,
                        textAlign: TextAlign.center,
                        style: baseText.headlineSmall?.copyWith(
                          color: on ? accent : foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (connected)
                        Material(
                          color: card,
                          shape: StadiumBorder(
                            side: BorderSide(color: border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: widget.core.testing
                                ? null
                                : () => runShowingErrors(
                                      context,
                                      widget.core.runTest,
                                    ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.core.testing)
                                    const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.7,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: pingColor,
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    pingText,
                                    style: baseText.labelLarge?.copyWith(
                                      color: pingColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          stateHint,
                          textAlign: TextAlign.center,
                          style: baseText.bodySmall?.copyWith(color: muted),
                        ),
                      if (connected && status.proxy?.startedAt != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          _sessionTime(status.proxy!.startedAt),
                          style: baseText.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  onTap: widget.onOpenServers,
                  child: Row(
                    children: [
                      CountryFlag(code: flagCode, width: 38),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (recommendedSelection || selectionLower == 'fastest') ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Color(0xFF20B879),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  recommendedSelection
                                      ? l.recommendedLocation
                                      : selectionLower == 'fastest'
                                          ? 'Fastest'
                                          : l.navServers,
                                  style: baseText.labelSmall?.copyWith(
                                    color: recommendedSelection || selectionLower == 'fastest'
                                        ? const Color(0xFF20B879)
                                        : muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              serverName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseText.titleMedium?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muted,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                _ActionCard(
                  onTap: widget.onOpenAccounts,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF36DDB3).withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.data_usage_rounded,
                          color: Color(0xFF58DDB8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.dataUsedTitle,
                              style: baseText.titleSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (usage == null)
                              Text(
                                l.quotaNotRead,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              )
                            else if (usage.unlimited)
                              Text(
                                l.unlimited,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              )
                            else if (usage.limitBytes > 0) ...[
                              Text(
                                l.usedOf(
                                  formatBytes(usage.usedBytes.clamp(0, usage.limitBytes).toInt()),
                                  formatBytes(usage.limitBytes),
                                ),
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: quotaProgress,
                                  minHeight: 5,
                                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF58DDB8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${formatBytes(usage.remainingBytes.clamp(0, usage.limitBytes).toInt())} ${l.dataLeftOf(formatBytes(usage.limitBytes))}'
                                '${usage.resetAt == null ? '' : ' · ${l.resets(formatDate(l, usage.resetAt!))}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                            ] else
                              Text(
                                l.quotaNotRead,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muted,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                if (failureMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    failureMessage,
                    textAlign: TextAlign.center,
                    style: baseText.bodySmall?.copyWith(
                      color: const Color(0xFFEF6475),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1B32)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x16FFFFFF)
                : const Color(0x180A1024),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: child,
          ),
        ),
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.055)
            : const Color(0xFFE8EDF5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x16FFFFFF)
                : const Color(0x180A1024),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF536174),
              size: 21,
            ),
          ),
        ),
      );
}

/// The three circuit traces that form Vista's V. This mark can also be
/// exported to the launcher icon artwork in a later, separate step.
class VistaCircuitMark extends StatelessWidget {
  const VistaCircuitMark({
    super.key,
    this.size = 120,
    this.color = const Color(0xFFE5E7EB),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _VistaCircuitPainter(color),
      );
}

class _VistaCircuitPainter extends CustomPainter {
  const _VistaCircuitPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 180);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color, color.withValues(alpha: 0.72)],
      ).createShader(const Rect.fromLTWH(0, 0, 180, 180));

    void trace(List<Offset> points, List<Offset> nodes) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      final nodePaint = Paint()..color = color;
      for (final node in nodes) {
        canvas.drawCircle(node, 6.5, nodePaint);
      }
    }

    trace(
      const [
        Offset(56, 58),
        Offset(74, 58),
        Offset(90, 77),
        Offset(106, 58),
        Offset(124, 58),
      ],
      const [Offset(52, 58), Offset(128, 58)],
    );
    trace(
      const [
        Offset(30, 77),
        Offset(64, 77),
        Offset(90, 107),
        Offset(116, 77),
        Offset(150, 77),
      ],
      const [Offset(26, 77), Offset(154, 77)],
    );
    trace(
      const [
        Offset(42, 96),
        Offset(56, 96),
        Offset(90, 136),
        Offset(124, 96),
        Offset(138, 96),
      ],
      const [Offset(38, 96), Offset(142, 96)],
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VistaCircuitPainter oldDelegate) =>
      oldDelegate.color != color;
}
