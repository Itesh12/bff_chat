import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:memovault/core/design_system/design_system.dart';
import 'package:memovault/features/hidden/services/messaging_identity_service.dart';

class MessagingProfileScreen extends StatefulWidget {
  const MessagingProfileScreen({super.key});

  @override
  State<MessagingProfileScreen> createState() => _MessagingProfileScreenState();
}

class _MessagingProfileScreenState extends State<MessagingProfileScreen> {
  final _identityService = Get.find<MessagingIdentityService>();
  String _username = '';
  String _displayName = '';
  String _publicKey = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await _identityService.getUsername();
    final display = await _identityService.getDisplayName();
    final key = await _identityService.getPublicKey();
    setState(() {
      _username = user ?? '@unknown';
      _displayName = display ?? (user?.startsWith('@') == true ? user!.substring(1) : (user ?? 'unknown'));
      _publicKey = key ?? 'Fingerprint not calculated';
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _username));
    AppSnackBar.success(
      title: 'Copied',
      message: 'Pseudonym username copied to clipboard.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dynamic generated clean fingerprint string for security audits
    final cleanFingerprint = _publicKey.length > 24
        ? '${_publicKey.substring(0, 8)}...${_publicKey.substring(_publicKey.length - 8)}'
            .toUpperCase()
        : _publicKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppIconButton.secondary(
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mock QR glassmorphic visual block
              Center(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  backgroundColor: theme.cardColor.withValues(alpha: 0.8),
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  child: Column(
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 130,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const AppGap.v12(),
                      Text(
                        'Pairing Scheme Reserved',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'memovault://pair?user=$_username',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 9,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AppGap.v32(),

              // User Info details
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  children: [
                    Text(
                      'SECURE IDENTITY',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                      ),
                    ),
                    const AppGap.v8(),
                    Text(
                      _displayName,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const AppGap.v4(),
                    Text(
                      _username,
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                    const AppGap.v16(),
                    const Divider(height: 1),
                    const AppGap.v16(),
                    Text(
                      'IDENTITY FINGERPRINT',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                      ),
                    ),
                    const AppGap.v8(),
                    Text(
                      cleanFingerprint,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        fontFamily: 'monospace',
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const AppGap.v48(),

              // Action buttons
              AppButton.primary(
                text: 'Copy Username',
                icon: Icons.copy_rounded,
                onPressed: _copyToClipboard,
              ),
              const AppGap.v16(),
              AppButton.secondary(
                text: 'Share My Profile Link',
                icon: Icons.share_rounded,
                onPressed: () {
                  // Simulate sharesheet launch
                  AppSnackBar.info(
                    title: 'Share Profile',
                    message: 'Native OS sharesheet triggered for: $_username',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
