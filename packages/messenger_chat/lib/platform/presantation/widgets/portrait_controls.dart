part of messenger_chat;

/// Default portrait controls.
class _CustomPortraitControls extends StatelessWidget {
  const _CustomPortraitControls();

  /// Icon size.
  ///
  /// This size is used for all the player icons.
  double get iconSize => 20;

  /// Font size.
  ///
  /// This size is used for all the text.
  double get fontSize => 12;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(
        child: FlickShowControlsAction(
          child: FlickSeekVideoAction(
            child: Center(
              child: FlickVideoBuffer(
                child: FlickAutoHideChild(
                  showIfVideoNotInitialized: false,
                  child: FlickPlayToggle(
                    size: 30,
                    color: Colors.black,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: FlickAutoHideChild(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlickVideoProgressBar(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FlickPlayToggle(size: iconSize),
                    SizedBox(width: iconSize / 2),
                    FlickSoundToggle(size: iconSize),
                    SizedBox(width: iconSize / 2),
                    Row(
                      children: <Widget>[
                        FlickCurrentPosition(fontSize: fontSize),
                        FlickAutoHideChild(
                          child: Text(
                            ' / ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                        FlickTotalDuration(fontSize: fontSize),
                      ],
                    ),
                    Expanded(child: Container()),
                    FlickSubtitleToggle(size: iconSize),
                    SizedBox(width: iconSize / 2),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
