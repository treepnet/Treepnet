import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:user_repository/user_repository.dart';

class UserProfileEdit extends StatelessWidget {
  const UserProfileEdit({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserProfileBloc(
        userRepository: context.read<UserRepository>(),
        postsRepository: context.read<PostsRepository>(),
      )..add(const UserProfileSubscriptionRequested()),
      child: const UserProfileEditView(),
    );
  }
}

class UserProfileEditView extends StatefulWidget {
  const UserProfileEditView({super.key});

  @override
  State<UserProfileEditView> createState() => _UserProfileEditViewState();
}

class _UserProfileEditViewState extends State<UserProfileEditView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Photo menu: change, and — when there is one — remove.
  Future<void> _showAvatarOptions(
    BuildContext context,
    String? avatarUrl,
  ) async {
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final bloc = context.read<UserProfileBloc>();
    final l10n = context.l10n;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(
                hasAvatar ? l10n.avatarChangeText : l10n.avatarUploadText,
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AvatarAction.change),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.red,
                ),
                title: Text(
                  l10n.avatarRemoveText,
                  style: const TextStyle(color: AppColors.red),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _AvatarAction.change:
        final url = await UserProfileAvatar.pickAndUpload(context);
        if (url == null) return;
        bloc.add(UserProfileUpdateRequested(avatarUrl: url));
        openSnackbar(SnackbarMessage.success(title: l10n.avatarUpdatedText));
      case _AvatarAction.remove:
        if (!context.mounted) return;
        await context.confirmAction(
          title: l10n.avatarRemoveConfirmText,
          yesText: l10n.removeText,
          noText: l10n.cancelText,
          yesTextStyle: context.labelLarge?.apply(color: AppColors.red),
          fn: () {
            bloc.add(const UserProfileUpdateRequested(clearAvatar: true));
            openSnackbar(
              SnackbarMessage.success(title: l10n.avatarRemovedText),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);
    // AppBloc only carries the identity; the editable profile fields (bio,
    // links, birthday) live on the profile row that UserProfileBloc streams.
    final profile = context.select((UserProfileBloc bloc) => bloc.state.user);
    final bio = profile.bio;

    return AppScaffold(
      releaseFocus: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        title: Text(context.l10n.editProfileText),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: AppConstrainedScrollView(
          withScrollBar: true,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              UserProfileAvatar(
                avatarUrl: user.avatarUrl,
                tappableVariant: TappableVariant.scaled,
                scaleStrength: ScaleStrength.xxs,
                // Opens the menu rather than the picker directly: tapping had
                // no way to reach "remove".
                onTap: (_) => _showAvatarOptions(context, user.avatarUrl),
              ),
              gapH12,
              Tappable.faded(
                onTap: () => _showAvatarOptions(context, user.avatarUrl),
                child: Text(
                  user.hasAvatar
                      ? context.l10n.avatarChangeText
                      : context.l10n.avatarUploadText,
                  style: context.bodyLarge?.apply(color: AppColors.white),
                ),
              ),
              gapH12,
              Column(
                children: <Widget>[
                  ProfileInfoInput(
                    value: user.fullName,
                    label: context.l10n.nameText,
                    description: context.l10n.fullNameEditDescription,
                    infoType: ProfileEditInfoType.fullName,
                  ),
                  gapH12,
                  ProfileInfoInput(
                    value: user.username,
                    label: context.l10n.usernameText,
                    description: context.l10n.usernameEditDescription(
                      user.username ?? '',
                    ),
                    infoType: ProfileEditInfoType.username,
                  ),
                  gapH12,
                  ProfileInfoInput(
                    value: bio ?? '',
                    label: context.l10n.bioText,
                    description: bio ?? '',
                    infoType: ProfileEditInfoType.bio,
                  ),
                  _EditSectionHeader(context.l10n.linksSectionText),
                  // A single free-form link (Instagram, Telegram, a website —
                  // whatever the user wants). Stored in `website`.
                  ProfileInfoInput(
                    value: profile.website == null
                        ? ''
                        : 'https://${profile.website}',
                    label: context.l10n.linkText,
                    description: 'https://example.com',
                    infoType: ProfileEditInfoType.website,
                  ),
                  _EditSectionHeader(context.l10n.aboutYouSectionText),
                  _GenderInput(gender: profile.gender),
                  gapH12,
                  _BirthdayInput(birthday: profile.birthday),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the photo menu came back with.
enum _AvatarAction { change, remove }

class ProfileInfoInput extends StatefulWidget {
  const ProfileInfoInput({
    required this.value,
    required this.label,
    this.infoType,
    this.description,
    this.readOnly = true,
    this.autofocus = false,
    this.onTap,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputType = TextInputType.name,
    this.textController,
    this.prefixText,
    super.key,
  });

  final String? value;
  final String? description;
  final String label;
  final bool readOnly;
  final bool autofocus;
  final VoidCallback? onTap;
  final ValueSetter<String>? onChanged;
  final ValueSetter<String?>? onFieldSubmitted;
  final TextInputType inputType;
  final TextEditingController? textController;
  final ProfileEditInfoType? infoType;

  /// Fixed, unerasable part of the value (`t.me/`, `https://`). It is decoration
  /// rather than text, so it can't be deleted and doesn't eat into [maxLength].
  final String? prefixText;

  @override
  State<ProfileInfoInput> createState() => _ProfileInfoInputState();
}

/// What each field is allowed to hold. These are the limits the services
/// themselves enforce; a single 16 for everything cut real handles short.
int _maxLengthFor(ProfileEditInfoType? type) => switch (type) {
  ProfileEditInfoType.fullName => 40,
  ProfileEditInfoType.bio => 150,
  ProfileEditInfoType.telegram => 32,
  ProfileEditInfoType.instagram => 30,
  ProfileEditInfoType.website => 100,
  _ => 16,
};

/// The fixed link prefix shown inside the field, if the field is a link.
String? prefixForInfoType(ProfileEditInfoType? type) => switch (type) {
  ProfileEditInfoType.telegram => 't.me/',
  ProfileEditInfoType.instagram => 'instagram.com/',
  ProfileEditInfoType.website => 'https://',
  _ => null,
};

class _ProfileInfoInputState extends State<ProfileInfoInput> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController =
        (widget.textController?..text = widget.value ?? '') ??
        TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ProfileInfoInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != null) {
      _textController.text = widget.value!;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField.underlineBorder(
      textController: _textController,
      focusNode: _focusNode,
      filled: false,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.done,
      textInputType: widget.readOnly ? null : widget.inputType,
      autofillHints: const [AutofillHints.nickname],
      // Usernames are lower case only; fold capitals as they are typed.
      inputFormatters: widget.infoType == ProfileEditInfoType.username
          ? const [LowerCaseTextFormatter()]
          : null,
      onFieldSubmitted: widget.onFieldSubmitted,
      // The handle only — the prefix is decoration and isn't counted.
      maxLength: widget.readOnly ? null : _maxLengthFor(widget.infoType),
      prefix: widget.prefixText == null
          ? null
          : Text(
              widget.prefixText!,
              style: context.bodyLarge?.apply(color: AppColors.grey),
            ),
      onTap: !widget.readOnly
          ? null
          : () => context.pushNamed(
              AppRoutes.editProfileInfo.name,
              pathParameters: {'label': widget.label},
              queryParameters: {
                'title': widget.label,
                'value': widget.value,
                'description': widget.description,
                // Carried in the URL, not `extra`: GoRouter drops `extra` when
                // the route is rebuilt (e.g. the profile stream emits), which
                // left the page without a field to edit.
                'type': widget.infoType?.name,
              },
              extra: widget.infoType,
            ),
      labelText: widget.label,
      labelStyle: context.bodyLarge?.apply(color: AppColors.grey),
      contentPadding: EdgeInsets.zero,
      onChanged: widget.onChanged,
      floatingLabelBehaviour: FloatingLabelBehavior.auto,
    );
  }
}

/// Which profile field a [ProfileInfoEditPage] edits.
///
/// [username] and [fullName] are rate-limited and ask for confirmation; the
/// rest save straight away.
enum ProfileEditInfoType {
  username,
  fullName,
  bio,
  telegram,
  website,
  instagram,
  gender;

  /// Whether changing this field needs a confirmation prompt.
  bool get needsConfirmation =>
      this == ProfileEditInfoType.username ||
      this == ProfileEditInfoType.fullName;
}

class ProfileInfoEditPage extends StatelessWidget {
  const ProfileInfoEditPage({
    required this.appBarTitle,
    required this.infoLabel,
    required this.infoType,
    super.key,
    this.description,
    this.infoValue,
  });

  final String appBarTitle;
  final String? description;
  final String? infoValue;
  final String infoLabel;
  final ProfileEditInfoType infoType;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserProfileBloc(
        userRepository: context.read<UserRepository>(),
        postsRepository: context.read<PostsRepository>(),
      ),
      child: ProfileInfoEditView(
        appBarTitle: appBarTitle,
        infoLabel: infoLabel,
        infoType: infoType,
        infoValue: infoValue,
        description: description,
      ),
    );
  }
}

class ProfileInfoEditView extends StatefulWidget {
  const ProfileInfoEditView({
    required this.appBarTitle,
    required this.infoValue,
    required this.infoLabel,
    required this.infoType,
    this.description,
    super.key,
  });

  final String appBarTitle;
  final String? description;
  final String? infoValue;
  final String infoLabel;
  final ProfileEditInfoType infoType;

  @override
  State<ProfileInfoEditView> createState() => _ProfileInfoEditViewState();
}

class _ProfileInfoEditViewState extends State<ProfileInfoEditView> {
  late ValueNotifier<String> _initialValue;
  late TextEditingController _valueController;

  late String _infoChangeType;

  @override
  void initState() {
    super.initState();
    // The row hands over a display link (`t.me/x`); the field edits the handle
    // alone, with the prefix drawn as decoration beside it.
    final seed = _stripHandle(
      widget.infoValue ?? '',
      prefixForInfoType(widget.infoType) ?? '',
    );
    _initialValue = ValueNotifier(seed);
    _valueController = TextEditingController(text: seed);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _infoChangeType = switch (widget.infoType) {
        ProfileEditInfoType.fullName => context.l10n.nameText.toLowerCase(),
        ProfileEditInfoType.bio => context.l10n.bioText.toLowerCase(),
        ProfileEditInfoType.username => context.l10n.usernameText.toLowerCase(),
        ProfileEditInfoType.telegram => 'telegram',
        ProfileEditInfoType.website => 'website',
        ProfileEditInfoType.instagram => 'instagram',
        ProfileEditInfoType.gender => 'gender',
      };
    });
  }

  @override
  void dispose() {
    _initialValue.dispose();
    _valueController.dispose();
    super.dispose();
  }

  /// Stores a handle bare: people paste `t.me/x`, `@x` or a full URL, and all
  /// of them mean the same account.
  String _stripHandle(String value, String host) {
    var v = value.trim();
    for (final prefix in ['https://', 'http://', 'www.', host, '@']) {
      if (prefix.isEmpty) continue;
      if (v.toLowerCase().startsWith(prefix)) v = v.substring(prefix.length);
    }
    // A website keeps its path (`example.com/about`); a handle never has one.
    if (widget.infoType == ProfileEditInfoType.website) {
      return v.split('?').first;
    }
    return v.split('/').first.split('?').first;
  }

  /// Handles: lower-case letters, numbers, `.` and `_`, 6–16 chars — the same
  /// rule as sign-up. The field already caps at 16 and folds case; this adds
  /// the 6-char minimum and blocks saving an invalid handle.
  static final _usernameRegex = RegExp(r'^[a-z0-9_.]{6,16}$');

  String? get _usernameError {
    if (widget.infoType != ProfileEditInfoType.username) return null;
    final v = _valueController.text.trim();
    if (v.isEmpty || _usernameRegex.hasMatch(v)) return null;
    return context.l10n.usernameValidationText;
  }

  /// Writes the field through the repository and waits for it.
  ///
  /// Deliberately not via the page's own bloc: popping disposes that bloc, and
  /// a bloc closed before it drains its queue silently drops the event — which
  /// is why edits used to vanish.
  Future<void> _save(String value) async {
    final users = context.read<UserRepository>();
    switch (widget.infoType) {
      case ProfileEditInfoType.bio:
        final id = users.currentUserId;
        if (id != null) await users.updateUserBio(userId: id, bio: value);
      case ProfileEditInfoType.telegram:
        await users.updateUser(telegram: _stripHandle(value, 't.me/'));
      case ProfileEditInfoType.instagram:
        await users.updateUser(
          instagram: _stripHandle(value, 'instagram.com/'),
        );
      case ProfileEditInfoType.website:
        await users.updateUser(website: value);
      case ProfileEditInfoType.gender:
        await users.updateUser(gender: value);
      case ProfileEditInfoType.fullName:
        await users.updateUser(fullName: value);
      case ProfileEditInfoType.username:
        await users.updateUser(username: value);
    }
  }

  Future<void> _confirmInfoEditing() async {
    final value = _valueController.text.trim();
    // Clearing a bio or a link is a legitimate edit; clearing a handle is not.
    final optional =
        widget.infoType == ProfileEditInfoType.bio ||
        widget.infoType == ProfileEditInfoType.website;
    if (value.isEmpty && !optional) return;
    // A handle must satisfy the 6–16 rule before it can be saved.
    if (_usernameError != null) return;
    // Only the handle and display name are rate-limited; everything else
    // saves straight away.
    if (!widget.infoType.needsConfirmation) {
      await _save(value);
      if (mounted) context.pop();
      return;
    }
    context.confirmAction(
      fn: () async {
        await _save(value);
        if (mounted) context.pop();
      },
      title: context.l10n.profileInfoEditConfirmationText(
        value,
        _infoChangeType,
      ),
      content: context.l10n.profileInfoChangePeriodText(_infoChangeType, 14),
      yesText: context.l10n.changeText,
      noText: context.l10n.cancelText,
      yesTextStyle: context.labelLarge?.apply(color: AppColors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        centerTitle: false,
        elevation: 0,
        actions: [
          AnimatedBuilder(
            animation: Listenable.merge([_initialValue, _valueController]),
            builder: (context, _) {
              // A bio or a link may be cleared; a username or name may not.
              final optional =
                  widget.infoType == ProfileEditInfoType.bio ||
                  widget.infoType == ProfileEditInfoType.website;
              final empty = _valueController.text.trim().isEmpty;

              return IconButton(
                icon: const Icon(Icons.check, size: AppSize.iconSizeMedium),
                onPressed: (empty && !optional)
                    ? null
                    // Block save while the handle breaks the 6–16 rule.
                    : _usernameError != null
                    ? null
                    : _valueController.text.trim() == _initialValue.value
                    ? () => context.pop()
                    : _confirmInfoEditing,
                color: AppColors.white,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: AppConstrainedScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: <Widget>[
              ProfileInfoInput(
                autofocus: true,
                readOnly: false,
                value: _initialValue.value,
                label: widget.infoLabel,
                infoType: widget.infoType,
                textController: _valueController,
                prefixText: prefixForInfoType(widget.infoType),
              ),
              // Live handle warning, like the sign-up screen.
              if (widget.infoType == ProfileEditInfoType.username)
                AnimatedBuilder(
                  animation: _valueController,
                  builder: (context, _) {
                    final err = _usernameError;
                    if (err == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          err,
                          style: context.bodySmall?.apply(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              gapH12,
              if (widget.description != null)
                Text(
                  widget.description!,
                  style: context.bodySmall?.apply(color: AppColors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groups the edit fields so a long form reads as a few short ones.
class _EditSectionHeader extends StatelessWidget {
  const _EditSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: context.labelSmall?.copyWith(
          color: context.adaptiveColor.withValues(alpha: 0.5),
          letterSpacing: 1.1,
          fontWeight: AppFontWeight.semiBold,
        ),
      ),
    ),
  );
}

/// Date-of-birth row. Opens the platform picker rather than asking people to
/// type a date, and saves as soon as one is chosen.
class _BirthdayInput extends StatelessWidget {
  const _BirthdayInput({this.birthday});

  /// ISO `yyyy-MM-dd`, as stored.
  final String? birthday;

  static String _display(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final current = birthday == null ? null : DateTime.tryParse(birthday!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null || !context.mounted) return;
    context.read<UserProfileBloc>().add(
      UserProfileUpdateRequested(
        birthday: picked.toIso8601String().split('T').first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.birthdayText, style: context.bodyLarge),
                const Gap.v(AppSpacing.xxs),
                Text(
                  birthday == null ? '—' : _display(birthday!),
                  style: context.bodyMedium?.copyWith(
                    color: context.adaptiveColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right,
              color: context.adaptiveColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gender row. A short, fixed set of options rather than free text — typing it
/// invites typos and makes the value useless to filter on later.
class _GenderInput extends StatelessWidget {
  const _GenderInput({this.gender});

  /// Stored value: `male`, `female`, or null when unspecified.
  final String? gender;

  static const _options = ['male', 'female'];

  String _label(BuildContext context, String? value) => switch (value) {
    'male' => context.l10n.genderMaleText,
    'female' => context.l10n.genderFemaleText,
    _ => context.l10n.genderNotSayText,
  };

  Future<void> _pick(BuildContext context) async {
    final users = context.read<UserRepository>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _options)
              ListTile(
                title: Text(
                  _label(sheetContext, option.isEmpty ? null : option),
                ),
                trailing: (gender ?? '') == option
                    ? const Icon(Icons.check, color: AppColors.blue)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await users.updateUser(gender: picked.isEmpty ? '' : picked);
  }

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.genderText, style: context.bodyLarge),
                const Gap.v(AppSpacing.xxs),
                Text(
                  _label(context, gender?.isEmpty ?? true ? null : gender),
                  style: context.bodyMedium?.copyWith(
                    color: context.adaptiveColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right,
              color: context.adaptiveColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
