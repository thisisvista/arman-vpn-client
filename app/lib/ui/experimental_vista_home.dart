import 'dart:async';
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

class _ExperimentalVistaHomeState extends State<ExperimentalVistaHome> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
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
    const background = Color(0xFF0C0E12);
    const card = Color(0xFF14171F);
    const border = Color(0x16FFFFFF);
    const muted = Color(0xFF9CA3AF);

    if (status == null) {
      return const ColoredBox(
        color: background,
        child: Center(child: CircularProgressIndicator()),
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
        ? const Color(0xFFCBD0D8)
        : confirming
            ? const Color(0xFFF59E0B)
            : status.state.phase == Phase.error
                ? const Color(0xFFEF6475)
                : connected
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B);
    final failure = failureText(l, status.proxy, widget.core.lastTest);
    final failureMessage = failure.code.isNotEmpty
        ? failure.text
        : status.connectFailure.isNotEmpty
            ? failureCodeText(l, status.connectFailure)
            : status.noNetwork && on
                ? l.noNetwork
                : '';
    final test = status.isCurrentTest(widget.core.lastTest)
        ? widget.core.lastTest
        : null;
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
    final serverName = status.selectionName.isNotEmpty
        ? status.selectionName
        : selection.isEmpty
            ? l.recommendedLocation
            : selectionLower == 'fastest'
                ? l.modeFastest
                : locationName(l, selection, selection);
    final flagCode = selection.isEmpty || selectionLower == 'fastest'
        ? 'REC'
        : selection.toUpperCase();
    final account = status.activeAccount;
    final accountTitle = account == null
        ? l.navAccounts
        : account.name.isNotEmpty
            ? account.name
            : account.email.isNotEmpty
                ? maskEmail(account.email)
                : l.navAccounts;
    final accountSubtitle = account?.email.isNotEmpty == true
        ? maskEmail(account!.email)
        : l.navAccounts;
    final stateLabel = confirming
        ? l.stateConnecting
        : connected
            ? l.stateConnected
            : look.label;
    final stateHint = !on
        ? l.tapToConnectPhone
        : look.hint.isNotEmpty
            ? look.hint
            : l.tapToDisconnectPhone;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.42),
            radius: 1.08,
            colors: [Color(0xFF171B24), background],
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
                        color: Colors.white.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: const Center(
                        child: VistaCircuitMark(
                          size: 26,
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      'Vista ',
                      style: baseText.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'VPN',
                      style: baseText.titleLarge?.copyWith(
                        color: const Color(0xFFB7C0D0),
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
                        width: 270,
                        height: 224,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 254,
                              height: 254,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accent.withValues(alpha: on ? 0.17 : 0.075),
                                    accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            for (final size in [174.0, 210.0, 246.0])
                              Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accent.withValues(
                                      alpha: size == 174 ? 0.34 : 0.12,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              width: 154,
                              height: 154,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: on
                                      ? [
                                          Color.lerp(accent, Colors.white, 0.20)!,
                                          accent,
                                          Color.lerp(accent, Colors.black, 0.20)!,
                                        ]
                                      : const [
                                          Color(0xFF343944),
                                          Color(0xFF171A21),
                                        ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: on ? 0.30 : 0.12,
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
                                    child: VistaCircuitMark(
                                      size: 128,
                                      color: on
                                          ? const Color(0xFFFFFFFF)
                                          : const Color(0xFFE5E7EB),
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
                          color: on ? accent : Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (connected)
                        Material(
                          color: card,
                          shape: const StadiumBorder(
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
                            Text(
                              l.navServers,
                              style: baseText.labelSmall?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              serverName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseText.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.all_inclusive_rounded,
                          color: Color(0xFF34D399),
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              accountTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseText.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              accountSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseText.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
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

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.055),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x16FFFFFF)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: const Color(0xFFD1D5DB), size: 21),
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF14171F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0x16FFFFFF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: child,
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
        colors: [Colors.white, color, color.withValues(alpha: 0.72)],
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
