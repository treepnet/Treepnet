part of messenger_chat;
class _CircularLoading extends StatefulWidget {
  const _CircularLoading({required this.color, this.value = 0, this.strokeWidth = 4});

  final Color color;
  final double value;
  final double strokeWidth;

  @override
  State<_CircularLoading> createState() => _CircularLoadingState();
}

class _CircularLoadingState extends State<_CircularLoading> {
  @override
  Widget build(BuildContext context) => CircularProgressIndicator(
    value: widget.value == 0 || widget.value == 1 ? null : widget.value,
    color: widget.color,
    strokeWidth: widget.strokeWidth,
    strokeCap: StrokeCap.round,
  );
}
