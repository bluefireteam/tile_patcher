import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nes_ui/nes_ui.dart';
import 'package:tile_patcher/models/models.dart';
import 'package:path/path.dart' as path;

extension on Patch {
  BoxDecoration toBoxDecoration() {
    final noPatchColor = Colors.blueGrey.withValues(alpha: 0.2);
    return BoxDecoration(
      border: Border(
        left: BorderSide(
          color: patchLeft ? Colors.blue : noPatchColor,
          width: 4,
        ),
        right: BorderSide(
          color: patchRight ? Colors.blue : noPatchColor,
          width: 4,
        ),
        top: BorderSide(
          color: patchTop ? Colors.blue : noPatchColor,
          width: 4,
        ),
        bottom: BorderSide(
          color: patchBottom ? Colors.blue : noPatchColor,
          width: 4,
        ),
      ),
    );
  }
}

class TilePatcherEditorView extends StatefulWidget {
  const TilePatcherEditorView({
    required this.selection,
    required this.onCancel,
    super.key,
  });

  final TilePatcherSelection selection;
  final VoidCallback onCancel;

  @override
  State<TilePatcherEditorView> createState() => TilePatcherEditorViewState();
}

class TilePatcherEditorViewState extends State<TilePatcherEditorView> {
  late TilePatcherSelection _selection = widget.selection;

  final _gridsizeController = TextEditingController(text: '0');
  final _gridHeightController = TextEditingController(text: '0');
  final _spaceController = TextEditingController(text: '0');

  bool _square = true;

  Offset _hoverGridCursor = Offset.zero;
  Offset _hoverCursor = Offset.zero;
  Size _hoverSize = Size.zero;

  List<Patch> _patches = [];

  void _placePatch() async {
    final patch = Patch.all(
      gridPosition: _hoverGridCursor,
    );

    final existingPatches = _patches.where(
      (element) => element.gridPosition == patch.gridPosition,
    );

    if (existingPatches.isNotEmpty) {
      final value = await NesDialog.show<_PatchEditViewResult>(
        context: context,
        builder: (context) {
          return _PatchEditView(
            patch: existingPatches.first,
          );
        },
      );

      if (value != null) {
        if (value.delete) {
          setState(() {
            _patches = _patches
                .where(
                  (element) => element.gridPosition != patch.gridPosition,
                )
                .toList();
          });
        } else {
          setState(() {
            _patches = _patches.map(
              (element) {
                if (element.gridPosition == patch.gridPosition) {
                  return value.patch;
                } else {
                  return element;
                }
              },
            ).toList();
          });
        }
      }
    } else {
      setState(() {
        _patches = [..._patches, patch];
      });
    }
  }

  Size _gridSize() {
    final gridWidth = double.parse(_gridsizeController.text);
    final gridHeight = _square
        ? double.parse(_gridsizeController.text)
        : double.parse(_gridHeightController.text);
    return Size(gridWidth, gridHeight);
  }

  void _onHover(
      Offset position, double totalViewWidth, double totalViewHeight) {
    final gridSize = _gridSize();
    if (gridSize.width == 0 || gridSize.height == 0) {
      return;
    }

    final scaleX = totalViewWidth / _selection.image.width;
    final scaleY = totalViewHeight / _selection.image.height;

    final scale = math.min(scaleX, scaleY);

    final gridPosition = Offset(
      ((position.dx / scale) ~/ gridSize.width).toDouble(),
      ((position.dy / scale) ~/ gridSize.height).toDouble(),
    );

    setState(() {
      _hoverGridCursor = gridPosition;
      _hoverCursor = Offset(
        gridPosition.dx * (gridSize.width * scale),
        gridPosition.dy * (gridSize.height * scale),
      );
      _hoverSize = Size(
        gridSize.width * scale,
        gridSize.height * scale,
      );
    });
  }

  Future<void> _save() async {
    final imageBytes = await _selection.patch.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final fileName = path.basenameWithoutExtension(_selection.path);
    final dirName = path.dirname(_selection.path);
    final fileExtension = path.extension(_selection.path);

    final patchedFileName = '${fileName}_patched.$fileExtension';
    final patchedFilePath = path.join(dirName, patchedFileName);

    File(patchedFilePath).writeAsBytesSync(imageBytes!.buffer.asUint8List());
  }

  Future<void> _update() async {
    final gridSize = _gridSize();
    final gridWidth = gridSize.width;
    final gridHeight = gridSize.height;

    final space = int.parse(_spaceController.text);
    final newGridWidth = gridWidth + space;
    final newGridHeight = gridHeight + space;

    final image = widget.selection.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = Paint();

    final verticalTiles = (image.height / gridHeight).ceil();
    final horizontalTiles = (image.width / gridWidth).ceil();
    for (double y = 0; y < verticalTiles; y++) {
      for (double x = 0; x < horizontalTiles; x++) {
        final src = Rect.fromLTWH(
          x * gridWidth,
          y * gridHeight,
          gridWidth,
          gridHeight,
        );

        final dst = Rect.fromLTWH(
          x * newGridWidth,
          y * newGridHeight,
          gridWidth,
          gridHeight,
        );

        canvas.drawImageRect(
          image,
          src,
          dst,
          paint,
        );

        final patch = _patches.firstWhere(
          (element) => element.gridPosition == Offset(x, y),
          orElse: () => Patch.none(
            gridPosition: Offset(x, y),
          ),
        );

        // Bottom patch
        if (patch.patchBottom) {
          final bottomPatcherSrc = Rect.fromLTWH(
            x * gridWidth,
            y * gridHeight + gridHeight - 1,
            gridWidth,
            space.toDouble(),
          );

          final bottomPatcherDst = Rect.fromLTWH(
            x * newGridWidth,
            y * newGridHeight + gridHeight,
            newGridWidth,
            space.toDouble(),
          );

          canvas.drawImageRect(
            image,
            bottomPatcherSrc,
            bottomPatcherDst,
            paint,
          );
        }

        if (patch.patchRight) {
          // Right patch
          final rightPatcherSrc = Rect.fromLTWH(
            x * gridWidth + gridWidth - 1,
            y * gridHeight,
            space.toDouble(),
            gridHeight,
          );

          final rightPatcherDst = Rect.fromLTWH(
            x * newGridWidth + gridWidth,
            y * newGridHeight,
            space.toDouble(),
            newGridHeight,
          );

          canvas.drawImageRect(
            image,
            rightPatcherSrc,
            rightPatcherDst,
            paint,
          );
        }

        if (patch.patchTop) {
          // Top patch
          final topPatcherSrc = Rect.fromLTWH(
            x * gridWidth,
            y * gridHeight - space,
            gridWidth,
            space.toDouble(),
          );

          final topPatcherDst = Rect.fromLTWH(
            x * newGridWidth,
            y * newGridHeight - space,
            newGridWidth,
            space.toDouble(),
          );

          canvas.drawImageRect(
            image,
            topPatcherSrc,
            topPatcherDst,
            paint,
          );
        }

        if (patch.patchLeft) {
          // Left patch
          final leftPatcherSrc = Rect.fromLTWH(
            x * gridWidth - space,
            y * gridHeight,
            space.toDouble(),
            gridHeight,
          );

          final leftPatcherDst = Rect.fromLTWH(
            x * newGridWidth - space,
            y * newGridHeight,
            space.toDouble(),
            newGridHeight,
          );

          canvas.drawImageRect(
            image,
            leftPatcherSrc,
            leftPatcherDst,
            paint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    final newImage = await picture.toImage(
      (horizontalTiles * newGridWidth).toInt() - 1,
      (verticalTiles * newGridHeight).toInt() - 1,
    );

    setState(() {
      _selection = TilePatcherSelection(
        path: widget.selection.path,
        image: widget.selection.image,
        patch: newImage,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              NesButton(
                type: NesButtonType.primary,
                onPressed: _update,
                child: const Text('Update'),
              ),
              const SizedBox(height: 8),
              NesButton(
                type: NesButtonType.success,
                onPressed: _save,
                child: const Text('Save'),
              ),
              const SizedBox(height: 8),
              NesButton(
                type: NesButtonType.warning,
                onPressed: widget.onCancel,
                child: const Text('Close'),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Square'),
              Switch(
                value: _square,
                onChanged: (value) {
                  setState(() {
                    _square = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _spaceController,
                  decoration: const InputDecoration(
                    label: Text('Spacing'),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _gridsizeController,
                  decoration: InputDecoration(
                    label: Text(_square ? 'Grid Size' : 'Grid Width'),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!_square) ...[
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _gridHeightController,
                    decoration: const InputDecoration(
                      label: Text('Grid Height'),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 8),
          const VerticalDivider(),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Listener(
                              onPointerHover: (event) {
                                _onHover(
                                  event.localPosition,
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );
                              },
                              onPointerUp: (_) {
                                _placePatch();
                              },
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: RawImage(
                                      image: _selection.image,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.topCenter,
                                      filterQuality: FilterQuality.none,
                                    ),
                                  ),
                                  for (final patch in _patches)
                                    Positioned(
                                      left: patch.gridPosition.dx *
                                          _hoverSize.width,
                                      top: patch.gridPosition.dy *
                                          _hoverSize.height,
                                      child: DecoratedBox(
                                        decoration: patch.toBoxDecoration(),
                                        child: SizedBox(
                                          width: _hoverSize.width,
                                          height: _hoverSize.height,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                      left: _hoverCursor.dx,
                                      top: _hoverCursor.dy,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                            width: 2,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: _hoverSize.width,
                                          height: _hoverSize.height,
                                        ),
                                      )),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Text(
                        'Original: ${_selection.image.width}x${_selection.image.height}',
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: RawImage(
                          image: _selection.patch,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                      Text(
                        'Patch: ${_selection.patch.width}x${_selection.patch.height}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatchEditViewResult {
  const _PatchEditViewResult({
    required this.patch,
    required this.delete,
  });

  final Patch patch;
  final bool delete;
}

class _PatchEditView extends StatefulWidget {
  const _PatchEditView({
    required this.patch,
  });

  final Patch patch;

  @override
  State<_PatchEditView> createState() => _PatchEditViewState();
}

class _PatchEditViewState extends State<_PatchEditView> {
  late var _patch = widget.patch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 450,
      height: 380,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  const Text('Preview'),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: _patch.toBoxDecoration(),
                    child: const SizedBox(
                      width: 120,
                      height: 120,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 48),
              SizedBox(
                width: 250,
                child: Column(
                  children: [
                    Row(
                      spacing: 16,
                      children: [
                        NesCheckBox(
                          value: _patch.patchTop,
                          onChange: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchTop: value);
                            });
                          },
                        ),
                        const Text('Patch Top'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 16,
                      children: [
                        NesCheckBox(
                          value: _patch.patchBottom,
                          onChange: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchBottom: value);
                            });
                          },
                        ),
                        const Text('Patch Bottom'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 16,
                      children: [
                        NesCheckBox(
                          value: _patch.patchLeft,
                          onChange: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchLeft: value);
                            });
                          },
                        ),
                        const Text('Patch Left'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 16,
                      children: [
                        NesCheckBox(
                          value: _patch.patchRight,
                          onChange: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchRight: value);
                            });
                          },
                        ),
                        const Text('Patch Right'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  NesButton(
                    type: NesButtonType.primary,
                    onPressed: () {
                      Navigator.of(context).pop(
                        _PatchEditViewResult(
                          patch: _patch,
                          delete: false,
                        ),
                      );
                    },
                    child: const Text('Update'),
                  ),
                  NesButton(
                    type: NesButtonType.error,
                    onPressed: () {
                      Navigator.of(context).pop(
                        _PatchEditViewResult(
                          patch: widget.patch,
                          delete: true,
                        ),
                      );
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              NesButton(
                type: NesButtonType.warning,
                onPressed: () {
                  Navigator.of(context).pop(
                    _PatchEditViewResult(
                      patch: widget.patch,
                      delete: false,
                    ),
                  );
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
