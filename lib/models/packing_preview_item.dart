class PackingPreviewItem {
  const PackingPreviewItem({
    required this.title,
    required this.done,
    this.itemId,
  });

  final String title;
  final bool done;
  final String? itemId;
}
