import 'dart:ui';

class TilePatcherSelection {
  const TilePatcherSelection({
    required this.path,
    required this.image,
    required this.patch,
  });

  final String path;
  final Image image;
  final Image patch;
}
