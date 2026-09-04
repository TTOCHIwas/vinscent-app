import 'package:flutter/material.dart';

import '../../assets/app_icons.dart';
import '../../presentation/widgets/app_svg_icon.dart';
import '../app_drawing.dart';

class AppDrawingToolbar extends StatelessWidget {
  const AppDrawingToolbar({
    super.key,
    required this.selectedTool,
    required this.isReadOnly,
    required this.canUndo,
    required this.onToolChanged,
    required this.onUndoPressed,
    this.canClear = false,
    this.onClearPressed,
    this.leading,
    this.trailing,
    required this.keyPrefix,
  });

  final AppDrawingTool selectedTool;
  final bool isReadOnly;
  final bool canUndo;
  final bool canClear;
  final ValueChanged<AppDrawingTool> onToolChanged;
  final VoidCallback onUndoPressed;
  final VoidCallback? onClearPressed;
  final Widget? leading;
  final Widget? trailing;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final tools = [
      AppDrawingToolButton(
        buttonKey: ValueKey('$keyPrefix-pen'),
        tooltip: '펜',
        icon: const Icon(Icons.edit),
        isSelected: selectedTool == AppDrawingTool.pen,
        onPressed: isReadOnly ? null : () => onToolChanged(AppDrawingTool.pen),
      ),
      AppDrawingToolButton(
        buttonKey: ValueKey('$keyPrefix-eraser'),
        tooltip: '지우개',
        icon: const AppSvgIcon(AppIcons.eraser),
        isSelected: selectedTool == AppDrawingTool.eraser,
        onPressed: isReadOnly
            ? null
            : () => onToolChanged(AppDrawingTool.eraser),
      ),
      AppDrawingToolButton(
        buttonKey: ValueKey('$keyPrefix-undo'),
        tooltip: '되돌리기',
        icon: const Icon(Icons.undo),
        onPressed: !isReadOnly && canUndo ? onUndoPressed : null,
      ),
      if (onClearPressed != null)
        AppDrawingToolButton(
          buttonKey: ValueKey('$keyPrefix-clear'),
          tooltip: '전체 삭제',
          icon: const Icon(Icons.delete_outline),
          onPressed: !isReadOnly && canClear ? onClearPressed : null,
        ),
    ];
    return Material(
      key: ValueKey('$keyPrefix-toolbar'),
      color: const Color(0x33000000),
      child: SizedBox(
        key: ValueKey('$keyPrefix-top-controls'),
        height: 56,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              ?leading,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gap =
                        ((constraints.maxWidth - tools.length * 48) /
                                (tools.length - 1))
                            .clamp(0.0, 6.0);
                    final row = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < tools.length; i++) ...[
                          if (i > 0) SizedBox(width: gap),
                          tools[i],
                        ],
                      ],
                    );
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: constraints.maxWidth < tools.length * 48
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: row,
                            )
                          : row,
                    );
                  },
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class AppDrawingToolButton extends StatelessWidget {
  const AppDrawingToolButton({
    super.key,
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
  });

  final Key buttonKey;
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        color: isSelected ? Colors.black : Colors.white,
        disabledColor: Colors.white38,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: isSelected ? Colors.white : const Color(0x52000000),
          disabledBackgroundColor: const Color(0x33000000),
          side: BorderSide(color: isSelected ? Colors.white : Colors.white38),
        ),
      ),
    );
  }
}
