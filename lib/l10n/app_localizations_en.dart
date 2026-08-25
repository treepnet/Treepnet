// ignore_for_file: dart-format

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get feedAppBarTitle => 'Feed';

  @override
  String get homeNavBarItemLabel => 'Home';

  @override
  String get searchNavBarItemLabel => 'Search';

  @override
  String get createMediaNavBarItemLabel => 'Create media';

  @override
  String get reelsNavBarItemLabel => 'Reels';

  @override
  String get profileNavBarItemLabel => 'Profile';

  @override
  String get likesText => 'Likes';

  @override
  String likesCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '$count like',
    );
    return '$_temp0';
  }

  @override
  String likedByText(String userName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '$count other',
    );
    return 'Liked by $userName and $_temp0';
  }

  @override
  String get likeText => 'Like';

  @override
  String get unlikeText => 'Unlike';

  @override
  String likesCountTextShort(int count) {
    return '$count';
  }

  @override
  String get originalAudioText => 'Original audio';

  @override
  String get discardEditsText => 'Discard Edits';

  @override
  String get discardText => 'Discard';

  @override
  String get doneText => 'Done';

  @override
  String get draftEmpty => 'Draft empty';

  @override
  String get errorText => 'Error';

  @override
  String get uploadText => 'Upload';

  @override
  String get loseAllEditsText =>
      'If you go back now, you\'ll loose all the edits you\'ve made.';

  @override
  String get saveDraft => 'Save Draft';

  @override
  String get successfullySavedText => 'Successfully saved';

  @override
  String get tapToTypeText => 'Tap to type...';

  @override
  String get noPostsText => 'No Posts Yet!';

  @override
  String get noPostFoundText => 'No post found!';

  @override
  String get addCommentText => 'Add a comment';

  @override
  String get noChatsText => 'No chats yet!';

  @override
  String get startChatText => 'Start a chat';

  @override
  String get deleteCommentText => 'Delete comment';

  @override
  String get commentDeleteConfirmationText =>
      'Are you sure you want to delete this comment?';

  @override
  String get deleteMessageText => 'Delete message';

  @override
  String get messageDeleteConfirmationText =>
      'Are you sure you want to delete this message?';

  @override
  String get deleteChatText => 'Delete chat';

  @override
  String get chatDeleteConfirmationText =>
      'Are you sure you want to delete this chat?';

  @override
  String get deleteReelText => 'Delete Reel';

  @override
  String get reelDeleteConfirmationText =>
      'Are you sure you want to delete this Reel?';

  @override
  String get deleteStoryText => 'Delete story';

  @override
  String get storyDeleteConfirmationText =>
      'Are you sure you want to delete this story?';

  @override
  String get commentText => 'Comment';

  @override
  String get commentsText => 'Comments';

  @override
  String get noCommentsText => 'No comments';

  @override
  String seeAllComments(int count) {
    return 'View all $count comments';
  }

  @override
  String get yourStoryLabel => 'Your story';

  @override
  String get postsText => 'Posts';

  @override
  String get followUser => 'Follow';

  @override
  String get followingUser => 'Following';

  @override
  String get followersText => 'Followers';

  @override
  String get followingsText => 'Following';

  @override
  String followersCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count followers',
      one: '$count follower',
    );
    return '$_temp0';
  }

  @override
  String followingsCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count following',
    );
    return '$_temp0';
  }

  @override
  String postsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posts',
      one: 'Post',
    );
    return '$_temp0';
  }

  @override
  String get profilePostsAppBarTitle => 'Posts';

  @override
  String followersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Followers',
      one: 'Follower',
    );
    return '$_temp0';
  }

  @override
  String followingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Followings',
      one: 'Following',
    );
    return '$_temp0';
  }

  @override
  String get optionsText => 'Options';

  @override
  String get viewProfileText => 'View profile';

  @override
  String get editProfileText => 'Edit profile';

  @override
  String get editingText => 'Editing';

  @override
  String get editPostText => 'Edit post';

  @override
  String get shareProfileText => 'Share profile';

  @override
  String get sharePostText => 'Share';

  @override
  String get sharePostCaptionHintText => 'Add a message...';

  @override
  String get sendText => 'Send';

  @override
  String get sendSeparatelyText => 'Send separately';

  @override
  String get addStoryText => 'New';

  @override
  String get sponsoredPostText => 'Sponsored';

  @override
  String get visitSponsoredInstagramProfile => 'Visit Treepnet Profile';

  @override
  String get visitSponsoredPostAuthorProfileText => 'Visit Treepnet Profile';

  @override
  String get learnMoreAboutUserPromoText => 'Learn more';

  @override
  String get visitUserPromoWebsiteText => 'Go to website';

  @override
  String get cancelFollowingText => 'Unfollow';

  @override
  String get haveSeenAllRecentPosts => 'You\'re all caught up';

  @override
  String get haveSeenAllRecentPostsInPast3Days =>
      'You\'ve seen all new posts from the past 3 days.';

  @override
  String get suggestedForYouText => 'Suggested for you';

  @override
  String get andText => 'and';

  @override
  String othersText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '$count other',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get newPostText => 'New post';

  @override
  String get newStoryText => 'New story';

  @override
  String get newAvatarImageText => 'New avatar image';

  @override
  String get writeCaptionText => 'Write caption...';

  @override
  String get logOutText => 'Log out';

  @override
  String get logOutConfirmationText => 'Are you sure you want to log out?';

  @override
  String get notShowAgainText => 'Dont\'t show again';

  @override
  String get blockPostAuthorText => 'Block post author';

  @override
  String get blockAuthorText => 'Block author';

  @override
  String get blockAuthorConfirmationText =>
      'Are you sure you want to block this author?';

  @override
  String get blockText => 'Block';

  @override
  String get refreshText => 'Refresh';

  @override
  String get noReelsFoundText => 'No Reels Yet';

  @override
  String get publishText => 'Publish';

  @override
  String get searchText => 'Search';

  @override
  String get addMessageText => 'Add message';

  @override
  String get messageText => 'Message';

  @override
  String get editPictureText => 'Edit picture';

  @override
  String get requiredFieldText => 'This field is required';

  @override
  String passwordLengthErrorText(int count) {
    return 'Password should contain at least $count characters';
  }

  @override
  String get changeText => 'Change';

  @override
  String get changePhotoText => 'Change photo';

  @override
  String get fullNameEditDescription =>
      'Help people discover your account by using the name yor\'re known by: either your full name, nickname, or business name.\n\nYou can only change your name twice within 14 days.';

  @override
  String usernameEditDescription(String username) {
    return 'You\'ll be able to change your username back to $username for another 14 days';
  }

  @override
  String profileInfoEditConfirmationText(
    String newUsername,
    String changeType,
  ) {
    return 'Are you sure you want to change your $changeType to $newUsername ?';
  }

  @override
  String profileInfoChangePeriodText(String changeType, int count) {
    return 'You can change your $changeType only twice in $count days ';
  }

  @override
  String get forgotPasswordText => 'Forgot password?';

  @override
  String get recoveryPasswordText => 'Password recovery';

  @override
  String get orText => 'Or';

  @override
  String signInWithText(String provider) {
    return 'Sign in with $provider';
  }

  @override
  String get goBackConfirmationText => 'Are you sure you want to go back?';

  @override
  String get goBackText => 'Go back';

  @override
  String get furtherText => 'Furhter';

  @override
  String get somethingWentWrongText => 'Something went wrong!';

  @override
  String get failedToCreateStoryText => 'Failed to create story';

  @override
  String get successfullyCreatedStoryText => 'Successfully created story!';

  @override
  String get createText => 'Create';

  @override
  String get reelText => 'Reel';

  @override
  String get postText => 'Post';

  @override
  String get storyText => 'Story';

  @override
  String get removeText => 'Remove';

  @override
  String get removeFollowerText => 'Remove follower';

  @override
  String get removeFollowerConfirmationText =>
      'Are you sure you want to remove follower?';

  @override
  String get deletePostText => 'Delete post';

  @override
  String get deletePostConfirmationText =>
      'Are you sure you want to delete this post?';

  @override
  String get cancelText => 'Cancel';

  @override
  String get captionText => 'Caption';

  @override
  String get noCameraFoundText => 'No camera found!';

  @override
  String get videoText => 'VIDEO';

  @override
  String get photoText => 'PHOTO';

  @override
  String get clearImagesText => 'Clear selected images';

  @override
  String get galleryText => 'GALLERY';

  @override
  String get deletingText => 'DELETE';

  @override
  String get notFoundingCameraText => 'No secondary camera found';

  @override
  String get holdButtonText => 'Press and hold to record';

  @override
  String get noMediaFound => 'There is no media';

  @override
  String get acceptAllPermissionsText =>
      'Failed! accept all access permissions.';

  @override
  String get noLastMessagesText => 'No last messages';

  @override
  String get onlineText => 'online';

  @override
  String get moreText => 'More';

  @override
  String get noAccountText => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccountText => 'Already have an account?';

  @override
  String get nameText => 'Name';

  @override
  String get usernameText => 'Username';

  @override
  String get forgotPasswordEmailConfirmationText => 'Email verification';

  @override
  String verificationTokenSentText(String email) {
    return 'Verification token sent to $email';
  }

  @override
  String get emailText => 'Email';

  @override
  String get otpText => 'Reset token';

  @override
  String get changePasswordText => 'Change password';

  @override
  String get passwordText => 'Password';

  @override
  String get newPasswordText => 'New password';

  @override
  String get loginText => 'Login';

  @override
  String get signUpText => 'Sign up';

  @override
  String get bioText => 'Bio';

  @override
  String get postUnavailableText => 'Post unavailable';

  @override
  String get postUnavailableDescriptionText => 'This post is unavailable';

  @override
  String get editText => 'Edit';

  @override
  String get editedText => 'edited';

  @override
  String get deleteText => 'Delete';

  @override
  String get replyText => 'Reply';

  @override
  String replyToText(String username) {
    return 'Reply to $username';
  }

  @override
  String get themeText => 'Theme';

  @override
  String get systemOption => 'System';

  @override
  String get lightModeOption => 'Light';

  @override
  String get darkModeOption => 'Dark';

  @override
  String get languageText => 'Language';

  @override
  String get ruOptionText => 'Russian';

  @override
  String get enOptionText => 'English';

  @override
  String get systemDefaultText => 'System default';

  @override
  String secondsAgo(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds ago',
      one: '1 second ago',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get networkError =>
      'A network error has occurred.\nCheck your connection and try again.';

  @override
  String get networkErrorButton => 'Try Again';

  @override
  String likedByLabel(String userName, String and, String count) {
    return 'Liked by <username>$userName</username>$and<count>$count</count>';
  }

  @override
  String get privateAccountTitle => 'This account is private';

  @override
  String get privateAccountSubtitle =>
      'Follow this account to see their posts, stories and travel map.';

  @override
  String get signUpDetailsTitle => 'Create account';

  @override
  String get signUpDetailsSubtitle =>
      'Username, your name, password and date of birth.';

  @override
  String get signUpEmailTitle => 'Your email';

  @override
  String get signUpEmailSubtitle =>
      'We\'ll send a verification code to this address.';

  @override
  String get signUpCodeTitle => 'Enter the code';

  @override
  String signUpCodeSubtitle(String email) {
    return 'Code sent to $email.';
  }

  @override
  String get continueText => 'Continue';

  @override
  String get sendCodeText => 'Send code';

  @override
  String get verifyText => 'Verify';

  @override
  String get backText => 'Back';

  @override
  String get birthdayText => 'Birthday';

  @override
  String get fullNameText => 'Full name';

  @override
  String codeHintText(int length) {
    return '$length-digit code';
  }

  @override
  String get passwordWeakText => 'Weak';

  @override
  String get passwordMediumText => 'Medium';

  @override
  String get passwordStrongText => 'Strong';

  @override
  String get signUpSelectBirthdayError => 'Select your date of birth.';

  @override
  String get signUpInvalidFieldsError => 'Please check the fields above.';

  @override
  String get signUpUsernameTakenError =>
      'This username is taken. Try another one.';

  @override
  String get signUpInvalidEmailError => 'Invalid email address.';

  @override
  String get signUpInvalidCodeError => 'Enter the code correctly.';

  @override
  String get signUpGenericError => 'Something went wrong. Please try again.';

  @override
  String get signUpWeakPasswordError =>
      'Choose a stronger password — 8+ characters with letters, numbers and a symbol.';

  @override
  String get passwordNeedStrongerText => 'You need a stronger password.';

  @override
  String get genderMaleText => 'Male';

  @override
  String get genderFemaleText => 'Female';

  @override
  String get genderNotSayText => 'Prefer not to say';

  @override
  String get genderText => 'Gender';

  @override
  String get linksSectionText => 'Links';

  @override
  String get aboutYouSectionText => 'About you';

  @override
  String get inviteFriendsText => 'Invite friends';

  @override
  String get inviteHeroTitle => 'Invite your friends';

  @override
  String get inviteHeroSubtitle =>
      'Bring your friends to Treepnet — map the places you have been, together.';

  @override
  String get inviteStepShareTitle => 'Share your code';

  @override
  String get inviteStepShareSub => 'Send your invite code to friends';

  @override
  String get inviteStepJoinTitle => 'Your friend joins';

  @override
  String get inviteStepJoinSub => 'They enter your code in the app';

  @override
  String get inviteStepTravelTitle => 'Travel together';

  @override
  String get inviteStepTravelSub => 'Pin your places on the map';

  @override
  String get inviteYourCodeText => 'Your invite code';

  @override
  String get inviteCopyMessageText => 'Copy invite message';

  @override
  String get inviteCopiedText => 'Copied';

  @override
  String inviteMessageBody(String code) {
    return 'Treepnet — map every place you travel! Join me and use my invite code: $code';
  }

  @override
  String get inviteRewardsTitle => 'Rewards';

  @override
  String inviteRewardsSubtitle(int count) {
    return 'Invite friends to unlock badges. Friends invited: $count';
  }

  @override
  String get inviteRedeemCardText => 'Were you invited? Enter the code';

  @override
  String get inviteRedeemDialogTitle => 'Enter invite code';

  @override
  String get inviteRedeemHintText => 'Your friend\'s username or code';

  @override
  String get inviteRedeemOkText => 'Thanks! Invite accepted';

  @override
  String get inviteRedeemAlreadyText => 'You have already been invited';

  @override
  String get inviteRedeemSelfText => 'You cannot invite yourself';

  @override
  String get inviteRedeemUnknownText => 'No such code';

  @override
  String get inviteRedeemFailedText =>
      'Something went wrong — please try again';

  @override
  String get inviteLinkAcceptedText => 'Invite link accepted';

  @override
  String get confirmText => 'Confirm';

  @override
  String get inviteCopyCodeText => 'Copy code';

  @override
  String get inviteCodeHelpText =>
      'Your friend enters this code in Settings → Invite friends.';

  @override
  String get profileLinkCopiedText => 'Profile link copied';

  @override
  String get mapPickLocationTitle => 'Pick a location';

  @override
  String get mapOceanText => 'Ocean';

  @override
  String get mapDragToLandText => 'Drag the pin onto land';

  @override
  String get mapSelectText => 'Select';

  @override
  String get mapPickCountryText => 'Pick a country';

  @override
  String get mapSearchCountryHint => 'Search country...';

  @override
  String get mapSearchRegionHint => 'Search region...';

  @override
  String get passportTitle => 'Travel passport';

  @override
  String get passportMapSection => 'Map';

  @override
  String get passportAchievementsSection => 'Achievements';

  @override
  String passportContinentsSection(int visited) {
    return 'Continents  ·  $visited/7';
  }

  @override
  String get passportRegionsLabel => 'Regions';

  @override
  String get passportCountriesLabel => 'Countries';

  @override
  String get passportContinentsLabel => 'Continents';

  @override
  String get passportUnlockedText => 'Unlocked';

  @override
  String passportNeedRegions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regions',
      one: '1 region',
    );
    return '$_temp0';
  }

  @override
  String passportNeedCountries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count countries',
      one: '1 country',
    );
    return '$_temp0';
  }

  @override
  String passportNeedContinents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count continents',
      one: '1 continent',
    );
    return '$_temp0';
  }

  @override
  String get badgeFirstStep => 'First step';

  @override
  String get badgeTraveller => 'Traveller';

  @override
  String get badgeExperienced => 'Experienced';

  @override
  String get badgeExplorer => 'Explorer';

  @override
  String get badgeBorderCrosser => 'Border crosser';

  @override
  String get badgeGlobetrotter => 'Globetrotter';

  @override
  String get badgeWorldWanderer => 'World wanderer';

  @override
  String get badgeLegendary => 'Legendary';

  @override
  String get badgeTwoContinents => 'Two continents';

  @override
  String get badgeThreeContinents => 'Three continents';

  @override
  String get badgeWholeWorld => 'Whole world';

  @override
  String get continentAsia => 'Asia';

  @override
  String get continentEurope => 'Europe';

  @override
  String get continentAfrica => 'Africa';

  @override
  String get continentNorthAmerica => 'N. America';

  @override
  String get continentSouthAmerica => 'S. America';

  @override
  String get continentOceania => 'Oceania';

  @override
  String get continentAntarctica => 'Antarctica';

  @override
  String passportStampsSection(int count) {
    return 'Stamps  ·  $count';
  }

  @override
  String get passportEmptyTitle => 'Your passport is still empty';

  @override
  String get passportEmptySubtitle =>
      'Tag a region when you post — your level, stamps and achievements collect here. ✈️';

  @override
  String get travelLevelStart => 'Start travelling';

  @override
  String get travelLevelNew => 'New traveller';

  @override
  String get travelLevelExplorer => 'Explorer';

  @override
  String get travelLevelExperienced => 'Experienced traveller';

  @override
  String get travelLevelGlobetrotter => 'Globetrotter';

  @override
  String get travelLevelWorldWanderer => 'World wanderer';

  @override
  String get travelLevelLegendary => 'Legendary traveller';

  @override
  String get passportMaxedText => 'You have reached the highest level! 👑';

  @override
  String passportNextLevelText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count countries to the next level',
      one: '1 country to the next level',
    );
    return '$_temp0';
  }

  @override
  String get passportLevelLabel => 'Level';

  @override
  String get onboardingSkipText => 'Skip';

  @override
  String get avatarUploadText => 'Upload photo';

  @override
  String get avatarChangeText => 'Change photo';

  @override
  String get avatarRemoveText => 'Remove photo';

  @override
  String get avatarRemoveConfirmText => 'Remove your profile photo?';

  @override
  String get avatarRemovedText => 'Photo removed';

  @override
  String get avatarUpdatedText => 'Photo updated';

  @override
  String get avatarFailedText =>
      'Could not update the photo — please try again';

  @override
  String get locationPostsTitle => 'Posts here';

  @override
  String get locationPostsThisSpot => 'This spot';

  @override
  String locationPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
      zero: 'No posts yet',
    );
    return '$_temp0';
  }

  @override
  String get locationAddPostText => 'Add post here';

  @override
  String get locationEmptyText => 'Nothing posted from here yet.';

  @override
  String get locationWholeRegionText => 'See the whole region';

  @override
  String get storyReplyHint => 'Send a message';

  @override
  String get storyViewersTitle => 'Viewers';

  @override
  String storyViewsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '1 view',
      zero: 'No views',
    );
    return '$_temp0';
  }

  @override
  String get storyNoViewersText => 'No views yet';

  @override
  String get storyReplySentText => 'Reply sent';

  @override
  String get storyReplyFailedText => 'Could not send the reply';

  @override
  String get noStoriesText => 'No stories yet';

  @override
  String get inviteIntroText =>
      'Invite your friends to have a more interesting time together and get a reward for it.';

  @override
  String get inviteRewardRuleText =>
      'For every 5 people you invite, you will receive 1 month of a tick in your profile to test a premium subscription.';

  @override
  String get inviteYourLinkText => 'Your link to invite friends';

  @override
  String get inviteRegisteredText => 'Registered people by your link';

  @override
  String get invitePlusOneMonthText => '+1 month';

  @override
  String get inviteProgressTitle => 'Your progress';

  @override
  String get inviteFriendsUnit => 'friends';

  @override
  String inviteMonthsText(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String inviteDaysLeftText(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get inviteNeedPostText =>
      'Add at least one post with a location — until then the checkmark stays hidden.';

  @override
  String get inviteTierExplainText =>
      'Based on the number of cities visited, locations added and posts, you will receive one of these checkmarks. By adding new posts to your profile this checkmark will be improved according to this sequence.';

  @override
  String get inviteCopyText => 'Copy';

  @override
  String get inviteNoDataText => '—';

  @override
  String get visitedTitle => 'Where have you been?';

  @override
  String get visitedSubtitle =>
      'Mark the regions you\'ve visited — your travel map starts filled in.';

  @override
  String get visitedSearchHint => 'Search a region or country';

  @override
  String get visitedNearbyTitle => 'Your country';

  @override
  String get visitedContinueText => 'Continue';

  @override
  String get visitedRevealTitle => 'Your map';

  @override
  String visitedRevealRegions(int count) {
    return '$count regions';
  }

  @override
  String get visitedRevealHint =>
      'Post from a new place to raise your checkmark.';

  @override
  String get visitedStartText => 'Start';

  @override
  String get visitedNothingFound => 'Nothing found';

  @override
  String get highlightNewText => 'New';

  @override
  String get highlightCreateTitle => 'New highlight';

  @override
  String get highlightNameHint => 'Highlight name';

  @override
  String get highlightPickStories => 'Pick stories';

  @override
  String get highlightNoStories => 'You have no stories yet';

  @override
  String get highlightSave => 'Save';

  @override
  String get highlightDeleteTitle => 'Delete highlight?';

  @override
  String get locationTabPosts => 'Posts';

  @override
  String get locationTabStories => 'Stories';

  @override
  String get locationAddText => 'Add +';

  @override
  String get locationNoStoriesText => 'No stories pinned here yet';

  @override
  String get locationPickFromArchiveTitle => 'Pin a story here';

  @override
  String get locationArchiveEmptyText => 'Nothing in your archive yet';

  @override
  String get locationStoryPinnedText => 'Pinned to this place';

  @override
  String get locationUnpinStoryText => 'Remove from this place';

  @override
  String get settingsText => 'Settings';

  @override
  String get savedText => 'Saved';

  @override
  String get archiveText => 'Archive';

  @override
  String get securityText => 'Security';

  @override
  String get privacyText => 'Privacy';

  @override
  String get blockedUsersText => 'Blocked users';

  @override
  String get deleteAccountText => 'Delete account';

  @override
  String get confirmPasswordText => 'Confirm password';

  @override
  String get accountPasswordText => 'Account password';

  @override
  String get couldNotIdentifyAccountText => 'Could not identify your account.';

  @override
  String deleteFailedText(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get retryText => 'Retry';

  @override
  String get messageNotSentText => 'Message not sent';

  @override
  String get typingText => 'typing…';

  @override
  String get failedToOpenUrlText => 'Failed to open the url.';

  @override
  String get chatsTypeTabText => 'Type';

  @override
  String get chatsTabText => 'Chats';

  @override
  String get linkText => 'Link';

  @override
  String get failedToCreatePostText => 'Failed to create post!';

  @override
  String get descriptionText => 'Description';

  @override
  String get writeDescriptionHintText => 'Write a description...';

  @override
  String get tagPeopleText => 'Tag people';

  @override
  String get tagPeopleHintText => '@username @friend';

  @override
  String get addInformationText => 'Add information';

  @override
  String get acceptText => 'Accept';

  @override
  String get declineText => 'Decline';

  @override
  String get unblockedText => 'Unblocked';

  @override
  String get blockedText => 'Blocked';

  @override
  String get unblockText => 'Unblock';

  @override
  String get nameOfLocationText => 'Name of location';

  @override
  String get removeFromSavedText => 'Remove from saved';

  @override
  String get blueBadgeText => 'Blue check';

  @override
  String get darkBlueBadgeText => 'Dark blue check';

  @override
  String get purpleBadgeText => 'Purple check';

  @override
  String get pinkBadgeText => 'Pink check';

  @override
  String get redBadgeText => 'Red check';

  @override
  String get couldNotReachServerText =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get emailAlreadyExistsText => 'User with this email already exists.';

  @override
  String get usernameOrEmailText => 'Username or email';

  @override
  String get codeText => 'Code';

  @override
  String get sendCodeAgainText => 'Send the code again';

  @override
  String get backToLoginText => 'Back to login';

  @override
  String get incorrectCredentialsText => 'Email and/or password are incorrect.';

  @override
  String get userNotFoundText => 'User with this email not found!';

  @override
  String get googleLoginFailedText => 'Google login failed!';

  @override
  String get postArchivedText => 'Post archived';

  @override
  String get storiesText => 'Stories';

  @override
  String get successfullyCreatedPostText => 'Successfully created post!';

  @override
  String get loggedOutSuccessfullyText => 'Logged out successfully';

  @override
  String get logOutFailedText => 'Log out failed';

  @override
  String get featureNotAvailableText => 'Feature is not available!';

  @override
  String get linkCopiedText => 'Link copied!';

  @override
  String get successfullySharedPostText => 'Successfully shared post!';

  @override
  String get failedToSharePostText => 'Failed to share post.';

  @override
  String get successfullySharedStoryText => 'Successfully shared story!';

  @override
  String get failedToShareStoryText => 'Failed to share story.';

  @override
  String get copyLinkText => 'Copy link';

  @override
  String get successfullyPinnedText => 'Successfully pinned!';

  @override
  String get highlightNameText => 'Highlight name';

  @override
  String get addLocationText => 'Add location';

  @override
  String get newHighlightText => 'New highlight';

  @override
  String get tryToSignUpText => 'Try to sign up.';

  @override
  String get tryAgainLaterText => 'Try again later.';

  @override
  String get internetConnectionErrorText => 'Internet connection error!';

  @override
  String get checkInternetConnectionText =>
      'Check your internet connection and try again.';

  @override
  String get tryAnotherEmailText => 'Try another email address.';

  @override
  String get featureNotAvailableDescriptionText =>
      'We are trying our best to implement it as fast as possible.';

  @override
  String get linkNoPreviewText =>
      'The page doesn\'t contain any title, description or url.';

  @override
  String get noOneToMessageText => 'No one new to message';

  @override
  String get noMessagesYetText => 'No messages yet';

  @override
  String get sayHiText => 'Say hi 👋';

  @override
  String get discoverPeopleText => 'Discover people';

  @override
  String get noSuggestionsText => 'No suggestions right now';

  @override
  String get notificationsText => 'Notifications';

  @override
  String get noNotificationsText => 'No notifications yet';

  @override
  String get noSavedProfilesText => 'No saved profiles yet';

  @override
  String get savedProfilesHintText => 'Open a profile, tap ⋮ and choose Save.';

  @override
  String get nothingSavedText => 'Nothing saved yet';

  @override
  String get savedPostsHintText =>
      'Tap the bookmark on any post to save it here.';

  @override
  String get privateAccountText => 'Private account';

  @override
  String get privateAccountDescriptionText =>
      'Only your followers can see your posts, stories and travel map.';

  @override
  String get comingSoonText => 'Coming soon';

  @override
  String get noBlockedUsersText => 'No blocked users';

  @override
  String get blockedUsersHintText => 'People you block will show up here.';

  @override
  String get inviteFriendText => 'Invite friend';

  @override
  String get resetPasswordText => 'Reset password';

  @override
  String get forgotPasswordSubtitleText =>
      'Enter your username or email and we will send you a code.';

  @override
  String emailedCodeText(int count) {
    return 'We emailed a $count-digit code. Enter it below and choose a new password.';
  }

  @override
  String get passwordChangedText => 'Password changed';

  @override
  String get passwordChangedDescriptionText =>
      'You can sign in with your new password now.';

  @override
  String get unblockConfirmationText =>
      'They will be able to find your profile and message you again.';

  @override
  String get blockConfirmationText =>
      'They won\'t be able to find your profile or message you.';

  @override
  String get addLocationAndNameText => 'Add a location and name it';

  @override
  String get noLikesYetText => 'No likes yet';

  @override
  String get deleteAccountWarningText =>
      'This permanently deletes your account and everything in it — posts, stories, messages and profile. This cannot be undone.';

  @override
  String get passwordManagedText => 'Your password is managed by Microsoft';

  @override
  String get passwordSecurityDescriptionText =>
      'Treepnet never stores your password — it is kept secure by Microsoft.\n\nPassword changes are not available in the app yet.';

  @override
  String get errorCompressingVideoText => 'Error compressing video';

  @override
  String get noArchivedStoriesText => 'No archived stories';

  @override
  String get archiveHintText =>
      'Stories move here once their 24 hours are up. Only you can see them.';

  @override
  String get pinStoryText => 'Pin story';

  @override
  String get saveText => 'Save';

  @override
  String get unsaveText => 'Unsave';

  @override
  String get subscribesText => 'Subscribes';

  @override
  String get copyProfileLinkText => 'Copy profile link';

  @override
  String get removedFromSavedText => 'Removed from saved';

  @override
  String removeFromSavedConfirmText(String username) {
    return 'Remove @$username from your saved profiles?';
  }

  @override
  String unblockUserTitleText(String username) {
    return 'Unblock @$username?';
  }

  @override
  String blockUserTitleText(String username) {
    return 'Block @$username?';
  }

  @override
  String get unblockAuthorText => 'Unblock author';

  @override
  String lastSeenMinutesText(int count) {
    return 'last seen ${count}m ago';
  }

  @override
  String lastSeenHoursText(int count) {
    return 'last seen ${count}h ago';
  }

  @override
  String lastSeenDaysText(int count) {
    return 'last seen ${count}d ago';
  }

  @override
  String get lastSeenAWhileText => 'last seen a while ago';

  @override
  String get blockedThisUserText =>
      'You\'ve blocked this user. Unblock to send a message.';

  @override
  String get cantMessageUserText => 'You can\'t message this user.';

  @override
  String get notifLikedText => 'Liked your post.';

  @override
  String get notifCommentedText => 'Left a comment on your post.';

  @override
  String notifCommentedContentText(String text) {
    return 'Left a comment on your post: $text.';
  }

  @override
  String get notifFollowedText => 'Followed to your profile.';

  @override
  String get notifFollowRequestText => 'Wants to follow your profile.';

  @override
  String get notifMessageText => 'Sent you a message.';

  @override
  String notifMessageContentText(String text) {
    return 'Sent: $text.';
  }

  @override
  String get nowText => 'now';

  @override
  String get locationText => 'Location';

  @override
  String get profileText => 'Profile';

  @override
  String get unpinStoryText => 'Unpin story';

  @override
  String get noStoriesHereText => 'No stories here';

  @override
  String get noPostsHereText => 'No posts here';

  @override
  String get requestedText => 'Requested';

  @override
  String get unknownText => 'Unknown';

  @override
  String get usernameValidationText =>
      'Username must be 6–16 characters: lower-case letters, numbers, periods and underscores only.';

  @override
  String get selectCountryText => 'Select a country';

  @override
  String get searchCountryText => 'Search country...';

  @override
  String get searchRegionText => 'Search region...';

  @override
  String get nameLocationErrorText => 'Name this location to continue';

  @override
  String get networkProblemText =>
      'Network problem — check your connection and try again.';

  @override
  String get postedText => 'Posted';

  @override
  String get postingText => 'Posting…';

  @override
  String get cameraUnavailableText => 'Camera unavailable';
}
