import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MonthlyRetrospectivePager extends StatefulWidget {
  const MonthlyRetrospectivePager({
    super.key,
    required this.month,
    required this.pages,
    required this.pageBuilder,
  });

  final DateTime month;
  final List<String> pages;
  final Widget Function(String page) pageBuilder;

  @override
  State<MonthlyRetrospectivePager> createState() =>
      _MonthlyRetrospectivePagerState();
}

class _MonthlyRetrospectivePagerState extends State<MonthlyRetrospectivePager> {
  late String _selected = widget.pages.first;
  PageController _controller = PageController(keepPage: false);

  @override
  void didUpdateWidget(MonthlyRetrospectivePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        !listEquals(oldWidget.pages, widget.pages)) {
      if (oldWidget.month != widget.month ||
          !widget.pages.contains(_selected)) {
        _selected = widget.pages.first;
      }
      final previous = _controller;
      _controller = PageController(
        initialPage: widget.pages.indexOf(_selected),
        keepPage: false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: PageView.builder(
          key: ValueKey('${widget.month}:${widget.pages.join('|')}'),
          controller: _controller,
          allowImplicitScrolling: true,
          itemCount: widget.pages.length,
          onPageChanged: (index) {
            FocusScope.of(context).unfocus();
            setState(() => _selected = widget.pages[index]);
          },
          itemBuilder: (context, index) =>
              widget.pageBuilder(widget.pages[index]),
        ),
      ),
      if (widget.pages.length > 1)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < widget.pages.length; index++)
                  Semantics(
                    label:
                        '${widget.pages[index]}, ${index + 1}/${widget.pages.length}페이지',
                    button: true,
                    selected: widget.pages[index] == _selected,
                    child: InkResponse(
                      key: Key('monthly-page-indicator-$index'),
                      radius: 22,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: SizedBox.square(
                        dimension: 44,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: widget.pages[index] == _selected ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: widget.pages[index] == _selected
                                  ? AppColors.brandAccent
                                  : AppColors.textMuted.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
