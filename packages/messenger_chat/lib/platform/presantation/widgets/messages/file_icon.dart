part of messenger_chat;

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.fileName, this.size = 40});

  final String fileName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final extension = fileName.split('.').last.toLowerCase();
    final config = _getFileConfig(extension);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config.color.withAlpha(200), config.color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: config.color.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(config.icon, color: Colors.white, size: size * 0.5),
          Positioned(
            bottom: size * 0.05,
            right: size * 0.05,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
              child: Text(
                extension.toUpperCase(),
                style: TextStyle(
                  color: config.color,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _FileConfig _getFileConfig(String ext) {
    switch (ext) {
      case 'pdf':
        return _FileConfig(
          color: const Color(0xFFE53935), // Red
          icon: ChatIcons.fileText,
        );
      case 'doc':
      case 'docx':
        return _FileConfig(
          color: const Color(0xFF1E88E5), // Blue
          icon: ChatIcons.fileText,
        );
      case 'xls':
      case 'xlsx':
        return _FileConfig(
          color: const Color(0xFF43A047), // Green
          icon: ChatIcons.fileText,
        );
      case 'ppt':
      case 'pptx':
        return _FileConfig(
          color: const Color(0xFFFB8C00), // Orange
          icon: ChatIcons.fileText,
        );
      case 'txt':
        return _FileConfig(
          color: const Color(0xFF757575), // Grey
          icon: ChatIcons.fileText,
        );
      case 'zip':
      case 'rar':
      case '7z':
        return _FileConfig(
          color: const Color(0xFF8E24AA), // Purple
          icon: ChatIcons.fileArchive,
        );
      case 'exe':
      case 'msi':
        return _FileConfig(
          color: const Color(0xFF3949AB), // Indigo
          icon: ChatIcons.fileCode,
        );
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return _FileConfig(
          color: const Color(0xFF00ACC1), // Cyan
          icon: ChatIcons.fileImage,
        );
      case 'mp4':
      case 'mov':
      case 'avi':
        return _FileConfig(
          color: const Color(0xFFD81B60), // Pink
          icon: ChatIcons.fileVideo,
        );
      case 'mp3':
      case 'wav':
      case 'm4a':
        return _FileConfig(
          color: const Color(0xFFF4511E), // Deep Orange
          icon: ChatIcons.fileAudio,
        );
      default:
        return _FileConfig(
          color: const Color(0xFF546E7A), // Blue Grey
          icon: ChatIcons.file,
        );
    }
  }
}

class _FileConfig {
  final Color color;
  final IconData icon;

  const _FileConfig({required this.color, required this.icon});
}
