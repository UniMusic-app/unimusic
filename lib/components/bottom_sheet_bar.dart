import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

class BottomSheetBarNotification extends Notification {
  final double value;
  final Duration duration;

  const BottomSheetBarNotification({required this.value, required this.duration});
}

class BottomSheetBar extends StatefulWidget {
  final Widget sheet;
  final Widget bar;
  const BottomSheetBar({super.key, required this.sheet, required this.bar});

  @override
  State<BottomSheetBar> createState() => BottomSheetBarState();
}

class BottomSheetBarState extends State<BottomSheetBar> {
  final GlobalKey sheetKey = GlobalKey();
  final GlobalKey barKey = GlobalKey();

  Duration? duration;
  double value = 0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<BottomSheetBarNotification>(
      onNotification: (notification) {
        final phase = SchedulerBinding.instance.schedulerPhase;
        if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
          // Safe to immediately set state
          setState(() {
            value = notification.value;
            duration = notification.duration;
          });
        } else {
          // Defer until after this frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                value = notification.value;
                duration = notification.duration;
              });
            }
          });
        }

        return true;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(key: sheetKey, child: widget.sheet),
          AnimatedSize(
            duration: duration ?? Duration.zero,
            curve: Curves.easeOutSine,
            child: AnimatedOpacity(
              duration: duration ?? Duration.zero,
              curve: Curves.easeOutSine,
              opacity: 1 - value,
              child: SizedBox(height: value > 0 ? 0 : null, key: barKey, child: widget.bar),
            ),
          ),
        ],
      ),
    );
  }
}
