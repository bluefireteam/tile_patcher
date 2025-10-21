import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:tile_patcher/models/models.dart';

class TilePatcherImageSelectionView extends StatelessWidget {
  const TilePatcherImageSelectionView({
    required this.onSelect,
    super.key,
  });

  final void Function(TilePatcherSelection) onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          const typeGroup = XTypeGroup(
            label: 'images',
            extensions: <String>['jpg', 'png'],
          );
          final file =
              await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

          if (file != null) {
            final bytes = await file.readAsBytes();
            final image = await decodeImageFromList(bytes);

            final selection = TilePatcherSelection(
              path: file.path,
              image: image,
              patch: image,
            );

            onSelect(selection);
          }
        },
        child: const Text('Load image'),
      ),
    );
  }
}
