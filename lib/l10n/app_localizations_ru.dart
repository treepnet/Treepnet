// ignore_for_file: dart-format

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get feedAppBarTitle => 'Просмотр ленты';

  @override
  String get homeNavBarItemLabel => 'Лента';

  @override
  String get searchNavBarItemLabel => 'Поиск';

  @override
  String get createMediaNavBarItemLabel => 'Создать медиа';

  @override
  String get reelsNavBarItemLabel => 'Рилс';

  @override
  String get profileNavBarItemLabel => 'Профиль';

  @override
  String get likesText => 'Нравится';

  @override
  String likesCountText(int count) {
    return 'Нравится: $count';
  }

  @override
  String likedByText(String userName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и $count другим',
      one: '',
    );
    return 'Нравится $userName $_temp0';
  }

  @override
  String get likeText => 'Нравится';

  @override
  String get unlikeText => 'Не нравится';

  @override
  String likesCountTextShort(int count) {
    return '$count';
  }

  @override
  String get originalAudioText => 'Оригинальное аудио';

  @override
  String get discardEditsText => 'Сбросить Изменения';

  @override
  String get discardText => 'Сбросить';

  @override
  String get doneText => 'Готово';

  @override
  String get draftEmpty => 'Черновик пустой';

  @override
  String get errorText => 'Ошибка';

  @override
  String get uploadText => 'Загрузить';

  @override
  String get loseAllEditsText =>
      'Если вы вернетесь сейчас, вы потеряете все внесенные вами изменения.';

  @override
  String get saveDraft => 'Сохранить черновик';

  @override
  String get successfullySavedText => 'Успешно сохранено';

  @override
  String get tapToTypeText => 'Нажмите, чтобы печатать...';

  @override
  String get noPostsText => 'Постов пока нет';

  @override
  String get noPostFoundText => 'Пост не найден!';

  @override
  String get addCommentText => 'Добавить комментарий';

  @override
  String get noChatsText => 'Нет чатов!';

  @override
  String get startChatText => 'Создать чат';

  @override
  String get deleteCommentText => 'Удалить комментарий';

  @override
  String get commentDeleteConfirmationText =>
      'Вы уверены что хотите удалить этот комментарий?';

  @override
  String get deleteMessageText => 'Удалить сообщение';

  @override
  String get messageDeleteConfirmationText =>
      'Вы уверены что хотите удалить это сообщение?';

  @override
  String get deleteChatText => 'Удалить чат';

  @override
  String get chatDeleteConfirmationText =>
      'Вы уверены что хотите удалить этот чат?';

  @override
  String get deleteReelText => 'Удалить видео Reels';

  @override
  String get reelDeleteConfirmationText =>
      'Вы уверены что хотите удалить это видео Reels?';

  @override
  String get deleteStoryText => 'Удалить историю';

  @override
  String get storyDeleteConfirmationText =>
      'Вы уверены что хотите удалить эту историю?';

  @override
  String get commentText => 'Комментарий';

  @override
  String get commentsText => 'Комментарии';

  @override
  String get noCommentsText => 'Нет комментариев';

  @override
  String seeAllComments(int count) {
    return 'Смотреть все коментарии ($count)';
  }

  @override
  String get yourStoryLabel => 'Твоя история';

  @override
  String get postsText => 'Посты';

  @override
  String get followUser => 'Подписаться';

  @override
  String get followingUser => 'Вы подписаны';

  @override
  String get followersText => 'Подписчики';

  @override
  String get followingsText => 'Подписки';

  @override
  String followersCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Подписчики: $count',
    );
    return '$_temp0';
  }

  @override
  String followingsCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Подписки: $count',
    );
    return '$_temp0';
  }

  @override
  String postsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Постов',
      few: 'Поста',
      one: 'Пост',
    );
    return '$_temp0';
  }

  @override
  String get profilePostsAppBarTitle => 'Посты';

  @override
  String followersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Подписчиков',
      few: 'Подписчика',
      one: 'Подписчик',
    );
    return '$_temp0';
  }

  @override
  String followingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Подписок',
      few: 'Подписки',
      one: 'Подписка',
    );
    return '$_temp0';
  }

  @override
  String get optionsText => 'Настройки';

  @override
  String get viewProfileText => 'Посмотреть профиль';

  @override
  String get editProfileText => 'Редактировать профиль';

  @override
  String get editingText => 'Редактирование';

  @override
  String get editPostText => 'Редактировать публикацию';

  @override
  String get shareProfileText => 'Поделиться профилем';

  @override
  String get sharePostText => 'Поделиться';

  @override
  String get sharePostCaptionHintText => 'Добавить сообщение...';

  @override
  String get sendText => 'Отправить';

  @override
  String get sendSeparatelyText => 'Отправить отдельно';

  @override
  String get addStoryText => 'Добавить';

  @override
  String get sponsoredPostText => 'Реклама';

  @override
  String get visitSponsoredInstagramProfile => 'Посетить профиль Treepnet';

  @override
  String get visitSponsoredPostAuthorProfileText => 'Открыть профиль Treepnet';

  @override
  String get learnMoreAboutUserPromoText => 'Узнать больше';

  @override
  String get visitUserPromoWebsiteText => 'Посетить сайт';

  @override
  String get cancelFollowingText => 'Отменить подписку';

  @override
  String get haveSeenAllRecentPosts => 'Вы посмотрели все обновления';

  @override
  String get haveSeenAllRecentPostsInPast3Days =>
      'Вы посмотрели все новые публикации за последние 3 дн.';

  @override
  String get suggestedForYouText => 'Рекомендуемые публикации';

  @override
  String get andText => 'и';

  @override
  String othersText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ещё $count',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get newPostText => 'Новая публикация';

  @override
  String get newStoryText => 'Новая история';

  @override
  String get newAvatarImageText => 'Новое фото аватара';

  @override
  String get writeCaptionText => 'Добавить подпись...';

  @override
  String get logOutText => 'Выйти';

  @override
  String get logOutConfirmationText =>
      'Вы уверены что хотите выйти из аккаунта?';

  @override
  String get notShowAgainText => 'Не показывать снова';

  @override
  String get blockPostAuthorText => 'Заблокировать автора публикации';

  @override
  String get blockAuthorText => 'Заблокировать автора';

  @override
  String get blockAuthorConfirmationText =>
      'Вы уверены что хотите заблокировать этого автора?';

  @override
  String get blockText => 'Заблокировать';

  @override
  String get refreshText => 'Обновить';

  @override
  String get noReelsFoundText => 'Видео Reels пока нет';

  @override
  String get publishText => 'Отправить';

  @override
  String get searchText => 'Поиск';

  @override
  String get addMessageText => 'Сообщение';

  @override
  String get messageText => 'Сообщение';

  @override
  String get editPictureText => 'Изменить фото';

  @override
  String get requiredFieldText => 'Это поле обязательно';

  @override
  String passwordLengthErrorText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count символа',
      one: '$count символ',
    );
    return 'Пароль должен содержать минимум $_temp0';
  }

  @override
  String get changeText => 'Изменить';

  @override
  String get changePhotoText => 'Изменить фото';

  @override
  String get fullNameEditDescription =>
      'Помогите людям найти вашу учетную запись, используя имя, под которым вы известны: полное имя, псевдоним или название компании.\n\nВы можете изменить свое имя только дважды в течение 14 дней.';

  @override
  String usernameEditDescription(String username) {
    return 'Вы сможете изменить свое имя пользователя обратно на $username следующие 14 дней.';
  }

  @override
  String profileInfoEditConfirmationText(
    String newUsername,
    String changeType,
  ) {
    return 'Вы уверены что хотите сменить $changeType на $newUsername ?';
  }

  @override
  String profileInfoChangePeriodText(String changeType, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      few: '$count дня',
      one: 'день',
    );
    return 'Вы можете изменять $changeType только дважды в $_temp0.';
  }

  @override
  String get forgotPasswordText => 'Забыли пароль?';

  @override
  String get recoveryPasswordText => 'Восстановление пароля';

  @override
  String get orText => 'Или';

  @override
  String signInWithText(String provider) {
    return 'Войти через $provider';
  }

  @override
  String get goBackConfirmationText => 'Вы уверены что хотите вернуться назад?';

  @override
  String get goBackText => 'Вернуться назад';

  @override
  String get furtherText => 'Далее';

  @override
  String get somethingWentWrongText => 'Что-то пошло не так!';

  @override
  String get failedToCreateStoryText => 'Не удалось создать историю';

  @override
  String get successfullyCreatedStoryText => 'История успешно создана!';

  @override
  String get createText => 'Cоздать';

  @override
  String get reelText => 'Видео Reels';

  @override
  String get postText => 'Пост';

  @override
  String get storyText => 'История';

  @override
  String get removeText => 'Удалить';

  @override
  String get removeFollowerText => 'Удалить подписчика';

  @override
  String get removeFollowerConfirmationText =>
      'Вы уверены что хотите удалить подписчика?';

  @override
  String get deletePostText => 'Удалить публикацию';

  @override
  String get deletePostConfirmationText =>
      'Вы уверены что хотите удальть эту публикацию?';

  @override
  String get cancelText => 'Отмена';

  @override
  String get captionText => 'Описание';

  @override
  String get noCameraFoundText => 'Камера не найдена!';

  @override
  String get videoText => 'ВИДЕО';

  @override
  String get photoText => 'ФОТО';

  @override
  String get clearImagesText => 'Очистить выбранные изображения';

  @override
  String get galleryText => 'ГАЛЕРЕЯ';

  @override
  String get deletingText => 'УДАЛИТЬ';

  @override
  String get notFoundingCameraText => 'Дополнительная камера не найдена';

  @override
  String get holdButtonText => 'Нажмите и удерживайте, чтобы записать';

  @override
  String get noMediaFound => 'Галерея пуста';

  @override
  String get acceptAllPermissionsText => 'Примите все необходимые разрешения!';

  @override
  String get noLastMessagesText => 'Нет последних сообщений';

  @override
  String get onlineText => 'онлайн';

  @override
  String get moreText => 'Ещё';

  @override
  String get noAccountText => 'Ещё нет аккаунта?';

  @override
  String get alreadyHaveAccountText => 'Уже есть аккаунт?';

  @override
  String get nameText => 'Имя';

  @override
  String get usernameText => 'Имя пользователя';

  @override
  String get forgotPasswordEmailConfirmationText =>
      'Подтверждение учётной записи';

  @override
  String verificationTokenSentText(String email) {
    return 'Код подтверждения отправлени на почту $email';
  }

  @override
  String get emailText => 'Почта';

  @override
  String get otpText => 'Код';

  @override
  String get changePasswordText => 'Поменять пароль';

  @override
  String get passwordText => 'Пароль';

  @override
  String get newPasswordText => 'Новый пароль';

  @override
  String get loginText => 'Войти';

  @override
  String get signUpText => 'Зарегестрироваться';

  @override
  String get bioText => 'Биография';

  @override
  String get postUnavailableText => 'Пост недоступен';

  @override
  String get postUnavailableDescriptionText => 'Этот пост недоступен';

  @override
  String get editText => 'Редактировать';

  @override
  String get editedText => 'изменено';

  @override
  String get deleteText => 'Удалить';

  @override
  String get replyText => 'Ответить';

  @override
  String replyToText(String username) {
    return 'В ответ $username';
  }

  @override
  String get themeText => 'Тема';

  @override
  String get systemOption => 'Системная';

  @override
  String get lightModeOption => 'Светлая';

  @override
  String get darkModeOption => 'Тёмная';

  @override
  String get languageText => 'Язык';

  @override
  String get ruOptionText => 'Русский';

  @override
  String get enOptionText => 'Английский';

  @override
  String get systemDefaultText => 'Системный язык';

  @override
  String secondsAgo(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds секунд назад',
      few: '$seconds секунды назад',
      one: '$seconds секунду назад',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes минут назад',
      few: '$minutes минуты назад',
      one: '$minutes минуту назад',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours часов назад',
      few: '$hours часа назад',
      one: '$hours час назад',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дней назад',
      few: '$days дня назад',
      one: '$days день назад',
    );
    return '$_temp0';
  }

  @override
  String weeksAgo(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks недель назад',
      few: '$weeks недели назад',
      one: '$weeks неделю назад',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months месяцев назад',
      few: '$months месяца назад',
      one: '$months месяц назад',
    );
    return '$_temp0';
  }

  @override
  String yearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years лет назад',
      few: '$years года назад',
      one: '$years год назад',
    );
    return '$_temp0';
  }

  @override
  String get networkError =>
      'Произошла сетевая ошибка.\nПроверьте подключение и повторите попытку.';

  @override
  String get networkErrorButton => 'Попробуйте ещё раз';

  @override
  String likedByLabel(String userName, String and, String count) {
    return 'Нравится <username>$userName</username>$and<count>$count</count>';
  }

  @override
  String get privateAccountTitle => 'Это закрытый аккаунт';

  @override
  String get privateAccountSubtitle =>
      'Подпишитесь на этот аккаунт, чтобы видеть его публикации, истории и карту путешествий.';

  @override
  String get signUpDetailsTitle => 'Создать аккаунт';

  @override
  String get signUpDetailsSubtitle =>
      'Имя пользователя, имя, пароль и дата рождения.';

  @override
  String get signUpEmailTitle => 'Ваш email';

  @override
  String get signUpEmailSubtitle =>
      'Мы отправим код подтверждения на этот адрес.';

  @override
  String get signUpCodeTitle => 'Введите код';

  @override
  String signUpCodeSubtitle(String email) {
    return 'Код отправлен на $email.';
  }

  @override
  String get continueText => 'Продолжить';

  @override
  String get sendCodeText => 'Отправить код';

  @override
  String get verifyText => 'Подтвердить';

  @override
  String get backText => 'Назад';

  @override
  String get birthdayText => 'День рождения';

  @override
  String get fullNameText => 'Полное имя';

  @override
  String codeHintText(int length) {
    return 'Код из $length цифр';
  }

  @override
  String get passwordWeakText => 'Слабый';

  @override
  String get passwordMediumText => 'Средний';

  @override
  String get passwordStrongText => 'Надёжный';

  @override
  String get signUpSelectBirthdayError => 'Выберите дату рождения.';

  @override
  String get signUpInvalidFieldsError => 'Проверьте поля выше.';

  @override
  String get signUpUsernameTakenError =>
      'Это имя пользователя занято. Выберите другое.';

  @override
  String get signUpInvalidEmailError => 'Неверный адрес email.';

  @override
  String get signUpInvalidCodeError => 'Введите код правильно.';

  @override
  String get signUpGenericError => 'Произошла ошибка. Попробуйте снова.';

  @override
  String get signUpWeakPasswordError =>
      'Выберите более надёжный пароль — от 8 символов: буквы, цифры и символ.';

  @override
  String get passwordNeedStrongerText => 'Нужен более надёжный пароль.';

  @override
  String get genderMaleText => 'Мужской';

  @override
  String get genderFemaleText => 'Женский';

  @override
  String get genderNotSayText => 'Не указывать';

  @override
  String get genderText => 'Пол';

  @override
  String get linksSectionText => 'Ссылки';

  @override
  String get aboutYouSectionText => 'О себе';

  @override
  String get inviteFriendsText => 'Пригласить друзей';

  @override
  String get inviteHeroTitle => 'Пригласите друзей';

  @override
  String get inviteHeroSubtitle =>
      'Приведите друзей в Treepnet — отмечайте на карте места, где вы побывали, вместе.';

  @override
  String get inviteStepShareTitle => 'Поделитесь кодом';

  @override
  String get inviteStepShareSub => 'Отправьте свой код приглашения друзьям';

  @override
  String get inviteStepJoinTitle => 'Друг присоединяется';

  @override
  String get inviteStepJoinSub => 'Он вводит ваш код в приложении';

  @override
  String get inviteStepTravelTitle => 'Путешествуйте вместе';

  @override
  String get inviteStepTravelSub => 'Отмечайте свои места на карте';

  @override
  String get inviteYourCodeText => 'Ваш код приглашения';

  @override
  String get inviteCopyMessageText => 'Копировать текст приглашения';

  @override
  String get inviteCopiedText => 'Скопировано';

  @override
  String inviteMessageBody(String code) {
    return 'Treepnet — отмечайте на карте каждое место, где побывали! Присоединяйтесь и введите мой код приглашения: $code';
  }

  @override
  String get inviteRewardsTitle => 'Награды';

  @override
  String inviteRewardsSubtitle(int count) {
    return 'Приглашайте друзей и открывайте значки. Приглашено друзей: $count';
  }

  @override
  String get inviteRedeemCardText => 'Вас пригласили? Введите код';

  @override
  String get inviteRedeemDialogTitle => 'Введите код приглашения';

  @override
  String get inviteRedeemHintText => 'Имя пользователя или код друга';

  @override
  String get inviteRedeemOkText => 'Спасибо! Приглашение принято';

  @override
  String get inviteRedeemAlreadyText => 'Вас уже пригласили';

  @override
  String get inviteRedeemSelfText => 'Нельзя пригласить самого себя';

  @override
  String get inviteRedeemUnknownText => 'Такой код не найден';

  @override
  String get inviteRedeemFailedText =>
      'Что-то пошло не так — попробуйте ещё раз';

  @override
  String get inviteLinkAcceptedText => 'Ссылка-приглашение принята';

  @override
  String get confirmText => 'Подтвердить';

  @override
  String get inviteCopyCodeText => 'Копировать код';

  @override
  String get inviteCodeHelpText =>
      'Друг вводит этот код в разделе «Настройки» → «Пригласить друзей».';

  @override
  String get profileLinkCopiedText => 'Ссылка на профиль скопирована';

  @override
  String get mapPickLocationTitle => 'Выберите место';

  @override
  String get mapOceanText => 'Океан';

  @override
  String get mapDragToLandText => 'Перетащите метку на сушу';

  @override
  String get mapSelectText => 'Выбрать';

  @override
  String get mapPickCountryText => 'Выберите страну';

  @override
  String get mapSearchCountryHint => 'Поиск страны...';

  @override
  String get mapSearchRegionHint => 'Поиск региона...';

  @override
  String get passportTitle => 'Паспорт путешественника';

  @override
  String get passportMapSection => 'Карта';

  @override
  String get passportAchievementsSection => 'Достижения';

  @override
  String passportContinentsSection(int visited) {
    return 'Континенты  ·  $visited/7';
  }

  @override
  String get passportRegionsLabel => 'Регионы';

  @override
  String get passportCountriesLabel => 'Страны';

  @override
  String get passportContinentsLabel => 'Континенты';

  @override
  String get passportUnlockedText => 'Открыто';

  @override
  String passportNeedRegions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count регионов',
      few: '$count региона',
      one: '$count регион',
    );
    return '$_temp0';
  }

  @override
  String passportNeedCountries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стран',
      few: '$count страны',
      one: '$count страна',
    );
    return '$_temp0';
  }

  @override
  String passportNeedContinents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count континентов',
      few: '$count континента',
      one: '$count континент',
    );
    return '$_temp0';
  }

  @override
  String get badgeFirstStep => 'Первый шаг';

  @override
  String get badgeTraveller => 'Путешественник';

  @override
  String get badgeExperienced => 'Опытный';

  @override
  String get badgeExplorer => 'Исследователь';

  @override
  String get badgeBorderCrosser => 'Через границы';

  @override
  String get badgeGlobetrotter => 'Путешественник мира';

  @override
  String get badgeWorldWanderer => 'Странник мира';

  @override
  String get badgeLegendary => 'Легендарный';

  @override
  String get badgeTwoContinents => 'Два континента';

  @override
  String get badgeThreeContinents => 'Три континента';

  @override
  String get badgeWholeWorld => 'Весь мир';

  @override
  String get continentAsia => 'Азия';

  @override
  String get continentEurope => 'Европа';

  @override
  String get continentAfrica => 'Африка';

  @override
  String get continentNorthAmerica => 'С. Америка';

  @override
  String get continentSouthAmerica => 'Ю. Америка';

  @override
  String get continentOceania => 'Океания';

  @override
  String get continentAntarctica => 'Антарктида';

  @override
  String passportStampsSection(int count) {
    return 'Штампы  ·  $count';
  }

  @override
  String get passportEmptyTitle => 'Ваш паспорт пока пуст';

  @override
  String get passportEmptySubtitle =>
      'Отмечайте регион в публикациях — здесь будут копиться ваш уровень, штампы и достижения. ✈️';

  @override
  String get travelLevelStart => 'Начните путешествие';

  @override
  String get travelLevelNew => 'Новый путешественник';

  @override
  String get travelLevelExplorer => 'Исследователь';

  @override
  String get travelLevelExperienced => 'Опытный путешественник';

  @override
  String get travelLevelGlobetrotter => 'Путешественник мира';

  @override
  String get travelLevelWorldWanderer => 'Странник мира';

  @override
  String get travelLevelLegendary => 'Легендарный путешественник';

  @override
  String get passportMaxedText => 'Вы достигли высшего уровня! 👑';

  @override
  String passportNextLevelText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стран до следующего уровня',
      few: '$count страны до следующего уровня',
      one: '$count страна до следующего уровня',
    );
    return '$_temp0';
  }

  @override
  String get passportLevelLabel => 'Уровень';

  @override
  String get onboardingSkipText => 'Пропустить';

  @override
  String get avatarUploadText => 'Загрузить фото';

  @override
  String get avatarChangeText => 'Изменить фото';

  @override
  String get avatarRemoveText => 'Удалить фото';

  @override
  String get avatarRemoveConfirmText => 'Удалить фото профиля?';

  @override
  String get avatarRemovedText => 'Фото удалено';

  @override
  String get avatarUpdatedText => 'Фото обновлено';

  @override
  String get avatarFailedText =>
      'Не удалось обновить фото — попробуйте ещё раз';

  @override
  String get locationPostsTitle => 'Посты здесь';

  @override
  String get locationPostsThisSpot => 'Это место';

  @override
  String locationPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count публикаций',
      few: '$count публикации',
      one: '$count публикация',
      zero: 'Пока нет публикаций',
    );
    return '$_temp0';
  }

  @override
  String get locationAddPostText => 'Добавить публикацию здесь';

  @override
  String get locationEmptyText => 'Отсюда ещё ничего не опубликовано.';

  @override
  String get locationWholeRegionText => 'Показать весь регион';

  @override
  String get storyReplyHint => 'Отправить сообщение';

  @override
  String get storyViewersTitle => 'Просмотры';

  @override
  String storyViewsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count просмотров',
      few: '$count просмотра',
      one: '$count просмотр',
      zero: 'Нет просмотров',
    );
    return '$_temp0';
  }

  @override
  String get storyNoViewersText => 'Пока нет просмотров';

  @override
  String get storyReplySentText => 'Ответ отправлен';

  @override
  String get storyReplyFailedText => 'Не удалось отправить ответ';

  @override
  String get noStoriesText => 'Историй пока нет';

  @override
  String get inviteIntroText =>
      'Приглашайте друзей, чтобы проводить время интереснее и получать за это награду.';

  @override
  String get inviteRewardRuleText =>
      'За каждые 5 приглашённых вы получите 1 месяц галочки в профиле для теста премиум-подписки.';

  @override
  String get inviteYourLinkText => 'Ваша ссылка для приглашения друзей';

  @override
  String get inviteRegisteredText => 'Зарегистрировались по вашей ссылке';

  @override
  String get invitePlusOneMonthText => '+1 месяц';

  @override
  String get inviteProgressTitle => 'Ваш прогресс';

  @override
  String get inviteFriendsUnit => 'друзей';

  @override
  String inviteMonthsText(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString месяцев',
      few: '$countString месяца',
      one: '$countString месяц',
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
      other: 'осталось $countString дней',
      few: 'осталось $countString дня',
      one: 'остался $countString день',
    );
    return '$_temp0';
  }

  @override
  String get inviteNeedPostText =>
      'Добавьте хотя бы одну публикацию с локацией — без неё галочка не появится.';

  @override
  String get inviteTierExplainText =>
      'В зависимости от числа посещённых городов, добавленных локаций и публикаций вы получите одну из этих галочек. Добавляя новые публикации, вы будете улучшать её по этой последовательности.';

  @override
  String get inviteCopyText => 'Копировать';

  @override
  String get inviteNoDataText => '—';

  @override
  String get visitedTitle => 'Где вы уже были?';

  @override
  String get visitedSubtitle =>
      'Отметьте регионы, где вы были — ваша карта начнётся уже заполненной.';

  @override
  String get visitedSearchHint => 'Поиск региона или страны';

  @override
  String get visitedNearbyTitle => 'Ваша страна';

  @override
  String get visitedContinueText => 'Продолжить';

  @override
  String get visitedRevealTitle => 'Ваша карта';

  @override
  String visitedRevealRegions(int count) {
    return '$count регионов';
  }

  @override
  String get visitedRevealHint =>
      'Публикуйте из новых мест, чтобы улучшить галочку.';

  @override
  String get visitedStartText => 'Начать';

  @override
  String get visitedNothingFound => 'Ничего не найдено';

  @override
  String get highlightNewText => 'Новый';

  @override
  String get highlightCreateTitle => 'Новый хайлайт';

  @override
  String get highlightNameHint => 'Название хайлайта';

  @override
  String get highlightPickStories => 'Выберите истории';

  @override
  String get highlightNoStories => 'У вас пока нет историй';

  @override
  String get highlightSave => 'Сохранить';

  @override
  String get highlightDeleteTitle => 'Удалить хайлайт?';

  @override
  String get locationTabPosts => 'Посты';

  @override
  String get locationTabStories => 'Истории';

  @override
  String get locationAddText => 'Добавить +';

  @override
  String get locationNoStoriesText =>
      'Сюда пока не закреплено ни одной истории';

  @override
  String get locationPickFromArchiveTitle => 'Закрепить историю здесь';

  @override
  String get locationArchiveEmptyText => 'В архиве пока пусто';

  @override
  String get locationStoryPinnedText => 'Закреплено в этом месте';

  @override
  String get locationUnpinStoryText => 'Убрать из этого места';

  @override
  String get settingsText => 'Настройки';

  @override
  String get savedText => 'Сохранённое';

  @override
  String get archiveText => 'Архив';

  @override
  String get securityText => 'Безопасность';

  @override
  String get privacyText => 'Конфиденциальность';

  @override
  String get blockedUsersText => 'Заблокированные';

  @override
  String get deleteAccountText => 'Удалить аккаунт';

  @override
  String get confirmPasswordText => 'Подтвердите пароль';

  @override
  String get accountPasswordText => 'Пароль аккаунта';

  @override
  String get couldNotIdentifyAccountText =>
      'Не удалось определить ваш аккаунт.';

  @override
  String deleteFailedText(String error) {
    return 'Ошибка удаления: $error';
  }

  @override
  String get retryText => 'Повторить';

  @override
  String get messageNotSentText => 'Сообщение не отправлено';

  @override
  String get typingText => 'печатает…';

  @override
  String get failedToOpenUrlText => 'Не удалось открыть ссылку.';

  @override
  String get chatsTypeTabText => 'Написать';

  @override
  String get chatsTabText => 'Чаты';

  @override
  String get linkText => 'Ссылка';

  @override
  String get failedToCreatePostText => 'Не удалось создать публикацию!';

  @override
  String get descriptionText => 'Описание';

  @override
  String get writeDescriptionHintText => 'Напишите описание...';

  @override
  String get tagPeopleText => 'Отметить людей';

  @override
  String get tagPeopleHintText => '@username @friend';

  @override
  String get addInformationText => 'Добавить информацию';

  @override
  String get acceptText => 'Принять';

  @override
  String get declineText => 'Отклонить';

  @override
  String get unblockedText => 'Разблокировано';

  @override
  String get blockedText => 'Заблокировано';

  @override
  String get unblockText => 'Разблокировать';

  @override
  String get nameOfLocationText => 'Название места';

  @override
  String get removeFromSavedText => 'Убрать из сохранённого';

  @override
  String get blueBadgeText => 'Синяя галочка';

  @override
  String get darkBlueBadgeText => 'Тёмно-синяя галочка';

  @override
  String get purpleBadgeText => 'Фиолетовая галочка';

  @override
  String get pinkBadgeText => 'Розовая галочка';

  @override
  String get redBadgeText => 'Красная галочка';

  @override
  String get couldNotReachServerText =>
      'Не удалось подключиться к серверу. Проверьте соединение и попробуйте снова.';

  @override
  String get emailAlreadyExistsText =>
      'Пользователь с таким email уже существует.';

  @override
  String get usernameOrEmailText => 'Имя пользователя или email';

  @override
  String get codeText => 'Код';

  @override
  String get sendCodeAgainText => 'Отправить код снова';

  @override
  String get backToLoginText => 'Назад ко входу';

  @override
  String get incorrectCredentialsText => 'Неверный email и/или пароль.';

  @override
  String get userNotFoundText => 'Пользователь с таким email не найден!';

  @override
  String get googleLoginFailedText => 'Не удалось войти через Google!';

  @override
  String get postArchivedText => 'Пост архивирован';

  @override
  String get storiesText => 'Истории';

  @override
  String get successfullyCreatedPostText => 'Пост создан!';

  @override
  String get loggedOutSuccessfullyText => 'Вы вышли из аккаунта';

  @override
  String get logOutFailedText => 'Не удалось выйти';

  @override
  String get featureNotAvailableText => 'Функция недоступна!';

  @override
  String get linkCopiedText => 'Ссылка скопирована!';

  @override
  String get successfullySharedPostText => 'Пост отправлен!';

  @override
  String get failedToSharePostText => 'Не удалось поделиться публикацией.';

  @override
  String get successfullySharedStoryText => 'История отправлена!';

  @override
  String get failedToShareStoryText => 'Не удалось поделиться историей.';

  @override
  String get copyLinkText => 'Копировать ссылку';

  @override
  String get successfullyPinnedText => 'Успешно закреплено!';

  @override
  String get highlightNameText => 'Название подборки';

  @override
  String get addLocationText => 'Добавить место';

  @override
  String get newHighlightText => 'Новая подборка';

  @override
  String get tryToSignUpText => 'Попробуйте зарегистрироваться.';

  @override
  String get tryAgainLaterText => 'Попробуйте позже.';

  @override
  String get internetConnectionErrorText => 'Ошибка подключения к интернету!';

  @override
  String get checkInternetConnectionText =>
      'Проверьте подключение к интернету и попробуйте снова.';

  @override
  String get tryAnotherEmailText => 'Попробуйте другой адрес email.';

  @override
  String get featureNotAvailableDescriptionText =>
      'Мы стараемся реализовать это как можно скорее.';

  @override
  String get linkNoPreviewText =>
      'На странице нет заголовка, описания или ссылки.';

  @override
  String get noOneToMessageText => 'Некому написать';

  @override
  String get noMessagesYetText => 'Сообщений пока нет';

  @override
  String get sayHiText => 'Поздоровайтесь 👋';

  @override
  String get discoverPeopleText => 'Найти людей';

  @override
  String get noSuggestionsText => 'Пока нет рекомендаций';

  @override
  String get notificationsText => 'Уведомления';

  @override
  String get noNotificationsText => 'Уведомлений пока нет';

  @override
  String get noSavedProfilesText => 'Нет сохранённых профилей';

  @override
  String get savedProfilesHintText =>
      'Откройте профиль, нажмите ⋮ и выберите «Сохранить».';

  @override
  String get nothingSavedText => 'Пока ничего не сохранено';

  @override
  String get savedPostsHintText =>
      'Нажмите на закладку у любой публикации, чтобы сохранить её здесь.';

  @override
  String get privateAccountText => 'Закрытый аккаунт';

  @override
  String get privateAccountDescriptionText =>
      'Только ваши подписчики видят ваши публикации, истории и карту путешествий.';

  @override
  String get comingSoonText => 'Скоро';

  @override
  String get noBlockedUsersText => 'Нет заблокированных';

  @override
  String get blockedUsersHintText =>
      'Пользователи, которых вы заблокируете, появятся здесь.';

  @override
  String get inviteFriendText => 'Пригласить друга';

  @override
  String get resetPasswordText => 'Сброс пароля';

  @override
  String get forgotPasswordSubtitleText =>
      'Введите имя пользователя или email, и мы отправим вам код.';

  @override
  String emailedCodeText(int count) {
    return 'Мы отправили $count-значный код на вашу почту. Введите его ниже и выберите новый пароль.';
  }

  @override
  String get passwordChangedText => 'Пароль изменён';

  @override
  String get passwordChangedDescriptionText =>
      'Теперь вы можете войти с новым паролем.';

  @override
  String get unblockConfirmationText =>
      'Они снова смогут найти ваш профиль и писать вам.';

  @override
  String get blockConfirmationText =>
      'Они не смогут найти ваш профиль или написать вам.';

  @override
  String get addLocationAndNameText => 'Добавьте место и назовите его';

  @override
  String get noLikesYetText => 'Пока нет отметок «Нравится»';

  @override
  String get deleteAccountWarningText =>
      'Это навсегда удалит ваш аккаунт и всё в нём — публикации, истории, сообщения и профиль. Это действие необратимо.';

  @override
  String get passwordManagedText => 'Ваш пароль надёжно защищён';

  @override
  String get passwordSecurityDescriptionText =>
      'Ваш пароль хранится в защищённом виде и никогда не отображается открыто.\n\nЧтобы изменить его, используйте «Забыли пароль?» на экране входа.';

  @override
  String get errorCompressingVideoText => 'Ошибка сжатия видео';

  @override
  String get noArchivedStoriesText => 'Нет архивных историй';

  @override
  String get archiveHintText =>
      'Истории попадают сюда после того, как их 24 часа истекут. Их видите только вы.';

  @override
  String get pinStoryText => 'Закрепить историю';

  @override
  String get saveText => 'Сохранить';

  @override
  String get unsaveText => 'Убрать';

  @override
  String get subscribesText => 'Подписки';

  @override
  String get copyProfileLinkText => 'Скопировать ссылку на профиль';

  @override
  String get removedFromSavedText => 'Убрано из сохранённого';

  @override
  String removeFromSavedConfirmText(String username) {
    return 'Убрать @$username из сохранённых профилей?';
  }

  @override
  String unblockUserTitleText(String username) {
    return 'Разблокировать @$username?';
  }

  @override
  String blockUserTitleText(String username) {
    return 'Заблокировать @$username?';
  }

  @override
  String get unblockAuthorText => 'Разблокировать автора';

  @override
  String lastSeenMinutesText(int count) {
    return 'был(а) $countм назад';
  }

  @override
  String lastSeenHoursText(int count) {
    return 'был(а) $countч назад';
  }

  @override
  String lastSeenDaysText(int count) {
    return 'был(а) $countд назад';
  }

  @override
  String get lastSeenAWhileText => 'был(а) давно';

  @override
  String get blockedThisUserText =>
      'Вы заблокировали этого пользователя. Разблокируйте, чтобы написать.';

  @override
  String get cantMessageUserText =>
      'Вы не можете написать этому пользователю, так как он вас заблокировал.';

  @override
  String get openPostText => 'Открыть пост';

  @override
  String get storyUnavailableText => 'История недоступна';

  @override
  String get couldNotOpenChatText => 'Не удалось открыть чат';

  @override
  String get couldNotDeleteChatText => 'Не удалось удалить чат';

  @override
  String locationsCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Локаций',
      one: '$count Локация',
    );
    return '$_temp0';
  }

  @override
  String get notifLikedText => 'Понравилась ваша публикация.';

  @override
  String get notifCommentedText => 'Оставил(а) комментарий к вашей публикации.';

  @override
  String notifCommentedContentText(String text) {
    return 'Оставил(а) комментарий к вашей публикации: $text.';
  }

  @override
  String get notifFollowedText => 'Подписался(ась) на вас.';

  @override
  String get notifFollowRequestText => 'Хочет подписаться на вас.';

  @override
  String get notifMessageText => 'Отправил(а) вам сообщение.';

  @override
  String notifMessageContentText(String text) {
    return 'Отправил(а): $text.';
  }

  @override
  String get nowText => 'сейчас';

  @override
  String get locationText => 'Место';

  @override
  String get profileText => 'Профиль';

  @override
  String get unpinStoryText => 'Открепить историю';

  @override
  String get noStoriesHereText => 'Здесь нет историй';

  @override
  String get noPostsHereText => 'Здесь нет публикаций';

  @override
  String get requestedText => 'Запрошено';

  @override
  String get unknownText => 'Неизвестно';

  @override
  String get usernameValidationText =>
      'Имя пользователя: 6–16 символов — строчные буквы, цифры, точки и подчёркивания.';

  @override
  String get selectCountryText => 'Выберите страну';

  @override
  String get searchCountryText => 'Поиск страны...';

  @override
  String get searchRegionText => 'Поиск региона...';

  @override
  String get nameLocationErrorText => 'Назовите место, чтобы продолжить';

  @override
  String get networkProblemText =>
      'Проблема с сетью — проверьте подключение и попробуйте снова.';

  @override
  String get postedText => 'Опубликовано';

  @override
  String get postingText => 'Публикуется…';

  @override
  String get cameraUnavailableText => 'Камера недоступна';
}
