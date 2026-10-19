import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class MonthlyOverviewLayout extends MultiChildRenderObjectWidget {
  MonthlyOverviewLayout({
    super.key,
    required this.viewportHeight,
    this.spaceAbove = 0,
    required Widget information,
    Widget? photos,
  }) : hasPhotos = photos != null,
       super(children: [photos ?? const SizedBox.shrink(), information]);

  final double viewportHeight;
  final double spaceAbove;
  final bool hasPhotos;

  @override
  RenderMonthlyOverviewLayout createRenderObject(BuildContext context) =>
      RenderMonthlyOverviewLayout(viewportHeight, hasPhotos, spaceAbove);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMonthlyOverviewLayout renderObject,
  ) => renderObject.update(viewportHeight, hasPhotos, spaceAbove);
}

class _OverviewParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMonthlyOverviewLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverviewParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverviewParentData> {
  RenderMonthlyOverviewLayout(
    this._viewportHeight,
    this._hasPhotos,
    this._spaceAbove,
  );

  double _viewportHeight;
  bool _hasPhotos;
  double _spaceAbove;

  void update(double viewportHeight, bool hasPhotos, double spaceAbove) {
    if (_viewportHeight == viewportHeight &&
        _hasPhotos == hasPhotos &&
        _spaceAbove == spaceAbove) {
      return;
    }
    _viewportHeight = viewportHeight;
    _hasPhotos = hasPhotos;
    _spaceAbove = spaceAbove;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverviewParentData) {
      child.parentData = _OverviewParentData();
    }
  }

  @override
  void performLayout() {
    final photos = firstChild!;
    final information = lastChild!;
    final width = constraints.maxWidth;
    information.layout(
      BoxConstraints.tightFor(width: width),
      parentUsesSize: true,
    );
    final verticalSpacing = _hasPhotos ? 32.0 - _spaceAbove : 0.0;
    final photoAreaHeight = _hasPhotos
        ? math.max(
            160.0,
            _viewportHeight - information.size.height - verticalSpacing,
          )
        : 0.0;
    photos.layout(
      BoxConstraints(maxWidth: width, maxHeight: photoAreaHeight),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(
        width,
        math.max(
          _viewportHeight,
          photoAreaHeight + verticalSpacing + information.size.height,
        ),
      ),
    );
    (photos.parentData! as _OverviewParentData).offset = Offset(
      (width - photos.size.width) / 2,
      _hasPhotos
          ? (size.height -
                    information.size.height -
                    _spaceAbove -
                    photos.size.height) /
                2
          : 0,
    );
    (information.parentData! as _OverviewParentData).offset = Offset(
      0,
      size.height - information.size.height,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
