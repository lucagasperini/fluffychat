import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/string_color.dart';
import 'matrix.dart';

class Avatar extends StatelessWidget {
  final Uri? mxContent;
  final String? name;
  final double size;
  final void Function()? onTap;
  static const double defaultSize = 44;
  final Client? client;
  final double fontSize;

  const Avatar({
    this.mxContent,
    this.name,
    this.size = defaultSize,
    this.onTap,
    this.client,
    this.fontSize = 18,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final src = mxContent?.getThumbnail(
      client ?? Matrix.of(context).client,
      width: size * MediaQuery.of(context).devicePixelRatio,
      height: size * MediaQuery.of(context).devicePixelRatio,
    );
    var fallbackLetters = '@';
    final name = this.name;
    if (name != null) {
      if (name.runes.length >= 2) {
        fallbackLetters = String.fromCharCodes(name.runes, 0, 2);
      } else if (name.runes.length == 1) {
        fallbackLetters = name;
      }
    }
    final noPic = mxContent == null ||
        mxContent.toString().isEmpty ||
        mxContent.toString() == 'null';
    final nopicColorText = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Colors.black;
    final textWidget = Center(
      child: Text(
        fallbackLetters,
        style: TextStyle(
            color: noPic ? nopicColorText : null,
            fontSize: fontSize,
            fontWeight: FontWeight.bold),
      ),
    );
    final borderRadius = BorderRadius.circular(size / 2);
    final nopicColor = Theme.of(context).brightness == Brightness.light
        ? name?.darkColor
        : name?.lightColor;
    final container = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          width: size,
          height: size,
          color: noPic ? nopicColor : Theme.of(context).secondaryHeaderColor,
          child: noPic
              ? textWidget
              : CachedNetworkImage(
                  imageUrl: src.toString(),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  placeholder: (c, s) => textWidget,
                  errorWidget: (c, s, d) => Stack(
                    children: [
                      textWidget,
                    ],
                  ),
                ),
        ),
      ),
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: container,
    );
  }
}
