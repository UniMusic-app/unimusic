import "dart:io";

bool get isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

bool get isMobile => Platform.isAndroid || Platform.isIOS;
