import 'package:flutter/material.dart';

class CustomSliverAppBar extends StatelessWidget {
  final bool isMainView;
  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final VoidCallback? onBackButtonPressed;

  const CustomSliverAppBar({
    super.key,
    required this.isMainView,
    required this.title,
    this.actions,
    this.bottom,
    this.onBackButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100.0,
      automaticallyImplyLeading: !isMainView,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          bottom: bottom != null ? 16.0 : 14.0,
          left: isMainView ? 20.0 : 55.0,
        ),
        title: title,
      ),
      leading: isMainView
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackButtonPressed ?? () => Navigator.of(context).pop(),
            ),      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
            : Colors.transparent,
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
