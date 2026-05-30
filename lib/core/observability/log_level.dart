/// Supported log levels for the MemoVault application observability framework.
///
/// Designed to follow ADR-013 privacy rules and log retention levels.
enum LogLevel {
  /// extremely detailed execution flows
  trace('TRACE', '🔍'),

  /// general development inspection and debugging details
  debug('DEBUG', '🛠️'),

  /// system-level state alterations and significant application operations
  info('INFO ', 'ℹ️'),

  /// non-fatal errors or recovered edge-cases that don't block execution
  warning('WARN ', '⚠️'),

  /// operation failures and caught errors
  error('ERROR', '❌'),

  /// boot or critical runtime failures requiring user or process intervention
  fatal('FATAL', '🚨');

  final String label;
  final String emoji;

  const LogLevel(this.label, this.emoji);

  @override
  String toString() => label;
}
