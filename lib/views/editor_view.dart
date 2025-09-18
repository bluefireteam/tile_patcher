import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tile_patcher/models/models.dart';

extension on Patch {
  BoxDecoration toBoxDecoration() {
    final noPatchColor = Colors.blue.withOpacity(0.2);
    return BoxDecoration(
      border: Border(
        left: BorderSide(
          color: patchLeft ? Colors.blue : noPatchColor,
          width: 2,
        ),
        right: BorderSide(
          color: patchRight ? Colors.blue : noPatchColor,
          width: 2,
        ),
        top: BorderSide(
          color: patchTop ? Colors.blue : noPatchColor,
          width: 2,
        ),
        bottom: BorderSide(
          color: patchBottom ? Colors.blue : noPatchColor,
          width: 2,
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

  // Rectangle selection state
  bool _rectangleSelectMode = false;
  Offset? _rectSelectStart;
  Offset? _rectSelectEnd;

  Rect? get _selectedRect {
    if (_rectSelectStart == null || _rectSelectEnd == null) return null;
    final start = _rectSelectStart!;
    final end = _rectSelectEnd!;
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final right = math.max(start.dx, end.dx);
    final bottom = math.max(start.dy, end.dy);
    return Rect.fromLTRB(left, top, right + 1, bottom + 1);
  }

  void _placePatch() async {
    final patch = Patch.all(
      gridPosition: _hoverGridCursor,
    );

    final existingPatches = _patches.where(
      (element) => element.gridPosition == patch.gridPosition,
    );

    if (existingPatches.isNotEmpty) {
      final value = await showDialog<_PatchEditViewResult>(
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
    try {
      final gridWidth = double.parse(_gridsizeController.text);
      final gridHeight = _square
          ? double.parse(_gridsizeController.text)
          : double.parse(_gridHeightController.text);

      return Size(gridWidth, gridHeight);
    } catch (e) {
      return Size.zero;
    }
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

  void _selectAll() {
    final gridSize = _gridSize();
    if (gridSize.width == 0 || gridSize.height == 0) {
      return;
    }

    final image = widget.selection.image;
    final verticalTiles = (image.height / gridSize.height).ceil();
    final horizontalTiles = (image.width / gridSize.width).ceil();

    final allPatches = <Patch>[];
    for (double y = 0; y < verticalTiles; y++) {
      for (double x = 0; x < horizontalTiles; x++) {
        final gridPosition = Offset(x, y);
        allPatches.add(Patch.all(gridPosition: gridPosition));
      }
    }

    setState(() {
      _patches = allPatches;
    });
  }

  void _removeBorder() {
    final gridSize = _gridSize();
    if (gridSize.width == 0 || gridSize.height == 0) {
      return;
    }

    final image = widget.selection.image;
    final verticalTiles = (image.height / gridSize.height).ceil();
    final horizontalTiles = (image.width / gridSize.width).ceil();

    final updatedPatches = _patches.map((patch) {
      final x = patch.gridPosition.dx;
      final y = patch.gridPosition.dy;

      // Determine which borders should be removed based on position
      final isLeftBorder = x == 0;
      final isRightBorder = x == horizontalTiles - 1;
      final isTopBorder = y == 0;
      final isBottomBorder = y == verticalTiles - 1;

      return patch.copyWith(
        patchLeft: isLeftBorder ? false : patch.patchLeft,
        patchRight: isRightBorder ? false : patch.patchRight,
        patchTop: isTopBorder ? false : patch.patchTop,
        patchBottom: isBottomBorder ? false : patch.patchBottom,
      );
    }).toList();

    setState(() {
      _patches = updatedPatches;
    });
  }

  void _removeBorderRect() {
    if (_selectedRect == null) return;

    final rect = _selectedRect!;
    final updatedPatches = _patches.map((patch) {
      final x = patch.gridPosition.dx;
      final y = patch.gridPosition.dy;

      // Only modify patches within the selected rectangle
      if (x < rect.left ||
          x >= rect.right ||
          y < rect.top ||
          y >= rect.bottom) {
        return patch;
      }

      // Determine which borders should be removed based on position within the rectangle
      final isLeftBorder = x == rect.left;
      final isRightBorder = x == rect.right - 1;
      final isTopBorder = y == rect.top;
      final isBottomBorder = y == rect.bottom - 1;

      return patch.copyWith(
        patchLeft: isLeftBorder ? false : patch.patchLeft,
        patchRight: isRightBorder ? false : patch.patchRight,
        patchTop: isTopBorder ? false : patch.patchTop,
        patchBottom: isBottomBorder ? false : patch.patchBottom,
      );
    }).toList();

    setState(() {
      _patches = updatedPatches;
    });
  }

  Future<void> _save() async {
    final imageBytes = await _selection.patch.toByteData(
      format: ui.ImageByteFormat.png,
    );

    File(_selection.path).writeAsBytesSync(imageBytes!.buffer.asUint8List());
  }

  Future<void> _update() async {
    final gridSize = _gridSize();
    final gridWidth = gridSize.width;
    final gridHeight = gridSize.height;

    // Validate grid size
    if (gridWidth <= 0 || gridHeight <= 0) {
      return;
    }

    final space = int.parse(_spaceController.text);
    if (space < 0) {
      return;
    }

    final newGridWidth = gridWidth + space;
    final newGridHeight = gridHeight + space;

    final image = widget.selection.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = Paint();

    final verticalTiles = (image.height / gridHeight).ceil();
    final horizontalTiles = (image.width / gridWidth).ceil();

    // Validate that we have tiles to process
    if (verticalTiles <= 0 || horizontalTiles <= 0) {
      return;
    }

    for (double y = 0; y < verticalTiles; y++) {
      for (double x = 0; x < horizontalTiles; x++) {
        final src = Rect.fromLTWH(
          x * gridWidth,
          y * gridHeight,
          math.min(gridWidth, image.width - x * gridWidth),
          math.min(gridHeight, image.height - y * gridHeight),
        );

        final dst = Rect.fromLTWH(
          x * newGridWidth,
          y * newGridHeight,
          src.width,
          src.height,
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
        if (patch.patchBottom && space > 0) {
          final bottomSrcY = math
              .min(y * gridHeight + gridHeight - 1, image.height - 1)
              .toDouble();
          final bottomSrcHeight =
              math.min(space.toDouble(), image.height - bottomSrcY);

          if (bottomSrcHeight > 0) {
            final bottomPatcherSrc = Rect.fromLTWH(
              x * gridWidth,
              bottomSrcY,
              math.min(gridWidth, image.width - x * gridWidth),
              bottomSrcHeight,
            );

            final bottomPatcherDst = Rect.fromLTWH(
              x * newGridWidth,
              y * newGridHeight + src.height,
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
        }

        if (patch.patchRight && space > 0) {
          // Right patch
          final rightSrcX = math
              .min(x * gridWidth + gridWidth - 1, image.width - 1)
              .toDouble();
          final rightSrcWidth =
              math.min(space.toDouble(), image.width - rightSrcX);

          if (rightSrcWidth > 0) {
            final rightPatcherSrc = Rect.fromLTWH(
              rightSrcX,
              y * gridHeight,
              rightSrcWidth,
              math.min(gridHeight, image.height - y * gridHeight),
            );

            final rightPatcherDst = Rect.fromLTWH(
              x * newGridWidth + src.width,
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
        }

        if (patch.patchTop && space > 0 && y > 0) {
          // Top patch - only if not on the first row
          final topSrcY = math.max(0, y * gridHeight - space).toDouble();
          final topSrcHeight = math.min(space.toDouble(), y * gridHeight);

          if (topSrcHeight > 0) {
            final topPatcherSrc = Rect.fromLTWH(
              x * gridWidth,
              topSrcY,
              math.min(gridWidth, image.width - x * gridWidth),
              topSrcHeight,
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
        }

        if (patch.patchLeft && space > 0 && x > 0) {
          // Left patch - only if not on the first column
          final leftSrcX = math.max(0, x * gridWidth - space).toDouble();
          final leftSrcWidth = math.min(space.toDouble(), x * gridWidth);

          if (leftSrcWidth > 0) {
            final leftPatcherSrc = Rect.fromLTWH(
              leftSrcX,
              y * gridHeight,
              leftSrcWidth,
              math.min(gridHeight, image.height - y * gridHeight),
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
    }

    final picture = recorder.endRecording();

    // Calculate final image dimensions and ensure they're positive
    final finalWidth = math.max(1, (horizontalTiles * newGridWidth).toInt());
    final finalHeight = math.max(1, (verticalTiles * newGridHeight).toInt());

    try {
      final newImage = await picture.toImage(finalWidth, finalHeight);

      setState(() {
        _selection = TilePatcherSelection(
          path: widget.selection.path,
          image: widget.selection.image,
          patch: newImage,
        );
      });
    } catch (e) {}
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
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _update();
                  } catch (e) {}
                },
                child: const Text('Update'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _save();
                  } catch (e) {}
                },
                child: const Text('Save'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.onCancel,
                child: const Text('Close'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _selectAll,
                child: const Text('Select All'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _rectangleSelectMode = !_rectangleSelectMode;
                    _rectSelectStart = null;
                    _rectSelectEnd = null;
                  });
                },
                child: Text(_rectangleSelectMode
                    ? 'Exit Rect Select'
                    : 'Rectangle Select'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _rectangleSelectMode && _selectedRect != null
                    ? _removeBorderRect
                    : null,
                child: const Text('Remove Border (Rect)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _removeBorder,
                child: const Text('Remove Border (All)'),
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
                width: 80,
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
                width: 80,
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
                                if (!_rectangleSelectMode) {
                                  _onHover(
                                    event.localPosition,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                }
                              },
                              onPointerDown: (event) {
                                if (_rectangleSelectMode) {
                                  final gridSize = _gridSize();
                                  if (gridSize.width <= 0 ||
                                      gridSize.height <= 0) return;

                                  final scaleX = constraints.maxWidth /
                                      _selection.image.width;
                                  final scaleY = constraints.maxHeight /
                                      _selection.image.height;
                                  final scale = math.min(scaleX, scaleY);
                                  final pos = event.localPosition;
                                  final gridX =
                                      (pos.dx / scale ~/ gridSize.width)
                                          .toDouble();
                                  final gridY =
                                      (pos.dy / scale ~/ gridSize.height)
                                          .toDouble();

                                  setState(() {
                                    _rectSelectStart = Offset(gridX, gridY);
                                    _rectSelectEnd = Offset(gridX, gridY);
                                  });
                                }
                              },
                              onPointerMove: (event) {
                                if (_rectangleSelectMode &&
                                    _rectSelectStart != null) {
                                  final gridSize = _gridSize();
                                  if (gridSize.width <= 0 ||
                                      gridSize.height <= 0) return;

                                  final scaleX = constraints.maxWidth /
                                      _selection.image.width;
                                  final scaleY = constraints.maxHeight /
                                      _selection.image.height;
                                  final scale = math.min(scaleX, scaleY);
                                  final pos = event.localPosition;
                                  final gridX =
                                      (pos.dx / scale ~/ gridSize.width)
                                          .toDouble();
                                  final gridY =
                                      (pos.dy / scale ~/ gridSize.height)
                                          .toDouble();

                                  setState(() {
                                    _rectSelectEnd = Offset(gridX, gridY);
                                  });
                                }
                              },
                              onPointerUp: (event) {
                                if (_rectangleSelectMode &&
                                    _rectSelectStart != null) {
                                  final gridSize = _gridSize();
                                  if (gridSize.width <= 0 ||
                                      gridSize.height <= 0) return;

                                  final scaleX = constraints.maxWidth /
                                      _selection.image.width;
                                  final scaleY = constraints.maxHeight /
                                      _selection.image.height;
                                  final scale = math.min(scaleX, scaleY);
                                  final pos = event.localPosition;
                                  final gridX =
                                      (pos.dx / scale ~/ gridSize.width)
                                          .toDouble();
                                  final gridY =
                                      (pos.dy / scale ~/ gridSize.height)
                                          .toDouble();

                                  setState(() {
                                    _rectSelectEnd = Offset(gridX, gridY);
                                  });
                                } else {
                                  _placePatch();
                                }
                              },
                              child: Stack(
                                children: [
                                  RawImage(
                                    image: _selection.image,
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
                                  // Rectangle selection highlight
                                  if (_rectangleSelectMode &&
                                      _selectedRect != null)
                                    Positioned(
                                      left: _selectedRect!.left *
                                          _hoverSize.width,
                                      top: _selectedRect!.top *
                                          _hoverSize.height,
                                      child: Container(
                                        width: (_selectedRect!.width) *
                                            _hoverSize.width,
                                        height: (_selectedRect!.height) *
                                            _hoverSize.height,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.red, width: 3),
                                          color: Colors.red.withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  // Hover cursor (only show when not in rectangle select mode)
                                  if (!_rectangleSelectMode)
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
                        child: RawImage(image: _selection.patch),
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
    return Dialog(
      child: SizedBox(
        width: 400,
        height: 440,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
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
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 48),
                Column(
                  children: [
                    Row(
                      children: [
                        const Text('Patch Top'),
                        Switch(
                          value: _patch.patchTop,
                          onChanged: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchTop: value);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Patch Bottom'),
                        Switch(
                          value: _patch.patchBottom,
                          onChanged: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchBottom: value);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Patch Left'),
                        Switch(
                          value: _patch.patchLeft,
                          onChanged: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchLeft: value);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Patch Right'),
                        Switch(
                          value: _patch.patchRight,
                          onChanged: (value) {
                            setState(() {
                              _patch = _patch.copyWith(patchRight: value);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
            Column(
              children: [
                ElevatedButton(
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
                const SizedBox(height: 8),
                ElevatedButton(
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
                const SizedBox(height: 8),
                ElevatedButton(
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
