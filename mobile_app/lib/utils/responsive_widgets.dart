import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// A responsive wrapper scaffold that automatically adjusts padding and constraints
class ResponsiveScaffold extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final bool useSafeArea;
  final bool useScrollView;

  const ResponsiveScaffold({
    Key? key,
    required this.child,
    this.backgroundColor,
    this.appBar,
    this.useSafeArea = true,
    this.useScrollView = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (useScrollView) {
      content = SingleChildScrollView(
        child: content,
      );
    }

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    // Add responsive padding and max width constraint
    content = Padding(
      padding: ResponsiveHelper.responsivePadding(
        context,
        mobileValue: 16,
        tabletValue: 24,
        desktopValue: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.maxContentWidth(context),
          ),
          child: content,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: appBar,
      body: content,
    );
  }
}

/// Responsive text helper class
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final double? mobileSize;
  final double? tabletSize;
  final double? desktopSize;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.baseStyle,
    this.mobileSize,
    this.tabletSize,
    this.desktopSize,
    this.maxLines,
    this.overflow,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveHelper.responsiveFontSize(
      context,
      mobileSize: mobileSize ?? 14,
      tabletSize: tabletSize ?? 15,
      desktopSize: desktopSize ?? 16,
    );

    return Text(
      text,
      style: (baseStyle ?? const TextStyle()).copyWith(fontSize: fontSize),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// Responsive heading helper
class ResponsiveHeading extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final double? mobileSize;
  final double? tabletSize;
  final double? desktopSize;

  const ResponsiveHeading(
    this.text, {
    Key? key,
    this.baseStyle,
    this.mobileSize,
    this.tabletSize,
    this.desktopSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveHelper.headingSize(
      context,
      mobileSize: mobileSize ?? 24,
      tabletSize: tabletSize ?? 28,
      desktopSize: desktopSize ?? 32,
    );

    return Text(
      text,
      style: (baseStyle ?? const TextStyle(fontWeight: FontWeight.bold))
          .copyWith(fontSize: fontSize),
    );
  }
}

/// Responsive SizedBox helper
class ResponsiveSizedBox extends StatelessWidget {
  final Axis axis;
  final double mobileValue;
  final double? tabletValue;
  final double? desktopValue;

  const ResponsiveSizedBox.vertical({
    Key? key,
    this.mobileValue = 16,
    this.tabletValue,
    this.desktopValue,
  })  : axis = Axis.vertical,
        super(key: key);

  const ResponsiveSizedBox.horizontal({
    Key? key,
    this.mobileValue = 16,
    this.tabletValue,
    this.desktopValue,
  })  : axis = Axis.horizontal,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final value = ResponsiveHelper.spacing(context, mobileValue);

    if (axis == Axis.vertical) {
      return SizedBox(height: value);
    } else {
      return SizedBox(width: value);
    }
  }
}
