part of messenger_chat;

class _ChatToastNotifier extends StatefulWidget {
  const _ChatToastNotifier({required this.controller});

  final ChatController<ChatModel> controller;

  @override
  State<_ChatToastNotifier> createState() => _ChatToastNotifierState();
}

class _ChatToastNotifierState extends State<_ChatToastNotifier>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  ToastData? _currentToast;
  Timer? _hideTimer;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
            reverseCurve: Curves.easeInCirc,
          ),
        );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _subscription = widget.controller.toastStream.listen(_showToast);
  }

  void _showToast(ToastData toast) {
    if (!mounted) return;

    _hideTimer?.cancel();
    setState(() {
      _currentToast = toast;
    });

    _animationController.forward();

    _hideTimer = Timer(toast.duration, () {
      if (mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentToast = null;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentToast == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(opacity: _opacityAnimation, child: child),
        );
      },
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(
                    _currentToast!.type,
                  ).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIcon(_currentToast!.type),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _currentToast!.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(ToastType type) {
    return switch (type) {
      ToastType.error => Colors.redAccent.shade700,
      ToastType.success => Colors.greenAccent.shade700,
      ToastType.warning => Colors.orangeAccent.shade700,
      ToastType.info => const Color(0xFF1F1F1F),
    };
  }

  IconData _getIcon(ToastType type) {
    return switch (type) {
      ToastType.error => Icons.error_outline_rounded,
      ToastType.success => Icons.check_circle_outline_rounded,
      ToastType.warning => Icons.warning_amber_rounded,
      ToastType.info => Icons.info_outline_rounded,
    };
  }
}
