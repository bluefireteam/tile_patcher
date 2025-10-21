import 'package:flutter/material.dart';
import 'package:tile_patcher/views/views.dart';

class TilePatcherApp extends StatelessWidget {
  const TilePatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TilesetPatcherHome(),
    );
  }
}
