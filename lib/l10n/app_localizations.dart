// ignore_for_file: dart-format
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Text shown in the Feed screen in the AppBar
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feedAppBarTitle;

  /// Home navigation bar item tooltip
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavBarItemLabel;

  /// Search navigation bar item tooltip
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchNavBarItemLabel;

  /// Create media navigation bar item tooltip
  ///
  /// In en, this message translates to:
  /// **'Create media'**
  String get createMediaNavBarItemLabel;

  /// Reels navigation bar item tooltip
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get reelsNavBarItemLabel;

  /// Profile navigation bar item tooltip
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileNavBarItemLabel;

  /// Text displaying statis Likes text
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likesText;

  /// Text shown in post footer section that display count of likes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} like} other{{count} likes}}'**
  String likesCountText(int count);

  /// No description provided for @likedByText.
  ///
  /// In en, this message translates to:
  /// **'Liked by {userName} and {count, plural, =1{{count} other} other{{count} others}}'**
  String likedByText(String userName, int count);

  /// No description provided for @likeText.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get likeText;

  /// No description provided for @unlikeText.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get unlikeText;

  /// Text shown in post footer section that display short count of likes
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String likesCountTextShort(int count);

  /// No description provided for @originalAudioText.
  ///
  /// In en, this message translates to:
  /// **'Original audio'**
  String get originalAudioText;

  /// No description provided for @discardEditsText.
  ///
  /// In en, this message translates to:
  /// **'Discard Edits'**
  String get discardEditsText;

  /// No description provided for @discardText.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardText;

  /// No description provided for @doneText.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneText;

  /// No description provided for @draftEmpty.
  ///
  /// In en, this message translates to:
  /// **'Draft empty'**
  String get draftEmpty;

  /// No description provided for @errorText.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorText;

  /// No description provided for @uploadText.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadText;

  /// No description provided for @loseAllEditsText.
  ///
  /// In en, this message translates to:
  /// **'If you go back now, you\'ll loose all the edits you\'ve made.'**
  String get loseAllEditsText;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get saveDraft;

  /// No description provided for @successfullySavedText.
  ///
  /// In en, this message translates to:
  /// **'Successfully saved'**
  String get successfullySavedText;

  /// No description provided for @tapToTypeText.
  ///
  /// In en, this message translates to:
  /// **'Tap to type...'**
  String get tapToTypeText;

  /// No description provided for @noPostsText.
  ///
  /// In en, this message translates to:
  /// **'No Posts Yet!'**
  String get noPostsText;

  /// No description provided for @noPostFoundText.
  ///
  /// In en, this message translates to:
  /// **'No post found!'**
  String get noPostFoundText;

  /// No description provided for @addCommentText.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get addCommentText;

  /// No description provided for @noChatsText.
  ///
  /// In en, this message translates to:
  /// **'No chats yet!'**
  String get noChatsText;

  /// No description provided for @startChatText.
  ///
  /// In en, this message translates to:
  /// **'Start a chat'**
  String get startChatText;

  /// No description provided for @deleteCommentText.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get deleteCommentText;

  /// No description provided for @commentDeleteConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment?'**
  String get commentDeleteConfirmationText;

  /// No description provided for @deleteMessageText.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get deleteMessageText;

  /// No description provided for @messageDeleteConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get messageDeleteConfirmationText;

  /// No description provided for @deleteChatText.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChatText;

  /// No description provided for @chatDeleteConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat?'**
  String get chatDeleteConfirmationText;

  /// No description provided for @deleteReelText.
  ///
  /// In en, this message translates to:
  /// **'Delete Reel'**
  String get deleteReelText;

  /// No description provided for @reelDeleteConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this Reel?'**
  String get reelDeleteConfirmationText;

  /// No description provided for @deleteStoryText.
  ///
  /// In en, this message translates to:
  /// **'Delete story'**
  String get deleteStoryText;

  /// No description provided for @storyDeleteConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this story?'**
  String get storyDeleteConfirmationText;

  /// No description provided for @commentText.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentText;

  /// No description provided for @commentsText.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsText;

  /// No description provided for @noCommentsText.
  ///
  /// In en, this message translates to:
  /// **'No comments'**
  String get noCommentsText;

  /// Text shown under the post caption
  ///
  /// In en, this message translates to:
  /// **'View all {count} comments'**
  String seeAllComments(int count);

  /// Text shown under the first storie in stories list view marked as your story
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get yourStoryLabel;

  /// Text displaying static Posts text
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get postsText;

  /// No description provided for @followUser.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followUser;

  /// No description provided for @followingUser.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingUser;

  /// Text displaying static Followers text
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followersText;

  /// Text displaying static Following text
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingsText;

  /// No description provided for @followersCountText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} follower} other{{count} followers}}'**
  String followersCountText(int count);

  /// No description provided for @followingsCountText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} following}}'**
  String followingsCountText(int count);

  /// Text describing the count of posts
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Post} other{Posts}}'**
  String postsCount(int count);

  /// Text shown in app bar in user's all posts screen
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profilePostsAppBarTitle;

  /// Text describing the count of posts
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Follower} other{Followers}}'**
  String followersCount(int count);

  /// Text describing the count of user followings
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Following} other{Followings}}'**
  String followingsCount(int count);

  /// No description provided for @optionsText.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsText;

  /// No description provided for @viewProfileText.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfileText;

  /// Text shown in account view to edit profile
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileText;

  /// No description provided for @editingText.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get editingText;

  /// Text shown in post edit view to edit post
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get editPostText;

  /// Text shown in account view to share profile
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfileText;

  /// Tooltip text shown in post popup to share post
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get sharePostText;

  /// No description provided for @sharePostCaptionHintText.
  ///
  /// In en, this message translates to:
  /// **'Add a message...'**
  String get sharePostCaptionHintText;

  /// No description provided for @sendText.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendText;

  /// No description provided for @sendSeparatelyText.
  ///
  /// In en, this message translates to:
  /// **'Send separately'**
  String get sendSeparatelyText;

  /// Text shown in account view to add new story
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get addStoryText;

  /// Text shown on sponsored post indicating that the post is sponsored by author
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get sponsoredPostText;

  /// Text shown on sponsored post telling that this action will navigate user to author's treepnet profile
  ///
  /// In en, this message translates to:
  /// **'Visit Treepnet Profile'**
  String get visitSponsoredInstagramProfile;

  /// Text shown on sponsored post telling that this action will navigate user to author profile
  ///
  /// In en, this message translates to:
  /// **'Visit Treepnet Profile'**
  String get visitSponsoredPostAuthorProfileText;

  /// Text shown in a floating action promo in user profile when was navigated from sponsored post
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get learnMoreAboutUserPromoText;

  /// Text shown in a floating action promo in user profile when was navigated from sponsored post
  ///
  /// In en, this message translates to:
  /// **'Go to website'**
  String get visitUserPromoWebsiteText;

  /// Text shown in modal bottom sheet to cancel current following to user
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get cancelFollowingText;

  /// Header text shown in divider block when user have seen all recent posts
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get haveSeenAllRecentPosts;

  /// Body text shown in divider block when user have seen all recent posts in past 3 days
  ///
  /// In en, this message translates to:
  /// **'You\'ve seen all new posts from the past 3 days.'**
  String get haveSeenAllRecentPostsInPast3Days;

  /// Text shown in a suggested section block.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get suggestedForYouText;

  /// No description provided for @andText.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get andText;

  /// No description provided for @othersText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{{count} other} other{{count} others}}'**
  String othersText(int count);

  /// No description provided for @newPostText.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPostText;

  /// No description provided for @newStoryText.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get newStoryText;

  /// No description provided for @newAvatarImageText.
  ///
  /// In en, this message translates to:
  /// **'New avatar image'**
  String get newAvatarImageText;

  /// No description provided for @writeCaptionText.
  ///
  /// In en, this message translates to:
  /// **'Write caption...'**
  String get writeCaptionText;

  /// No description provided for @logOutText.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOutText;

  /// No description provided for @logOutConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logOutConfirmationText;

  /// No description provided for @notShowAgainText.
  ///
  /// In en, this message translates to:
  /// **'Dont\'t show again'**
  String get notShowAgainText;

  /// No description provided for @blockPostAuthorText.
  ///
  /// In en, this message translates to:
  /// **'Block post author'**
  String get blockPostAuthorText;

  /// No description provided for @blockAuthorText.
  ///
  /// In en, this message translates to:
  /// **'Block author'**
  String get blockAuthorText;

  /// No description provided for @blockAuthorConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block this author?'**
  String get blockAuthorConfirmationText;

  /// No description provided for @blockText.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockText;

  /// No description provided for @refreshText.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshText;

  /// No description provided for @noReelsFoundText.
  ///
  /// In en, this message translates to:
  /// **'No Reels Yet'**
  String get noReelsFoundText;

  /// No description provided for @publishText.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishText;

  /// No description provided for @searchText.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchText;

  /// No description provided for @addMessageText.
  ///
  /// In en, this message translates to:
  /// **'Add message'**
  String get addMessageText;

  /// No description provided for @messageText.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageText;

  /// No description provided for @editPictureText.
  ///
  /// In en, this message translates to:
  /// **'Edit picture'**
  String get editPictureText;

  /// No description provided for @requiredFieldText.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredFieldText;

  /// No description provided for @passwordLengthErrorText.
  ///
  /// In en, this message translates to:
  /// **'Password should contain at least {count} characters'**
  String passwordLengthErrorText(int count);

  /// No description provided for @changeText.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeText;

  /// No description provided for @changePhotoText.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhotoText;

  /// No description provided for @fullNameEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Help people discover your account by using the name yor\'re known by: either your full name, nickname, or business name.\n\nYou can only change your name twice within 14 days.'**
  String get fullNameEditDescription;

  /// No description provided for @usernameEditDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be able to change your username back to {username} for another 14 days'**
  String usernameEditDescription(String username);

  /// No description provided for @profileInfoEditConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to change your {changeType} to {newUsername} ?'**
  String profileInfoEditConfirmationText(String newUsername, String changeType);

  /// No description provided for @profileInfoChangePeriodText.
  ///
  /// In en, this message translates to:
  /// **'You can change your {changeType} only twice in {count} days '**
  String profileInfoChangePeriodText(String changeType, int count);

  /// No description provided for @forgotPasswordText.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordText;

  /// No description provided for @recoveryPasswordText.
  ///
  /// In en, this message translates to:
  /// **'Password recovery'**
  String get recoveryPasswordText;

  /// No description provided for @orText.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get orText;

  /// No description provided for @signInWithText.
  ///
  /// In en, this message translates to:
  /// **'Sign in with {provider}'**
  String signInWithText(String provider);

  /// No description provided for @goBackConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to go back?'**
  String get goBackConfirmationText;

  /// No description provided for @goBackText.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBackText;

  /// No description provided for @furtherText.
  ///
  /// In en, this message translates to:
  /// **'Furhter'**
  String get furtherText;

  /// No description provided for @somethingWentWrongText.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong!'**
  String get somethingWentWrongText;

  /// No description provided for @failedToCreateStoryText.
  ///
  /// In en, this message translates to:
  /// **'Failed to create story'**
  String get failedToCreateStoryText;

  /// No description provided for @successfullyCreatedStoryText.
  ///
  /// In en, this message translates to:
  /// **'Successfully created story!'**
  String get successfullyCreatedStoryText;

  /// No description provided for @createText.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createText;

  /// No description provided for @reelText.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get reelText;

  /// No description provided for @postText.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postText;

  /// No description provided for @storyText.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get storyText;

  /// No description provided for @removeText.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeText;

  /// No description provided for @removeFollowerText.
  ///
  /// In en, this message translates to:
  /// **'Remove follower'**
  String get removeFollowerText;

  /// No description provided for @removeFollowerConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove follower?'**
  String get removeFollowerConfirmationText;

  /// No description provided for @deletePostText.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePostText;

  /// No description provided for @deletePostConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post?'**
  String get deletePostConfirmationText;

  /// No description provided for @cancelText.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelText;

  /// No description provided for @captionText.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get captionText;

  /// No description provided for @noCameraFoundText.
  ///
  /// In en, this message translates to:
  /// **'No camera found!'**
  String get noCameraFoundText;

  /// No description provided for @videoText.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get videoText;

  /// No description provided for @photoText.
  ///
  /// In en, this message translates to:
  /// **'PHOTO'**
  String get photoText;

  /// No description provided for @clearImagesText.
  ///
  /// In en, this message translates to:
  /// **'Clear selected images'**
  String get clearImagesText;

  /// No description provided for @galleryText.
  ///
  /// In en, this message translates to:
  /// **'GALLERY'**
  String get galleryText;

  /// No description provided for @deletingText.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deletingText;

  /// No description provided for @notFoundingCameraText.
  ///
  /// In en, this message translates to:
  /// **'No secondary camera found'**
  String get notFoundingCameraText;

  /// No description provided for @holdButtonText.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to record'**
  String get holdButtonText;

  /// No description provided for @noMediaFound.
  ///
  /// In en, this message translates to:
  /// **'There is no media'**
  String get noMediaFound;

  /// No description provided for @acceptAllPermissionsText.
  ///
  /// In en, this message translates to:
  /// **'Failed! accept all access permissions.'**
  String get acceptAllPermissionsText;

  /// No description provided for @noLastMessagesText.
  ///
  /// In en, this message translates to:
  /// **'No last messages'**
  String get noLastMessagesText;

  /// No description provided for @onlineText.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get onlineText;

  /// No description provided for @moreText.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreText;

  /// No description provided for @noAccountText.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountText;

  /// No description provided for @alreadyHaveAccountText.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccountText;

  /// No description provided for @nameText.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameText;

  /// No description provided for @usernameText.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameText;

  /// No description provided for @forgotPasswordEmailConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get forgotPasswordEmailConfirmationText;

  /// No description provided for @verificationTokenSentText.
  ///
  /// In en, this message translates to:
  /// **'Verification token sent to {email}'**
  String verificationTokenSentText(String email);

  /// No description provided for @emailText.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailText;

  /// No description provided for @otpText.
  ///
  /// In en, this message translates to:
  /// **'Reset token'**
  String get otpText;

  /// No description provided for @changePasswordText.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordText;

  /// No description provided for @passwordText.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordText;

  /// No description provided for @newPasswordText.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordText;

  /// No description provided for @loginText.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginText;

  /// No description provided for @signUpText.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpText;

  /// No description provided for @bioText.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioText;

  /// No description provided for @postUnavailableText.
  ///
  /// In en, this message translates to:
  /// **'Post unavailable'**
  String get postUnavailableText;

  /// No description provided for @postUnavailableDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'This post is unavailable'**
  String get postUnavailableDescriptionText;

  /// No description provided for @editText.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editText;

  /// No description provided for @editedText.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get editedText;

  /// No description provided for @deleteText.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteText;

  /// No description provided for @replyText.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyText;

  /// No description provided for @replyToText.
  ///
  /// In en, this message translates to:
  /// **'Reply to {username}'**
  String replyToText(String username);

  /// No description provided for @themeText.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeText;

  /// The option to use system-wide theme in the theme selector menu
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemOption;

  /// The option for light mode in the theme selector menu
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightModeOption;

  /// The option for dark mode in the theme selector menu
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkModeOption;

  /// No description provided for @languageText.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageText;

  /// No description provided for @ruOptionText.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get ruOptionText;

  /// No description provided for @enOptionText.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get enOptionText;

  /// No description provided for @systemDefaultText.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefaultText;

  /// Represents a text of seconds ago
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second ago} other{{seconds} seconds ago}}'**
  String secondsAgo(int seconds);

  /// Represents a text of minutes ago
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute ago} other{{minutes} minutes ago}}'**
  String minutesAgo(int minutes);

  /// Represents a text of hours ago
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour ago} other{{hours} hours ago}}'**
  String hoursAgo(int hours);

  /// Represents a text of days ago
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String daysAgo(int days);

  /// Represents a text of weeks ago
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{1 week ago} other{{weeks} weeks ago}}'**
  String weeksAgo(int weeks);

  /// Represents a text of months ago
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month ago} other{{months} months ago}}'**
  String monthsAgo(int months);

  /// Represents a text of years ago
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{1 year ago} other{{years} years ago}}'**
  String yearsAgo(int years);

  /// Text displayed when a network error occurs.
  ///
  /// In en, this message translates to:
  /// **'A network error has occurred.\nCheck your connection and try again.'**
  String get networkError;

  /// Text displayed on the refresh button when a network error occurs.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get networkErrorButton;

  /// No description provided for @likedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Liked by <username>{userName}</username>{and}<count>{count}</count>'**
  String likedByLabel(String userName, String and, String count);

  /// No description provided for @privateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'This account is private'**
  String get privateAccountTitle;

  /// No description provided for @privateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow this account to see their posts, stories and travel map.'**
  String get privateAccountSubtitle;

  /// No description provided for @signUpDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpDetailsTitle;

  /// No description provided for @signUpDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Username, your name, password and date of birth.'**
  String get signUpDetailsSubtitle;

  /// No description provided for @signUpEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get signUpEmailTitle;

  /// No description provided for @signUpEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code to this address.'**
  String get signUpEmailSubtitle;

  /// No description provided for @signUpCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get signUpCodeTitle;

  /// No description provided for @signUpCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {email}.'**
  String signUpCodeSubtitle(String email);

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @sendCodeText.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCodeText;

  /// No description provided for @verifyText.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyText;

  /// No description provided for @backText.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backText;

  /// No description provided for @birthdayText.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthdayText;

  /// No description provided for @fullNameText.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameText;

  /// No description provided for @codeHintText.
  ///
  /// In en, this message translates to:
  /// **'{length}-digit code'**
  String codeHintText(int length);

  /// No description provided for @passwordWeakText.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordWeakText;

  /// No description provided for @passwordMediumText.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get passwordMediumText;

  /// No description provided for @passwordStrongText.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrongText;

  /// No description provided for @signUpSelectBirthdayError.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth.'**
  String get signUpSelectBirthdayError;

  /// No description provided for @signUpInvalidFieldsError.
  ///
  /// In en, this message translates to:
  /// **'Please check the fields above.'**
  String get signUpInvalidFieldsError;

  /// No description provided for @signUpUsernameTakenError.
  ///
  /// In en, this message translates to:
  /// **'This username is taken. Try another one.'**
  String get signUpUsernameTakenError;

  /// No description provided for @signUpInvalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get signUpInvalidEmailError;

  /// No description provided for @signUpInvalidCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter the code correctly.'**
  String get signUpInvalidCodeError;

  /// No description provided for @signUpGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get signUpGenericError;

  /// No description provided for @signUpWeakPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password — 8+ characters with letters, numbers and a symbol.'**
  String get signUpWeakPasswordError;

  /// No description provided for @passwordNeedStrongerText.
  ///
  /// In en, this message translates to:
  /// **'You need a stronger password.'**
  String get passwordNeedStrongerText;

  /// No description provided for @genderMaleText.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMaleText;

  /// No description provided for @genderFemaleText.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemaleText;

  /// No description provided for @genderNotSayText.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get genderNotSayText;

  /// No description provided for @genderText.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderText;

  /// No description provided for @linksSectionText.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get linksSectionText;

  /// No description provided for @aboutYouSectionText.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYouSectionText;

  /// No description provided for @inviteFriendsText.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriendsText;

  /// No description provided for @inviteHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite your friends'**
  String get inviteHeroTitle;

  /// No description provided for @inviteHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your friends to Treepnet — map the places you have been, together.'**
  String get inviteHeroSubtitle;

  /// No description provided for @inviteStepShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your code'**
  String get inviteStepShareTitle;

  /// No description provided for @inviteStepShareSub.
  ///
  /// In en, this message translates to:
  /// **'Send your invite code to friends'**
  String get inviteStepShareSub;

  /// No description provided for @inviteStepJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Your friend joins'**
  String get inviteStepJoinTitle;

  /// No description provided for @inviteStepJoinSub.
  ///
  /// In en, this message translates to:
  /// **'They enter your code in the app'**
  String get inviteStepJoinSub;

  /// No description provided for @inviteStepTravelTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel together'**
  String get inviteStepTravelTitle;

  /// No description provided for @inviteStepTravelSub.
  ///
  /// In en, this message translates to:
  /// **'Pin your places on the map'**
  String get inviteStepTravelSub;

  /// No description provided for @inviteYourCodeText.
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get inviteYourCodeText;

  /// No description provided for @inviteCopyMessageText.
  ///
  /// In en, this message translates to:
  /// **'Copy invite message'**
  String get inviteCopyMessageText;

  /// No description provided for @inviteCopiedText.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get inviteCopiedText;

  /// No description provided for @inviteMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Treepnet — map every place you travel! Join me and use my invite code: {code}'**
  String inviteMessageBody(String code);

  /// No description provided for @inviteRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get inviteRewardsTitle;

  /// No description provided for @inviteRewardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends to unlock badges. Friends invited: {count}'**
  String inviteRewardsSubtitle(int count);

  /// No description provided for @inviteRedeemCardText.
  ///
  /// In en, this message translates to:
  /// **'Were you invited? Enter the code'**
  String get inviteRedeemCardText;

  /// No description provided for @inviteRedeemDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get inviteRedeemDialogTitle;

  /// No description provided for @inviteRedeemHintText.
  ///
  /// In en, this message translates to:
  /// **'Your friend\'s username or code'**
  String get inviteRedeemHintText;

  /// No description provided for @inviteRedeemOkText.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Invite accepted'**
  String get inviteRedeemOkText;

  /// No description provided for @inviteRedeemAlreadyText.
  ///
  /// In en, this message translates to:
  /// **'You have already been invited'**
  String get inviteRedeemAlreadyText;

  /// No description provided for @inviteRedeemSelfText.
  ///
  /// In en, this message translates to:
  /// **'You cannot invite yourself'**
  String get inviteRedeemSelfText;

  /// No description provided for @inviteRedeemUnknownText.
  ///
  /// In en, this message translates to:
  /// **'No such code'**
  String get inviteRedeemUnknownText;

  /// No description provided for @inviteRedeemFailedText.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — please try again'**
  String get inviteRedeemFailedText;

  /// No description provided for @inviteLinkAcceptedText.
  ///
  /// In en, this message translates to:
  /// **'Invite link accepted'**
  String get inviteLinkAcceptedText;

  /// No description provided for @confirmText.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmText;

  /// No description provided for @inviteCopyCodeText.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get inviteCopyCodeText;

  /// No description provided for @inviteCodeHelpText.
  ///
  /// In en, this message translates to:
  /// **'Your friend enters this code in Settings → Invite friends.'**
  String get inviteCodeHelpText;

  /// No description provided for @profileLinkCopiedText.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied'**
  String get profileLinkCopiedText;

  /// No description provided for @mapPickLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a location'**
  String get mapPickLocationTitle;

  /// No description provided for @mapOceanText.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get mapOceanText;

  /// No description provided for @mapDragToLandText.
  ///
  /// In en, this message translates to:
  /// **'Drag the pin onto land'**
  String get mapDragToLandText;

  /// No description provided for @mapSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get mapSelectText;

  /// No description provided for @mapPickCountryText.
  ///
  /// In en, this message translates to:
  /// **'Pick a country'**
  String get mapPickCountryText;

  /// No description provided for @mapSearchCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get mapSearchCountryHint;

  /// No description provided for @mapSearchRegionHint.
  ///
  /// In en, this message translates to:
  /// **'Search region...'**
  String get mapSearchRegionHint;

  /// No description provided for @passportTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel passport'**
  String get passportTitle;

  /// No description provided for @passportMapSection.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get passportMapSection;

  /// No description provided for @passportAchievementsSection.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get passportAchievementsSection;

  /// No description provided for @passportContinentsSection.
  ///
  /// In en, this message translates to:
  /// **'Continents  ·  {visited}/7'**
  String passportContinentsSection(int visited);

  /// No description provided for @passportRegionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Regions'**
  String get passportRegionsLabel;

  /// No description provided for @passportCountriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get passportCountriesLabel;

  /// No description provided for @passportContinentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Continents'**
  String get passportContinentsLabel;

  /// No description provided for @passportUnlockedText.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get passportUnlockedText;

  /// No description provided for @passportNeedRegions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 region} other{{count} regions}}'**
  String passportNeedRegions(int count);

  /// No description provided for @passportNeedCountries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 country} other{{count} countries}}'**
  String passportNeedCountries(int count);

  /// No description provided for @passportNeedContinents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 continent} other{{count} continents}}'**
  String passportNeedContinents(int count);

  /// No description provided for @badgeFirstStep.
  ///
  /// In en, this message translates to:
  /// **'First step'**
  String get badgeFirstStep;

  /// No description provided for @badgeTraveller.
  ///
  /// In en, this message translates to:
  /// **'Traveller'**
  String get badgeTraveller;

  /// No description provided for @badgeExperienced.
  ///
  /// In en, this message translates to:
  /// **'Experienced'**
  String get badgeExperienced;

  /// No description provided for @badgeExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get badgeExplorer;

  /// No description provided for @badgeBorderCrosser.
  ///
  /// In en, this message translates to:
  /// **'Border crosser'**
  String get badgeBorderCrosser;

  /// No description provided for @badgeGlobetrotter.
  ///
  /// In en, this message translates to:
  /// **'Globetrotter'**
  String get badgeGlobetrotter;

  /// No description provided for @badgeWorldWanderer.
  ///
  /// In en, this message translates to:
  /// **'World wanderer'**
  String get badgeWorldWanderer;

  /// No description provided for @badgeLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get badgeLegendary;

  /// No description provided for @badgeTwoContinents.
  ///
  /// In en, this message translates to:
  /// **'Two continents'**
  String get badgeTwoContinents;

  /// No description provided for @badgeThreeContinents.
  ///
  /// In en, this message translates to:
  /// **'Three continents'**
  String get badgeThreeContinents;

  /// No description provided for @badgeWholeWorld.
  ///
  /// In en, this message translates to:
  /// **'Whole world'**
  String get badgeWholeWorld;

  /// No description provided for @continentAsia.
  ///
  /// In en, this message translates to:
  /// **'Asia'**
  String get continentAsia;

  /// No description provided for @continentEurope.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get continentEurope;

  /// No description provided for @continentAfrica.
  ///
  /// In en, this message translates to:
  /// **'Africa'**
  String get continentAfrica;

  /// No description provided for @continentNorthAmerica.
  ///
  /// In en, this message translates to:
  /// **'N. America'**
  String get continentNorthAmerica;

  /// No description provided for @continentSouthAmerica.
  ///
  /// In en, this message translates to:
  /// **'S. America'**
  String get continentSouthAmerica;

  /// No description provided for @continentOceania.
  ///
  /// In en, this message translates to:
  /// **'Oceania'**
  String get continentOceania;

  /// No description provided for @continentAntarctica.
  ///
  /// In en, this message translates to:
  /// **'Antarctica'**
  String get continentAntarctica;

  /// No description provided for @passportStampsSection.
  ///
  /// In en, this message translates to:
  /// **'Stamps  ·  {count}'**
  String passportStampsSection(int count);

  /// No description provided for @passportEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your passport is still empty'**
  String get passportEmptyTitle;

  /// No description provided for @passportEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tag a region when you post — your level, stamps and achievements collect here. ✈️'**
  String get passportEmptySubtitle;

  /// No description provided for @travelLevelStart.
  ///
  /// In en, this message translates to:
  /// **'Start travelling'**
  String get travelLevelStart;

  /// No description provided for @travelLevelNew.
  ///
  /// In en, this message translates to:
  /// **'New traveller'**
  String get travelLevelNew;

  /// No description provided for @travelLevelExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get travelLevelExplorer;

  /// No description provided for @travelLevelExperienced.
  ///
  /// In en, this message translates to:
  /// **'Experienced traveller'**
  String get travelLevelExperienced;

  /// No description provided for @travelLevelGlobetrotter.
  ///
  /// In en, this message translates to:
  /// **'Globetrotter'**
  String get travelLevelGlobetrotter;

  /// No description provided for @travelLevelWorldWanderer.
  ///
  /// In en, this message translates to:
  /// **'World wanderer'**
  String get travelLevelWorldWanderer;

  /// No description provided for @travelLevelLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary traveller'**
  String get travelLevelLegendary;

  /// No description provided for @passportMaxedText.
  ///
  /// In en, this message translates to:
  /// **'You have reached the highest level! 👑'**
  String get passportMaxedText;

  /// No description provided for @passportNextLevelText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 country to the next level} other{{count} countries to the next level}}'**
  String passportNextLevelText(int count);

  /// No description provided for @passportLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get passportLevelLabel;

  /// No description provided for @onboardingSkipText.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkipText;

  /// No description provided for @avatarUploadText.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get avatarUploadText;

  /// No description provided for @avatarChangeText.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get avatarChangeText;

  /// No description provided for @avatarRemoveText.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get avatarRemoveText;

  /// No description provided for @avatarRemoveConfirmText.
  ///
  /// In en, this message translates to:
  /// **'Remove your profile photo?'**
  String get avatarRemoveConfirmText;

  /// No description provided for @avatarRemovedText.
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get avatarRemovedText;

  /// No description provided for @avatarUpdatedText.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get avatarUpdatedText;

  /// No description provided for @avatarFailedText.
  ///
  /// In en, this message translates to:
  /// **'Could not update the photo — please try again'**
  String get avatarFailedText;

  /// No description provided for @locationPostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Posts here'**
  String get locationPostsTitle;

  /// No description provided for @locationPostsThisSpot.
  ///
  /// In en, this message translates to:
  /// **'This spot'**
  String get locationPostsThisSpot;

  /// No description provided for @locationPostsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No posts yet} =1{1 post} other{{count} posts}}'**
  String locationPostsCount(int count);

  /// No description provided for @locationAddPostText.
  ///
  /// In en, this message translates to:
  /// **'Add post here'**
  String get locationAddPostText;

  /// No description provided for @locationEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Nothing posted from here yet.'**
  String get locationEmptyText;

  /// No description provided for @locationWholeRegionText.
  ///
  /// In en, this message translates to:
  /// **'See the whole region'**
  String get locationWholeRegionText;

  /// No description provided for @storyReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get storyReplyHint;

  /// No description provided for @storyViewersTitle.
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get storyViewersTitle;

  /// No description provided for @storyViewsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No views} =1{1 view} other{{count} views}}'**
  String storyViewsLabel(int count);

  /// No description provided for @storyNoViewersText.
  ///
  /// In en, this message translates to:
  /// **'No views yet'**
  String get storyNoViewersText;

  /// No description provided for @storyReplySentText.
  ///
  /// In en, this message translates to:
  /// **'Reply sent'**
  String get storyReplySentText;

  /// No description provided for @storyReplyFailedText.
  ///
  /// In en, this message translates to:
  /// **'Could not send the reply'**
  String get storyReplyFailedText;

  /// Shown when the stories grid is empty
  ///
  /// In en, this message translates to:
  /// **'No stories yet'**
  String get noStoriesText;

  /// No description provided for @inviteIntroText.
  ///
  /// In en, this message translates to:
  /// **'Invite your friends to have a more interesting time together and get a reward for it.'**
  String get inviteIntroText;

  /// No description provided for @inviteRewardRuleText.
  ///
  /// In en, this message translates to:
  /// **'For every 5 people you invite, you will receive 1 month of a tick in your profile to test a premium subscription.'**
  String get inviteRewardRuleText;

  /// No description provided for @inviteYourLinkText.
  ///
  /// In en, this message translates to:
  /// **'Your link to invite friends'**
  String get inviteYourLinkText;

  /// No description provided for @inviteRegisteredText.
  ///
  /// In en, this message translates to:
  /// **'Registered people by your link'**
  String get inviteRegisteredText;

  /// No description provided for @invitePlusOneMonthText.
  ///
  /// In en, this message translates to:
  /// **'+1 month'**
  String get invitePlusOneMonthText;

  /// No description provided for @inviteProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get inviteProgressTitle;

  /// No description provided for @inviteFriendsUnit.
  ///
  /// In en, this message translates to:
  /// **'friends'**
  String get inviteFriendsUnit;

  /// No description provided for @inviteMonthsText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String inviteMonthsText(num count);

  /// No description provided for @inviteDaysLeftText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String inviteDaysLeftText(num count);

  /// No description provided for @inviteNeedPostText.
  ///
  /// In en, this message translates to:
  /// **'Add at least one post with a location — until then the checkmark stays hidden.'**
  String get inviteNeedPostText;

  /// No description provided for @inviteTierExplainText.
  ///
  /// In en, this message translates to:
  /// **'Based on the number of cities visited, locations added and posts, you will receive one of these checkmarks. By adding new posts to your profile this checkmark will be improved according to this sequence.'**
  String get inviteTierExplainText;

  /// No description provided for @inviteCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get inviteCopyText;

  /// No description provided for @inviteNoDataText.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get inviteNoDataText;

  /// No description provided for @visitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Where have you been?'**
  String get visitedTitle;

  /// No description provided for @visitedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark the regions you\'ve visited — your travel map starts filled in.'**
  String get visitedSubtitle;

  /// No description provided for @visitedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a region or country'**
  String get visitedSearchHint;

  /// No description provided for @visitedNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your country'**
  String get visitedNearbyTitle;

  /// No description provided for @visitedContinueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get visitedContinueText;

  /// No description provided for @visitedRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Your map'**
  String get visitedRevealTitle;

  /// No description provided for @visitedRevealRegions.
  ///
  /// In en, this message translates to:
  /// **'{count} regions'**
  String visitedRevealRegions(int count);

  /// No description provided for @visitedRevealHint.
  ///
  /// In en, this message translates to:
  /// **'Post from a new place to raise your checkmark.'**
  String get visitedRevealHint;

  /// No description provided for @visitedStartText.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get visitedStartText;

  /// No description provided for @visitedNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get visitedNothingFound;

  /// No description provided for @highlightNewText.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get highlightNewText;

  /// No description provided for @highlightCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New highlight'**
  String get highlightCreateTitle;

  /// No description provided for @highlightNameHint.
  ///
  /// In en, this message translates to:
  /// **'Highlight name'**
  String get highlightNameHint;

  /// No description provided for @highlightPickStories.
  ///
  /// In en, this message translates to:
  /// **'Pick stories'**
  String get highlightPickStories;

  /// No description provided for @highlightNoStories.
  ///
  /// In en, this message translates to:
  /// **'You have no stories yet'**
  String get highlightNoStories;

  /// No description provided for @highlightSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get highlightSave;

  /// No description provided for @highlightDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete highlight?'**
  String get highlightDeleteTitle;

  /// No description provided for @locationTabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get locationTabPosts;

  /// No description provided for @locationTabStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get locationTabStories;

  /// No description provided for @locationAddText.
  ///
  /// In en, this message translates to:
  /// **'Add +'**
  String get locationAddText;

  /// No description provided for @locationNoStoriesText.
  ///
  /// In en, this message translates to:
  /// **'No stories pinned here yet'**
  String get locationNoStoriesText;

  /// No description provided for @locationPickFromArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Pin a story here'**
  String get locationPickFromArchiveTitle;

  /// No description provided for @locationArchiveEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your archive yet'**
  String get locationArchiveEmptyText;

  /// No description provided for @locationStoryPinnedText.
  ///
  /// In en, this message translates to:
  /// **'Pinned to this place'**
  String get locationStoryPinnedText;

  /// No description provided for @locationUnpinStoryText.
  ///
  /// In en, this message translates to:
  /// **'Remove from this place'**
  String get locationUnpinStoryText;

  /// No description provided for @settingsText.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsText;

  /// No description provided for @savedText.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedText;

  /// No description provided for @archiveText.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveText;

  /// No description provided for @securityText.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityText;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyText;

  /// No description provided for @blockedUsersText.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsersText;

  /// No description provided for @deleteAccountText.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountText;

  /// No description provided for @confirmPasswordText.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordText;

  /// No description provided for @accountPasswordText.
  ///
  /// In en, this message translates to:
  /// **'Account password'**
  String get accountPasswordText;

  /// No description provided for @couldNotIdentifyAccountText.
  ///
  /// In en, this message translates to:
  /// **'Could not identify your account.'**
  String get couldNotIdentifyAccountText;

  /// No description provided for @deleteFailedText.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailedText(String error);

  /// No description provided for @retryText.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryText;

  /// No description provided for @messageNotSentText.
  ///
  /// In en, this message translates to:
  /// **'Message not sent'**
  String get messageNotSentText;

  /// No description provided for @typingText.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typingText;

  /// No description provided for @failedToOpenUrlText.
  ///
  /// In en, this message translates to:
  /// **'Failed to open the url.'**
  String get failedToOpenUrlText;

  /// No description provided for @chatsTypeTabText.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get chatsTypeTabText;

  /// No description provided for @chatsTabText.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTabText;

  /// No description provided for @linkText.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkText;

  /// No description provided for @failedToCreatePostText.
  ///
  /// In en, this message translates to:
  /// **'Failed to create post!'**
  String get failedToCreatePostText;

  /// No description provided for @descriptionText.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionText;

  /// No description provided for @writeDescriptionHintText.
  ///
  /// In en, this message translates to:
  /// **'Write a description...'**
  String get writeDescriptionHintText;

  /// No description provided for @tagPeopleText.
  ///
  /// In en, this message translates to:
  /// **'Tag people'**
  String get tagPeopleText;

  /// No description provided for @tagPeopleHintText.
  ///
  /// In en, this message translates to:
  /// **'@username @friend'**
  String get tagPeopleHintText;

  /// No description provided for @addInformationText.
  ///
  /// In en, this message translates to:
  /// **'Add information'**
  String get addInformationText;

  /// No description provided for @acceptText.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptText;

  /// No description provided for @declineText.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineText;

  /// No description provided for @unblockedText.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get unblockedText;

  /// No description provided for @blockedText.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedText;

  /// No description provided for @unblockText.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockText;

  /// No description provided for @nameOfLocationText.
  ///
  /// In en, this message translates to:
  /// **'Name of location'**
  String get nameOfLocationText;

  /// No description provided for @removeFromSavedText.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFromSavedText;

  /// No description provided for @blueBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Blue check'**
  String get blueBadgeText;

  /// No description provided for @darkBlueBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Dark blue check'**
  String get darkBlueBadgeText;

  /// No description provided for @purpleBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Purple check'**
  String get purpleBadgeText;

  /// No description provided for @pinkBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Pink check'**
  String get pinkBadgeText;

  /// No description provided for @redBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Red check'**
  String get redBadgeText;

  /// No description provided for @couldNotReachServerText.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get couldNotReachServerText;

  /// No description provided for @emailAlreadyExistsText.
  ///
  /// In en, this message translates to:
  /// **'User with this email already exists.'**
  String get emailAlreadyExistsText;

  /// No description provided for @usernameOrEmailText.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get usernameOrEmailText;

  /// No description provided for @codeText.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeText;

  /// No description provided for @sendCodeAgainText.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get sendCodeAgainText;

  /// No description provided for @backToLoginText.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLoginText;

  /// No description provided for @incorrectCredentialsText.
  ///
  /// In en, this message translates to:
  /// **'Email and/or password are incorrect.'**
  String get incorrectCredentialsText;

  /// No description provided for @userNotFoundText.
  ///
  /// In en, this message translates to:
  /// **'User with this email not found!'**
  String get userNotFoundText;

  /// No description provided for @googleLoginFailedText.
  ///
  /// In en, this message translates to:
  /// **'Google login failed!'**
  String get googleLoginFailedText;

  /// No description provided for @postArchivedText.
  ///
  /// In en, this message translates to:
  /// **'Post archived'**
  String get postArchivedText;

  /// No description provided for @storiesText.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get storiesText;

  /// No description provided for @successfullyCreatedPostText.
  ///
  /// In en, this message translates to:
  /// **'Successfully created post!'**
  String get successfullyCreatedPostText;

  /// No description provided for @loggedOutSuccessfullyText.
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get loggedOutSuccessfullyText;

  /// No description provided for @logOutFailedText.
  ///
  /// In en, this message translates to:
  /// **'Log out failed'**
  String get logOutFailedText;

  /// No description provided for @featureNotAvailableText.
  ///
  /// In en, this message translates to:
  /// **'Feature is not available!'**
  String get featureNotAvailableText;

  /// No description provided for @linkCopiedText.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get linkCopiedText;

  /// No description provided for @successfullySharedPostText.
  ///
  /// In en, this message translates to:
  /// **'Successfully shared post!'**
  String get successfullySharedPostText;

  /// No description provided for @failedToSharePostText.
  ///
  /// In en, this message translates to:
  /// **'Failed to share post.'**
  String get failedToSharePostText;

  /// No description provided for @successfullySharedStoryText.
  ///
  /// In en, this message translates to:
  /// **'Successfully shared story!'**
  String get successfullySharedStoryText;

  /// No description provided for @failedToShareStoryText.
  ///
  /// In en, this message translates to:
  /// **'Failed to share story.'**
  String get failedToShareStoryText;

  /// No description provided for @copyLinkText.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLinkText;

  /// No description provided for @successfullyPinnedText.
  ///
  /// In en, this message translates to:
  /// **'Successfully pinned!'**
  String get successfullyPinnedText;

  /// No description provided for @highlightNameText.
  ///
  /// In en, this message translates to:
  /// **'Highlight name'**
  String get highlightNameText;

  /// No description provided for @addLocationText.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocationText;

  /// No description provided for @newHighlightText.
  ///
  /// In en, this message translates to:
  /// **'New highlight'**
  String get newHighlightText;

  /// No description provided for @tryToSignUpText.
  ///
  /// In en, this message translates to:
  /// **'Try to sign up.'**
  String get tryToSignUpText;

  /// No description provided for @tryAgainLaterText.
  ///
  /// In en, this message translates to:
  /// **'Try again later.'**
  String get tryAgainLaterText;

  /// No description provided for @internetConnectionErrorText.
  ///
  /// In en, this message translates to:
  /// **'Internet connection error!'**
  String get internetConnectionErrorText;

  /// No description provided for @checkInternetConnectionText.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get checkInternetConnectionText;

  /// No description provided for @tryAnotherEmailText.
  ///
  /// In en, this message translates to:
  /// **'Try another email address.'**
  String get tryAnotherEmailText;

  /// No description provided for @featureNotAvailableDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'We are trying our best to implement it as fast as possible.'**
  String get featureNotAvailableDescriptionText;

  /// No description provided for @linkNoPreviewText.
  ///
  /// In en, this message translates to:
  /// **'The page doesn\'t contain any title, description or url.'**
  String get linkNoPreviewText;

  /// No description provided for @noOneToMessageText.
  ///
  /// In en, this message translates to:
  /// **'No one new to message'**
  String get noOneToMessageText;

  /// No description provided for @noMessagesYetText.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYetText;

  /// No description provided for @sayHiText.
  ///
  /// In en, this message translates to:
  /// **'Say hi 👋'**
  String get sayHiText;

  /// No description provided for @discoverPeopleText.
  ///
  /// In en, this message translates to:
  /// **'Discover people'**
  String get discoverPeopleText;

  /// No description provided for @noSuggestionsText.
  ///
  /// In en, this message translates to:
  /// **'No suggestions right now'**
  String get noSuggestionsText;

  /// No description provided for @notificationsText.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsText;

  /// No description provided for @noNotificationsText.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsText;

  /// No description provided for @noSavedProfilesText.
  ///
  /// In en, this message translates to:
  /// **'No saved profiles yet'**
  String get noSavedProfilesText;

  /// No description provided for @savedProfilesHintText.
  ///
  /// In en, this message translates to:
  /// **'Open a profile, tap ⋮ and choose Save.'**
  String get savedProfilesHintText;

  /// No description provided for @nothingSavedText.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get nothingSavedText;

  /// No description provided for @savedPostsHintText.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark on any post to save it here.'**
  String get savedPostsHintText;

  /// No description provided for @privateAccountText.
  ///
  /// In en, this message translates to:
  /// **'Private account'**
  String get privateAccountText;

  /// No description provided for @privateAccountDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'Only your followers can see your posts, stories and travel map.'**
  String get privateAccountDescriptionText;

  /// No description provided for @comingSoonText.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoonText;

  /// No description provided for @noBlockedUsersText.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsersText;

  /// No description provided for @blockedUsersHintText.
  ///
  /// In en, this message translates to:
  /// **'People you block will show up here.'**
  String get blockedUsersHintText;

  /// No description provided for @inviteFriendText.
  ///
  /// In en, this message translates to:
  /// **'Invite friend'**
  String get inviteFriendText;

  /// No description provided for @resetPasswordText.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordText;

  /// No description provided for @forgotPasswordSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Enter your username or email and we will send you a code.'**
  String get forgotPasswordSubtitleText;

  /// No description provided for @emailedCodeText.
  ///
  /// In en, this message translates to:
  /// **'We emailed a {count}-digit code. Enter it below and choose a new password.'**
  String emailedCodeText(int count);

  /// No description provided for @passwordChangedText.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChangedText;

  /// No description provided for @passwordChangedDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'You can sign in with your new password now.'**
  String get passwordChangedDescriptionText;

  /// No description provided for @unblockConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'They will be able to find your profile and message you again.'**
  String get unblockConfirmationText;

  /// No description provided for @blockConfirmationText.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to find your profile or message you.'**
  String get blockConfirmationText;

  /// No description provided for @addLocationAndNameText.
  ///
  /// In en, this message translates to:
  /// **'Add a location and name it'**
  String get addLocationAndNameText;

  /// No description provided for @noLikesYetText.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get noLikesYetText;

  /// No description provided for @deleteAccountWarningText.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and everything in it — posts, stories, messages and profile. This cannot be undone.'**
  String get deleteAccountWarningText;

  /// No description provided for @passwordManagedText.
  ///
  /// In en, this message translates to:
  /// **'Your password is managed by Microsoft'**
  String get passwordManagedText;

  /// No description provided for @passwordSecurityDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'Treepnet never stores your password — it is kept secure by Microsoft.\n\nPassword changes are not available in the app yet.'**
  String get passwordSecurityDescriptionText;

  /// No description provided for @errorCompressingVideoText.
  ///
  /// In en, this message translates to:
  /// **'Error compressing video'**
  String get errorCompressingVideoText;

  /// No description provided for @noArchivedStoriesText.
  ///
  /// In en, this message translates to:
  /// **'No archived stories'**
  String get noArchivedStoriesText;

  /// No description provided for @archiveHintText.
  ///
  /// In en, this message translates to:
  /// **'Stories move here once their 24 hours are up. Only you can see them.'**
  String get archiveHintText;

  /// No description provided for @pinStoryText.
  ///
  /// In en, this message translates to:
  /// **'Pin story'**
  String get pinStoryText;

  /// No description provided for @saveText.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveText;

  /// No description provided for @unsaveText.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get unsaveText;

  /// No description provided for @subscribesText.
  ///
  /// In en, this message translates to:
  /// **'Subscribes'**
  String get subscribesText;

  /// No description provided for @copyProfileLinkText.
  ///
  /// In en, this message translates to:
  /// **'Copy profile link'**
  String get copyProfileLinkText;

  /// No description provided for @removedFromSavedText.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved'**
  String get removedFromSavedText;

  /// No description provided for @removeFromSavedConfirmText.
  ///
  /// In en, this message translates to:
  /// **'Remove @{username} from your saved profiles?'**
  String removeFromSavedConfirmText(String username);

  /// No description provided for @unblockUserTitleText.
  ///
  /// In en, this message translates to:
  /// **'Unblock @{username}?'**
  String unblockUserTitleText(String username);

  /// No description provided for @blockUserTitleText.
  ///
  /// In en, this message translates to:
  /// **'Block @{username}?'**
  String blockUserTitleText(String username);

  /// No description provided for @unblockAuthorText.
  ///
  /// In en, this message translates to:
  /// **'Unblock author'**
  String get unblockAuthorText;

  /// No description provided for @lastSeenMinutesText.
  ///
  /// In en, this message translates to:
  /// **'last seen {count}m ago'**
  String lastSeenMinutesText(int count);

  /// No description provided for @lastSeenHoursText.
  ///
  /// In en, this message translates to:
  /// **'last seen {count}h ago'**
  String lastSeenHoursText(int count);

  /// No description provided for @lastSeenDaysText.
  ///
  /// In en, this message translates to:
  /// **'last seen {count}d ago'**
  String lastSeenDaysText(int count);

  /// No description provided for @lastSeenAWhileText.
  ///
  /// In en, this message translates to:
  /// **'last seen a while ago'**
  String get lastSeenAWhileText;

  /// No description provided for @blockedThisUserText.
  ///
  /// In en, this message translates to:
  /// **'You\'ve blocked this user. Unblock to send a message.'**
  String get blockedThisUserText;

  /// No description provided for @cantMessageUserText.
  ///
  /// In en, this message translates to:
  /// **'You can\'t message this user.'**
  String get cantMessageUserText;

  /// No description provided for @notifLikedText.
  ///
  /// In en, this message translates to:
  /// **'Liked your post.'**
  String get notifLikedText;

  /// No description provided for @notifCommentedText.
  ///
  /// In en, this message translates to:
  /// **'Left a comment on your post.'**
  String get notifCommentedText;

  /// No description provided for @notifCommentedContentText.
  ///
  /// In en, this message translates to:
  /// **'Left a comment on your post: {text}.'**
  String notifCommentedContentText(String text);

  /// No description provided for @notifFollowedText.
  ///
  /// In en, this message translates to:
  /// **'Followed to your profile.'**
  String get notifFollowedText;

  /// No description provided for @notifFollowRequestText.
  ///
  /// In en, this message translates to:
  /// **'Wants to follow your profile.'**
  String get notifFollowRequestText;

  /// No description provided for @notifMessageText.
  ///
  /// In en, this message translates to:
  /// **'Sent you a message.'**
  String get notifMessageText;

  /// No description provided for @notifMessageContentText.
  ///
  /// In en, this message translates to:
  /// **'Sent: {text}.'**
  String notifMessageContentText(String text);

  /// No description provided for @nowText.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get nowText;

  /// No description provided for @locationText.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationText;

  /// No description provided for @profileText.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileText;

  /// No description provided for @unpinStoryText.
  ///
  /// In en, this message translates to:
  /// **'Unpin story'**
  String get unpinStoryText;

  /// No description provided for @noStoriesHereText.
  ///
  /// In en, this message translates to:
  /// **'No stories here'**
  String get noStoriesHereText;

  /// No description provided for @noPostsHereText.
  ///
  /// In en, this message translates to:
  /// **'No posts here'**
  String get noPostsHereText;

  /// No description provided for @requestedText.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requestedText;

  /// No description provided for @unknownText.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownText;

  /// No description provided for @usernameValidationText.
  ///
  /// In en, this message translates to:
  /// **'Username must be 6–16 characters: lower-case letters, numbers, periods and underscores only.'**
  String get usernameValidationText;

  /// No description provided for @selectCountryText.
  ///
  /// In en, this message translates to:
  /// **'Select a country'**
  String get selectCountryText;

  /// No description provided for @searchCountryText.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get searchCountryText;

  /// No description provided for @searchRegionText.
  ///
  /// In en, this message translates to:
  /// **'Search region...'**
  String get searchRegionText;

  /// No description provided for @nameLocationErrorText.
  ///
  /// In en, this message translates to:
  /// **'Name this location to continue'**
  String get nameLocationErrorText;

  /// No description provided for @networkProblemText.
  ///
  /// In en, this message translates to:
  /// **'Network problem — check your connection and try again.'**
  String get networkProblemText;

  /// No description provided for @postedText.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get postedText;

  /// No description provided for @postingText.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get postingText;

  /// No description provided for @cameraUnavailableText.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailableText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
