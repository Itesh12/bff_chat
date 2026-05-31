import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/core/theme/app_color_scheme.dart';
import 'package:memovault/features/messaging/spike/signal_spike_service.dart';

class SignalSpikeScreen extends StatefulWidget {
  const SignalSpikeScreen({super.key});

  @override
  State<SignalSpikeScreen> createState() => _SignalSpikeScreenState();
}

class _SignalSpikeScreenState extends State<SignalSpikeScreen> {
  final SignalSpikeService _spikeService = SignalSpikeService();
  bool _isRunning = false;
  bool? _isPass;
  final ScrollController _logScrollController = ScrollController();

  void _runDiagnostics() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _isPass = null;
    });

    final success = await _spikeService.runDiagnostics();

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isPass = success;
      });
      
      // Auto scroll logs to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _copyLogsToClipboard() {
    if (_spikeService.logs.isEmpty) return;
    final allLogs = _spikeService.logs.join('\n');
    Clipboard.setData(ClipboardData(text: allLogs));
    
    Get.rawSnackbar(
      messageText: const Text(
        'Logs copied to clipboard successfully!',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.green.shade800,
      snackPosition: SnackPosition.BOTTOM,
      borderRadius: 12,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.extension<AppColorScheme>()!;

    return AppScaffold(
      title: 'libsignal Cryptographic Spike',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 28),
                      const AppGap.h12(),
                      Text(
                        'Phase 4.3.0 Compatibility Validation',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const AppGap.v12(),
                  Text(
                    'This screen runs dynamic, runtime cryptographic operations directly inside this device\'s architecture to verify the viability and stability of the Rust-backed libsignal dynamic libraries.',
                    style: AppTypography.bodyLarge.copyWith(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const AppGap.v16(),

            // Control panel card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Cryptographic Stack', style: AppTypography.labelMedium),
                          const AppGap.v4(),
                          Text(
                            'libsignal_dart (Rust FFI)',
                            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_isPass != null)
                        AppChip(
                          label: _isPass! ? 'SPIKE: PASS' : 'SPIKE: FAIL',
                          color: _isPass! ? colorScheme.success : colorScheme.error,
                        ),
                    ],
                  ),
                  const AppGap.v16(),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.primary(
                          text: _isRunning ? 'Executing Cryptographic Steps...' : 'Run Dynamic Diagnostics',
                          onPressed: _isRunning ? null : _runDiagnostics,
                          icon: _isRunning ? Icons.hourglass_empty_rounded : Icons.play_circle_filled_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const AppGap.v16(),

            // Step results
            if (_spikeService.results.isNotEmpty) ...[
              Text(
                'Operation Results Matrix',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const AppGap.v8(),
              ..._spikeService.results.map((result) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    borderColor: result.isSuccess
                        ? colorScheme.success.withValues(alpha: 0.3)
                        : colorScheme.error.withValues(alpha: 0.3),
                    backgroundColor: result.isSuccess
                        ? colorScheme.success.withValues(alpha: 0.03)
                        : colorScheme.error.withValues(alpha: 0.03),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          result.isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: result.isSuccess ? colorScheme.success : colorScheme.error,
                          size: 24,
                        ),
                        const AppGap.h12(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.stepName,
                                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const AppGap.v4(),
                              Text(
                                result.detail,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontSize: 13,
                                  color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                              if (result.error != null) ...[
                                const AppGap.v8(),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    result.error!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const AppGap.v16(),
            ],

            // Scrollable Console logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diagnostics Console Output',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_spikeService.logs.isNotEmpty)
                  AppIconButton.secondary(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy Logs',
                    onPressed: _copyLogsToClipboard,
                  ),
              ],
            ),
            const AppGap.v8(),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Sleek Slate-900 color
                borderRadius: BorderRadius.circular(AppRadius.rLarge),
                border: Border.all(
                  color: _isPass == null
                      ? Colors.blue.withValues(alpha: 0.3)
                      : (_isPass!
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3)),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: _spikeService.logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Console idle. Tap "Run Dynamic Diagnostics" to start operations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      itemCount: _spikeService.logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                          child: Text(
                            _spikeService.logs[index],
                            style: const TextStyle(
                              color: Color(0xFF38BDF8), // Terminal light blue
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const AppGap.v24(),
          ],
        ),
      ),
    );
  }
}
