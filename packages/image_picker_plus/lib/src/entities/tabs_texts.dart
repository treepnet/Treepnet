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
    this.photoUnavailableText = "This photo isn't available.",
    this.noPhotoAccessText =
        'No access to photos. Allow it in Settings to post from your gallery.',
    this.openSettingsText = 'Open Settings',
    this.selectMorePhotosText = 'Select more photos',
    this.acceptAllPermissions = 'Failed! Accept all access permissions.',
    this.noCameraFoundText = 'No camera found!',
    this.newPostText = 'New post',
    this.newAvatarImageText = 'New avatar image',
    this.discardPhotoTitleText = 'Discard photo?',
    this.discardPhotoText = 'Discard',
    this.cancelText = 'Cancel',
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

  /// Shown when a tapped photo's file can't be had (only in iCloud with no
  /// internet, or gone from the library).
  final String photoUnavailableText;

  /// The gallery when photo access was refused (not "no media": it isn't
  /// empty, it can't be read), with [openSettingsText] on a button.
  final String noPhotoAccessText;
  final String openSettingsText;

  /// With limited photo access: adds photos to what the app may see.
  final String selectMorePhotosText;
  final String acceptAllPermissions;
  final String noCameraFoundText;
  final String newPostText;
  final String newAvatarImageText;

  /// The camera's "throw this shot away?" dialog (was English-only).
  final String discardPhotoTitleText;
  final String discardPhotoText;
  final String cancelText;

  /// These texts with some replaced, e.g. the app's translated set with
  /// another title. (The story gallery built a fresh TabsTexts with only its
  /// title, so every other text there was the English default.)
  TabsTexts copyWith({
    String? videoText,
    String? photoText,
    String? galleryText,
    String? deletingText,
    String? limitingText,
    String? holdButtonText,
    String? clearImagesText,
    String? notFoundingCameraText,
    String? noMediaFound,
    String? photoCantBeUsedText,
    String? photoUnavailableText,
    String? noPhotoAccessText,
    String? openSettingsText,
    String? selectMorePhotosText,
    String? acceptAllPermissions,
    String? noCameraFoundText,
    String? newPostText,
    String? newAvatarImageText,
    String? discardPhotoTitleText,
    String? discardPhotoText,
    String? cancelText,
  }) {
    return TabsTexts(
      videoText: videoText ?? this.videoText,
      photoText: photoText ?? this.photoText,
      galleryText: galleryText ?? this.galleryText,
      deletingText: deletingText ?? this.deletingText,
      limitingText: limitingText ?? this.limitingText,
      holdButtonText: holdButtonText ?? this.holdButtonText,
      clearImagesText: clearImagesText ?? this.clearImagesText,
      notFoundingCameraText: notFoundingCameraText ?? this.notFoundingCameraText,
      noMediaFound: noMediaFound ?? this.noMediaFound,
      photoCantBeUsedText: photoCantBeUsedText ?? this.photoCantBeUsedText,
      photoUnavailableText: photoUnavailableText ?? this.photoUnavailableText,
      noPhotoAccessText: noPhotoAccessText ?? this.noPhotoAccessText,
      openSettingsText: openSettingsText ?? this.openSettingsText,
      selectMorePhotosText: selectMorePhotosText ?? this.selectMorePhotosText,
      acceptAllPermissions: acceptAllPermissions ?? this.acceptAllPermissions,
      noCameraFoundText: noCameraFoundText ?? this.noCameraFoundText,
      newPostText: newPostText ?? this.newPostText,
      newAvatarImageText: newAvatarImageText ?? this.newAvatarImageText,
      discardPhotoTitleText:
          discardPhotoTitleText ?? this.discardPhotoTitleText,
      discardPhotoText: discardPhotoText ?? this.discardPhotoText,
      cancelText: cancelText ?? this.cancelText,
    );
  }
}
