import 'package:flutter/material.dart';
import 'package:tile_patcher/models/models.dart';
import 'package:tile_patcher/views/views.dart';

class TilesetPatcherHome extends StatefulWidget {
  const TilesetPatcherHome({super.key});

  @override
  State<TilesetPatcherHome> createState() => _TilesetPatcherHomeState();
}

class _TilesetPatcherHomeState extends State<TilesetPatcherHome> {
  TilePatcherSelection? _selection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selection == null
          ? TilePatcherImageSelectionView(
              onSelect: (TilePatcherSelection selection) {
                setState(() {
                  _selection = selection;
                });
              },
            )
          : TilePatcherEditorView(
              selection: _selection!,
              onCancel: () {
                setState(() {
                  _selection = null;
                });
              },
            ),
    );
  }
}
