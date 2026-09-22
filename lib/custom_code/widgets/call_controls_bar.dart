import 'package:flutter/material.dart';

import '../../shared_pages/design/expatlio_design.dart';

const callControlsBarKey = ValueKey<String>('call_controls_bar');
const callCameraControlKey = ValueKey<String>('call_camera_control');
const callMicrophoneControlKey = ValueKey<String>('call_microphone_control');
const callChatControlKey = ValueKey<String>('call_chat_control');
const callTranslationControlKey = ValueKey<String>('call_translation_control');
const callEndControlKey = ValueKey<String>('call_end_control');

/// Presentation-only controls for an active video call.
///
/// Media state and call lifecycle remain owned by the parent. This widget only
/// maps immutable inputs to controls and forwards user intent through callbacks.
class CallControlsBar extends StatelessWidget {
  const CallControlsBar({
    super.key,
    required this.isVisible,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.isChatOpen,
    required this.unreadChatCount,
    required this.onCameraPressed,
    required this.onMicrophonePressed,
    required this.onChatPressed,
    required this.onEndCallPressed,
    this.onTranslationPressed,
  }) : assert(unreadChatCount >= 0);

  final bool isVisible;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final bool isChatOpen;
  final int unreadChatCount;
  final VoidCallback onCameraPressed;
  final VoidCallback onMicrophonePressed;
  final VoidCallback onChatPressed;
  final VoidCallback? onTranslationPressed;
  final VoidCallback onEndCallPressed;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Row(
      key: callControlsBarKey,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallControlButton(
          controlKey: callCameraControlKey,
          icon: cameraEnabled ? Icons.videocam : Icons.videocam_off,
          isActive: cameraEnabled,
          tooltip: cameraEnabled
              ? _text(context, ru: 'Выключить камеру', en: 'Turn camera off')
              : _text(context, ru: 'Включить камеру', en: 'Turn camera on'),
          semanticLabel: cameraEnabled
              ? _text(
                  context,
                  ru: 'Камера включена. Выключить камеру',
                  en: 'Camera on. Turn camera off',
                )
              : _text(
                  context,
                  ru: 'Камера выключена. Включить камеру',
                  en: 'Camera off. Turn camera on',
                ),
          semanticHint: _text(
            context,
            ru: 'Переключает камеру в звонке',
            en: 'Toggles the camera during the call',
          ),
          semanticToggled: cameraEnabled,
          onPressed: onCameraPressed,
        ),
        _CallControlButton(
          controlKey: callMicrophoneControlKey,
          icon: microphoneEnabled ? Icons.mic : Icons.mic_off,
          isActive: microphoneEnabled,
          tooltip: microphoneEnabled
              ? _text(
                  context,
                  ru: 'Выключить микрофон',
                  en: 'Mute microphone',
                )
              : _text(
                  context,
                  ru: 'Включить микрофон',
                  en: 'Unmute microphone',
                ),
          semanticLabel: microphoneEnabled
              ? _text(
                  context,
                  ru: 'Микрофон включен. Выключить микрофон',
                  en: 'Microphone on. Mute microphone',
                )
              : _text(
                  context,
                  ru: 'Микрофон выключен. Включить микрофон',
                  en: 'Microphone muted. Unmute microphone',
                ),
          semanticHint: _text(
            context,
            ru: 'Переключает микрофон в звонке',
            en: 'Toggles the microphone during the call',
          ),
          semanticToggled: microphoneEnabled,
          onPressed: onMicrophonePressed,
        ),
        _CallControlButton(
          controlKey: callChatControlKey,
          icon: isChatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
          isActive: isChatOpen,
          tooltip: _chatControlTooltip(context),
          semanticLabel: _chatControlSemanticLabel(context),
          semanticHint: _text(
            context,
            ru: 'Открывает или скрывает чат звонка',
            en: 'Opens or closes the call chat',
          ),
          semanticToggled: isChatOpen,
          onPressed: onChatPressed,
          badgeCount: unreadChatCount,
        ),
        if (onTranslationPressed case final callback?)
          _CallControlButton(
            controlKey: callTranslationControlKey,
            icon: Icons.translate_rounded,
            isActive: true,
            tooltip: _text(
              context,
              ru: 'Быстрый перевод',
              en: 'Quick translation',
            ),
            semanticLabel: _text(
              context,
              ru: 'Открыть быстрый перевод',
              en: 'Open quick translation',
            ),
            semanticHint: _text(
              context,
              ru: 'Переводит слово или фразу во время звонка',
              en: 'Translates a word or phrase during the call',
            ),
            onPressed: callback,
          ),
        _CallControlButton(
          controlKey: callEndControlKey,
          icon: Icons.call_end,
          isActive: true,
          tooltip: _text(
            context,
            ru: 'Завершить звонок',
            en: 'End call',
          ),
          semanticLabel: _text(
            context,
            ru: 'Завершить звонок',
            en: 'End call',
          ),
          semanticHint: _text(
            context,
            ru: 'Завершает текущий видеозвонок',
            en: 'Ends the current video call',
          ),
          onPressed: onEndCallPressed,
          isEndCall: true,
        ),
      ],
    );
  }

  String _chatControlTooltip(BuildContext context) {
    final baseLabel = isChatOpen
        ? _text(context, ru: 'Закрыть чат', en: 'Close chat')
        : _text(context, ru: 'Открыть чат', en: 'Open chat');
    if (!isChatOpen && unreadChatCount > 0) {
      return '$baseLabel, '
          '${_unreadMessagesSemanticLabel(context, unreadChatCount)}';
    }
    return baseLabel;
  }

  String _chatControlSemanticLabel(BuildContext context) {
    if (isChatOpen) {
      return _text(
        context,
        ru: 'Чат открыт. Закрыть чат',
        en: 'Chat open. Close chat',
      );
    }
    if (unreadChatCount > 0) {
      return '${_text(context, ru: 'Чат закрыт. Открыть чат.', en: 'Chat closed. Open chat.')} '
          '${_unreadMessagesSemanticLabel(context, unreadChatCount)}';
    }
    return _text(
      context,
      ru: 'Чат закрыт. Открыть чат',
      en: 'Chat closed. Open chat',
    );
  }

  String _unreadMessagesSemanticLabel(BuildContext context, int count) {
    if (count > 99) {
      return _text(
        context,
        ru: 'Больше 99 непрочитанных сообщений',
        en: 'More than 99 unread messages',
      );
    }
    return _text(
      context,
      ru: 'Непрочитанных сообщений: ${_formatUnreadChatCount(count)}',
      en: 'Unread messages: ${_formatUnreadChatCount(count)}',
    );
  }

  String _text(
    BuildContext context, {
    required String ru,
    required String en,
  }) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : ru;

  String _formatUnreadChatCount(int count) => count > 99 ? '99+' : '$count';
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.controlKey,
    required this.icon,
    required this.isActive,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
    this.isEndCall = false,
    this.semanticHint,
    this.semanticToggled,
    this.badgeCount = 0,
  });

  final Key controlKey;
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool isEndCall;
  final String? semanticHint;
  final bool? semanticToggled;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: controlKey,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isEndCall
                ? Colors.red.withValues(alpha: 0.9)
                : (isActive
                    ? Colors.black.withValues(alpha: 0.76)
                    : Colors.black.withValues(alpha: 0.6)),
            shape: BoxShape.circle,
            border: isEndCall
                ? null
                : Border.all(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
          ),
          child: Semantics(
            container: true,
            button: true,
            enabled: true,
            label: semanticLabel,
            hint: semanticHint,
            toggled: semanticToggled,
            onTap: onPressed,
            child: Tooltip(
              message: tooltip,
              excludeFromSemantics: true,
              child: ExcludeSemantics(
                child: IconButton(
                  icon: Icon(icon, color: Colors.white),
                  onPressed: onPressed,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: ExcludeSemantics(
              child: _UnreadBadge(label: _formatUnreadChatCount(badgeCount)),
            ),
          ),
      ],
    );
  }

  String _formatUnreadChatCount(int count) => count > 99 ? '99+' : '$count';
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ExpatlioDesign.space8,
        vertical: ExpatlioDesign.space4,
      ),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF2F80ED),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusSmall),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
