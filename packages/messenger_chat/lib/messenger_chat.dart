library messenger_chat;

import 'dart:convert';

import 'package:audio_session/audio_session.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:messenger_chat/data/enum/chat_language.dart';
import 'package:messenger_chat/data/enum/chat_connection_status.dart';
import 'package:messenger_chat/data/model/chat_model.dart';
import 'package:messenger_chat/data/model/unread_message_data.dart';
import 'package:messenger_chat/service/chat_controller/chat_controller.dart';
import 'package:messenger_chat/data/model/toast_data.dart';
import 'package:messenger_chat/utils/app_permission.dart';

import 'package:dio/dio.dart';

import 'package:equatable/equatable.dart';

import 'package:file_picker/file_picker.dart';

import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:image_picker/image_picker.dart';

import 'package:intl/intl.dart';

import 'package:just_audio/just_audio.dart' hide AudioSource;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/cupertino.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';

import 'dart:async';

import 'dart:developer';

import 'dart:io';

import 'dart:math' as math;

import 'dart:ui' as ui;

import 'dart:ui';

import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';

import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';


import 'package:vibration/vibration.dart';

import 'package:video_player/video_player.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:visibility_detector/visibility_detector.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as epf;
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:messenger_chat/data/enum/chat_connection_status.dart';
export 'package:messenger_chat/data/enum/chat_language.dart';
export 'package:messenger_chat/service/chat_controller/chat_controller.dart';

export 'package:messenger_chat/data/model/chat_model.dart';

export 'package:messenger_chat/data/model/unread_message_data.dart';

export 'package:messenger_chat/data/enum/chat_language.dart';

part 'platform/presantation/styles/chat_app_bar_style.dart';
part 'platform/presantation/styles/chat_list_style.dart';
part 'platform/presantation/chat_list.dart';
part 'platform/presantation/widgets/conversation_tile.dart';

part 'utils/crm_icons.dart';
part 'utils/chat_logger.dart';
part 'api/chat_user.dart';
part 'api/chat_transport.dart';
part 'api/chat_conversation.dart';
part 'api/chat_list_transport.dart';
part 'api/chat_features.dart';
part 'api/chat_runtime.dart';
part 'utils/maybe_blur.dart';

part 'core/either/either.dart';

part 'core/failures/failure.dart';

part 'core/methods/handle_requests.dart';

part 'core/methods/handle_source.dart';

part 'core/mimetype/mimetype_detector.dart';

part 'core/image/image_size_detector.dart';

part 'core/video/video_size_detector.dart';

part 'core/usecase/params_get_message.dart';


part 'data/model/audio_message_data.dart';

part 'data/model/message_model.dart';

part 'data/model/config_model.dart';

part 'data/model/upload_response.dart';

part 'platform/domain/repository/chat_repository.dart';


part 'platform/domain/usecase/get_message.dart';


part 'platform/domain/usecase/upload_message.dart';

part 'data/model/upload_params.dart';

part 'data/model/no_params.dart';

part 'core/exception/server_exception.dart';

part 'service/socket/chat_socket.dart';
part 'platform/presantation/animation/chat_bubble_animation.dart';

part 'platform/presantation/animation/scale.dart';

part 'platform/presantation/animation/typing_animation.dart';

part 'platform/presantation/styles/chat_decoration.dart';

part 'platform/presantation/styles/chat_message_style.dart';

part 'platform/presantation/styles/chat_text_field_style.dart';

part 'platform/presantation/widgets/chat_text_field.dart';

part 'service/audio_service/audio_message_controller.dart';

part 'service/audio_service/audio_player.dart';

part 'service/audio_service/audio_session.dart';


part 'utils/lorem_ipsum.dart';

part 'utils/duartion_formatter.dart';

part 'utils/constants/duration_contants.dart';



part 'core/usecase/usecase.dart';

part 'platform/presantation/chat.dart';

part 'platform/presantation/image_view_screen.dart';

part 'platform/presantation/video_view_screen.dart';

part 'platform/presantation/widgets/modal_sheet/file_upload_modal_sheet.dart';


part 'data/enum/content_type.dart';

part 'core/localization/chat_localizations.dart';

part 'core/localization/uzbek.dart';

part 'core/localization/uzbek_cyrillic.dart';

part 'core/localization/russian.dart';

part 'core/localization/english.dart';
part 'core/localization/app_texts.dart';


part 'data/model/voice_service_data.dart';

part 'platform/data/repository/chat_repository_impl.dart';

part 'platform/data/network/chat_network_data_source.dart';

part 'platform/presantation/animation/animated_visible.dart';

part 'platform/presantation/animation/animated_visible_vertical.dart';

part 'platform/presantation/animation/mic_pulse_animation.dart';

part 'platform/presantation/animation/ripple.dart';

part 'platform/presantation/animation/slider.dart';

part 'platform/presantation/cubit/chat_state.dart';

part 'platform/presantation/cubit/chat_cubit.dart';

part 'platform/presantation/widgets/messages/audio_message.dart';

part 'platform/presantation/widgets/messages/file_icon.dart';

part 'platform/presantation/widgets/messages/file_message.dart';

part 'platform/presantation/widgets/messages/image_message.dart';

part 'platform/presantation/widgets/messages/video_message.dart';

part 'platform/presantation/widgets/messages/text_message.dart';

part 'platform/presantation/widgets/shimmer/custom_shimmer.dart';

part 'platform/presantation/widgets/chat_appbar.dart';

part 'platform/presantation/widgets/peer_content.dart';

part 'platform/presantation/widgets/chat_bubble.dart';

part 'platform/presantation/widgets/painter/pulse_painter.dart';

part 'platform/presantation/widgets/painter/swipe_painter.dart';

part 'platform/presantation/widgets/painter/wave_painter.dart';

part 'platform/presantation/widgets/image_network.dart';

part 'platform/presantation/widgets/image_asset.dart';

part 'platform/presantation/widgets/message_list.dart';
part 'platform/presantation/widgets/notifier/chat_toast_notifier.dart';

part 'platform/presantation/widgets/loading_progress.dart';

part 'platform/presantation/widgets/mic_button.dart';

part 'platform/presantation/widgets/general_effects_button.dart';

part 'platform/presantation/widgets/portrait_controls.dart';

part 'platform/presantation/widgets/swipe_cancel.dart';

part 'service/audio_service/voice_recorder.dart';

part 'service/controller/message_controller.dart';

part 'service/controller/notification_controller.dart';
part 'service/controller/crm_chat_controller.dart';
part 'service/outbox/outbox_service.dart';

part 'data/enum/message_status.dart';

part 'core/either/right.dart';

part 'core/either/left.dart';

part 'core/storage/secure_storage.dart';

part 'core/failures/server_failure.dart';

part 'utils/date_utility.dart';
