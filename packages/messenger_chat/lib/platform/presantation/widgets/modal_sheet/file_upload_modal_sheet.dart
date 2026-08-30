part of messenger_chat;

class _FileUploadModalSheet extends StatefulWidget {
  const _FileUploadModalSheet();

  @override
  State<_FileUploadModalSheet> createState() => _FileUploadModalSheetState();
}

class _FileUploadModalSheetState extends State<_FileUploadModalSheet> {
  void fileReturned(XFile? image, BuildContext context) async {
    if (image == null) return null;
    final int sizeInBytes = await image.length();
    final String sizeInMb = (sizeInBytes / (1024 * 1024)).toStringAsFixed(2);
    final String title = image.path;
    Navigator.pop(context, Message(content: title, size: '$sizeInMb Mb'));
  }

  Future<XFile?> cameraPicker(BuildContext context) async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    fileReturned(image, context);
    return image;
  }

  Future<XFile?> galleryPicker(BuildContext context) async {
    final image = await ImagePicker().pickMedia();
    fileReturned(image, context);
    return image;
  }

  Future<void> pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'mp4',
        'heic',
        'heif',
        'mp3',
        'm4a',
        'xls',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'doc',
        'docx',
        'xlsx',
      ],
    );

    final filePath = result?.files.single.path;
    final xFile = XFile(filePath ?? '');
    fileReturned(xFile, context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatCubit(ChatRepositoryImpl()),
      child: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          return Material(
            color: Colors.transparent,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildOptionTile(
                            context,
                            title: _AppTexts.takePhoto,
                            icon: ChatIcons.fileImage,
                            color: const Color(0xff1064FF),
                            isVisible: !state.config.photoIsBlock,
                            onTap: () => cameraPicker(context),
                          ),
                          _buildDivider(),
                          _buildOptionTile(
                            context,
                            title: _AppTexts.uploadFile,
                            icon: ChatIcons.fileText,
                            color: const Color(0xff1064FF),
                            isVisible: !state.config.documentIsBlock,
                            onTap: () => pickFile(context),
                          ),
                          _buildDivider(),
                          _buildOptionTile(
                            context,
                            title: _AppTexts.uploadWitGallery,
                            icon: LucideIcons.image,
                            color: const Color(0xff1064FF),
                            isVisible: !state.config.videoIsBlock,
                            onTap: () => galleryPicker(context),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _RippleEffect(
                        onTap: () {
                          HapticFeedback.mediumImpact;
                          Navigator.pop(context);
                        },
                        rippleColor: Colors.blue.shade100,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            _AppTexts.cancel,
                            style: const TextStyle(
                              color: Color(0xff1064FF),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isVisible = true,
  }) {
    if (!isVisible) return const SizedBox.shrink();

    return _RippleEffect(
      onTap: () async {
        await HapticFeedback.mediumImpact();
        onTap();
      },
      rippleColor: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 70,
      endIndent: 20,
      color: Colors.black.withOpacity(0.05),
    );
  }
}
