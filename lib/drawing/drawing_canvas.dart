import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/drawing_stroke.dart';

/// A customizable drawing canvas with undo/redo support.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.initialStrokes,
    required this.onStrokesChanged,
    this.backgroundColor = Colors.white,
    this.showGrid = false,
    this.gridColor = const Color(0xFFE0E0E0),
    this.gridSpacing = 20.0,
    this.defaultColor = Colors.black,
    this.defaultWidth = 2.0,
    this.minWidth = 0.5,
    this.maxWidth = 20.0,
    this.enableEraser = true,
  });

  final List<DrawingStroke> initialStrokes;
  final ValueChanged<List<DrawingStroke>> onStrokesChanged;
  final Color backgroundColor;
  final bool showGrid;
  final Color gridColor;
  final double gridSpacing;
  final Color defaultColor;
  final double defaultWidth;
  final double minWidth;
  final double maxWidth;
  final bool enableEraser;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();

  // Public methods to control the canvas from parent
  void undo() => _DrawingCanvasState._undoStatic(this);
  void redo() => _DrawingCanvasState._redoStatic(this);
  void clear() => _DrawingCanvasState._clearStatic(this);

  // Getters for current state
  Color get currentColor => _DrawingCanvasState._getCurrentColorStatic(this);
  double get currentWidth => _DrawingCanvasState._getCurrentWidthStatic(this);
  bool get isEraserMode => _DrawingCanvasState._getIsEraserModeStatic(this);

  // Setters for external control
  set currentColor(Color color) => _DrawingCanvasState._setCurrentColorStatic(this, color);
  set currentWidth(double width) => _DrawingCanvasState._setCurrentWidthStatic(this, width);
  set isEraserMode(bool enabled) => _DrawingCanvasState._setIsEraserModeStatic(this, enabled);
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  late List<DrawingStroke> _strokes;
  late List<List<DrawingStroke>> _undoStack;
  late List<List<DrawingStroke>> _redoStack;

  Color _currentColor = Colors.black;
  double _currentWidth = 2.0;
  bool _isEraserMode = false;

  @override
  void initState() {
    super.initState();
    _strokes = List.from(widget.initialStrokes);
    _undoStack = [];
    _redoStack = [];
    _currentColor = widget.defaultColor;
    _currentWidth = widget.defaultWidth;
  }

  void _saveState() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _notifyChanged() {
    widget.onStrokesChanged(List.unmodifiable(_strokes));
    setState(() {});
  }

  void _addStroke(DrawingStroke stroke) {
    _saveState();
    setState(() {
      _strokes.add(stroke);
    });
    _notifyChanged();
  }

  void _removeLastStroke() {
    if (_strokes.isEmpty) return;
    _saveState();
    setState(() {
      _strokes.removeLast();
    });
    _notifyChanged();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_strokes));
    setState(() {
      _strokes = _undoStack.removeLast();
    });
    _notifyChanged();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_strokes));
    setState(() {
      _strokes = _redoStack.removeLast();
    });
    _notifyChanged();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _saveState();
    setState(() {
      _strokes.clear();
    });
    _notifyChanged();
  }

  void _handlePanStart(DragStartDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    final stroke = DrawingStroke(
      id: null,
      noteId: 0, // Will be set when saving
      points: [localPosition],
      color: _isEraserMode ? Colors.transparent : _currentColor,
      width: _isEraserMode ? _currentWidth * 3 : _currentWidth,
      createdAt: DateTime.now(),
    );

    setState(() {
      _strokes.add(stroke);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_strokes.isEmpty) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      final lastStroke = _strokes.last;
      final updatedPoints = List<Offset>.from(lastStroke.points)..add(localPosition);
      _strokes[_strokes.length - 1] = lastStroke.copyWith(points: updatedPoints);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    widget.onStrokesChanged(List.unmodifiable(_strokes));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Container(
        color: widget.backgroundColor,
        child: CustomPaint(
          painter: _DrawingPainter(
            strokes: _strokes,
            showGrid: widget.showGrid,
            gridColor: widget.gridColor,
            gridSpacing: widget.gridSpacing,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  // Static methods for external access via GlobalKey
  static void _undoStatic(DrawingCanvas canvas) {
    final state = canvas.state as _DrawingCanvasState?;
    state?.undo();
  }

  static void _redoStatic(DrawingCanvas canvas) {
    final state = canvas.state as _DrawingCanvasState?;
    state?.redo();
  }

  static void _clearStatic(DrawingCanvas canvas) {
    final state = canvas.state as _DrawingCanvasState?;
    state?.clear();
  }

  static Color _getCurrentColorStatic(DrawingCanvas canvas) {
    final state = canvas.state as _DrawingCanvasState?;
    return state?._currentColor ?? Colors.black;
  }

  static double _getCurrentWidthStatic(DrawingCanvas canvas) {
    final state = canvas.state as _DrawingCanvasState?;
    return state?._currentWidth ?? 2.0;
  }

  static bool _getIsEraserModeStatic(DrawingCanvas canvas) {
    final state = canvas.state as _DrawingCanvasState?;
    return state?._isEraserMode ?? false;
  }

  static void _setCurrentColorStatic(DrawingCanvas canvas, Color color) {
    final state = canvas.state as _DrawingCanvasState?;
    if (state != null) {
      state.setState(() {
        state._currentColor = color;
        state._isEraserMode = false;
      });
    }
  }

  static void _setCurrentWidthStatic(DrawingCanvas canvas, double width) {
    final state = canvas.state as _DrawingCanvasState?;
    if (state != nil) {
      state.setState(() {
        state._currentWidth = width.clamp(widget.minWidth, widget.maxWidth);
      });
    }
  }

  static void _setIsEraserModeStatic(DrawingCanvas canvas, bool enabled) {
    final state = canvas.state as _DrawingCanvasState?;
    if (state != nil) {
      state.setState(() {
        state._isEraserMode = enabled;
      });
    }
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final bool showGrid;
  final Color gridColor;
  final double gridSpacing;

  _DrawingPainter({
    required this.strokes,
    required this.showGrid,
    required this.gridColor,
    required this.gridSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    if (showGrid) {
      final paint = Paint()
        ..color = gridColor
        ..strokeWidth = 0.5;

      for (double x = 0; x < size.width; x += gridSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y < size.height; y += gridSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    // Draw strokes
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.color == Colors.transparent) {
        // Eraser mode - use blend mode to erase
        paint.blendMode = BlendMode.clear;
      }

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final prevPoint = stroke.points[i - 1];
        // Smooth the path using quadratic bezier
        final midPoint = Offset(
          (prevPoint.dx + point.dx) / 2,
          (prevPoint.dy + point.dy) / 2,
        );
        path.quadraticBezierTo(prevPoint.dx, prevPoint.dy, midPoint.dx, midPoint.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _DrawingPainter &&
        oldDelegate.strokes != strokes &&
        oldDelegate.showGrid != showGrid &&
        oldDelegate.gridColor != gridColor &&
        oldDelegate.gridSpacing != gridSpacing;
  }
}