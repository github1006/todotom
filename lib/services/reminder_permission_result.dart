class ReminderPermissionResult {
  const ReminderPermissionResult._({
    required this.isReady,
    required this.message,
    this.openSettings = false,
  });

  final bool isReady;
  final String message;
  final bool openSettings;

  factory ReminderPermissionResult.ready() {
    return const ReminderPermissionResult._(
      isReady: true,
      message: 'Recordatorios por ubicación activos',
    );
  }

  factory ReminderPermissionResult.needsBackground() {
    return const ReminderPermissionResult._(
      isReady: false,
      message: 'Elige "Permitir todo el tiempo" en ubicación para recibir avisos',
      openSettings: true,
    );
  }

  factory ReminderPermissionResult.denied(String reason, {bool openSettings = false}) {
    return ReminderPermissionResult._(
      isReady: false,
      message: reason,
      openSettings: openSettings,
    );
  }

  factory ReminderPermissionResult.notNeeded() {
    return const ReminderPermissionResult._(
      isReady: true,
      message: '',
    );
  }
}
