/// Configuración del sonido de recordatorio.
///
/// - Sin URI → tono de notificación predeterminado del teléfono.
/// - Con URI → tono elegido en el selector nativo de Android.
class ReminderSoundConfig {
  const ReminderSoundConfig({
    this.uri,
    this.title,
  });

  final String? uri;
  final String? title;

  bool get usesSystemPicker => uri != null && uri!.isNotEmpty;

  String get displayLabel {
    if (!usesSystemPicker) return 'Predeterminado del teléfono';
    return title ?? 'Tono del teléfono';
  }
}
