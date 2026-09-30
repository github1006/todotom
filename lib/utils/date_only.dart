class DateOnly {
  DateOnly._();

  static DateTime from(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime today() => from(DateTime.now());

  static int toStorage(DateTime value) => from(value).millisecondsSinceEpoch;

  static DateTime fromStorage(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime(date.year, date.month, date.day);
  }

  static String format(DateTime value) {
    final d = from(value);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}
