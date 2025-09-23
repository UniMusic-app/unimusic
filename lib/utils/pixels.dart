import 'package:flutter/widgets.dart';

extension LogicalPixelsToDevicePixels on double {
  int logicalPixelsToDevicePixels(BuildContext context) {
    return (this * MediaQuery.devicePixelRatioOf(context)).toInt();
  }
}
