class TabsTexts {
  const TabsTexts({
    this.videoText = 'VIDEO',
    this.photoText = 'PHOTO',
    this.clearImagesText = 'Clear selected images',
    this.galleryText = 'GALLERY',
    this.deletingText = 'DELETE',
    this.limitingText,
    this.notFoundingCameraText = 'No secondary camera found',
    this.holdButtonText = 'Press and hold to record',
    this.noMediaFound = 'There is no media',
    this.photoCantBeUsedText = "This photo can't be used.",
    this.acceptAllPermissions = 'Failed! Accept all access permissions.',
    this.noCameraFoundText = 'No camera found!',
    this.newPostText = 'New post',
    this.newAvatarImageText = 'New avatar image',
  });
  final String videoText;
  final String photoText;
  final String galleryText;
  final String deletingText;
  final String? limitingText;
  final String holdButtonText;
  final String clearImagesText;
  final String notFoundingCameraText;
  final String noMediaFound;

  /// Shown when a picked photo can't be opened or cropped (it is taken out
  /// of the selection).
  final String photoCantBeUsedText;
  final String acceptAllPermissions;
  final String noCameraFoundText;
  final String newPostText;
  final String newAvatarImageText;
}
