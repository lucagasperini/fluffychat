//@dart=2.12

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';

import 'package:fluffychat/pages/story/story_page.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/string_color.dart';
import 'package:fluffychat/widgets/avatar.dart';

class StoryView extends StatelessWidget {
  final StoryPageController controller;
  const StoryView(this.controller, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            controller.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(0, 0),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
          leading: Avatar(
            mxContent: controller.avatar,
            name: controller.title,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: FutureBuilder<List<Event>>(
        future: controller.loadStory,
        builder: (context, snapshot) {
          final error = snapshot.error;
          if (error != null) {
            return Center(child: Text(error.toLocalizedString(context)));
          }
          final events = snapshot.data;
          if (events == null) {
            return const Center(
                child: CircularProgressIndicator.adaptive(
              strokeWidth: 2,
            ));
          }
          if (events.isEmpty) {
            return Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Avatar(
                    mxContent: controller.avatar,
                    name: controller.title,
                    size: 128,
                    fontSize: 64,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    L10n.of(context)!.thisUserHasNotPostedAnythingYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            );
          }
          final event = events[controller.index];
          final backgroundColor = event.content.tryGet<String>('body')?.color ??
              Theme.of(context).primaryColor;
          final backgroundColorDark =
              event.content.tryGet<String>('body')?.darkColor ??
                  Theme.of(context).primaryColorDark;
          if (event.messageType == MessageTypes.Text) {
            controller.loadingModeOff();
          }
          return GestureDetector(
            onTapDown: controller.hold,
            onTapUp: controller.unhold,
            child: Stack(
              children: [
                if (event.messageType == MessageTypes.Video &&
                    PlatformInfos.isMobile)
                  FutureBuilder<VideoPlayerController>(
                    future: controller.loadVideoController(event),
                    builder: (context, snapshot) {
                      final videoPlayerController = snapshot.data;
                      if (videoPlayerController == null) {
                        controller.loadingModeOn();
                        return Container();
                      }
                      controller.loadingModeOff();
                      return Center(child: VideoPlayer(videoPlayerController));
                    },
                  ),
                if (event.messageType == MessageTypes.Image ||
                    (event.messageType == MessageTypes.Video &&
                        !PlatformInfos.isMobile))
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: FutureBuilder<MatrixFile>(
                      future: controller.downloadAndDecryptAttachment(
                          event, event.messageType == MessageTypes.Video),
                      builder: (context, snapshot) {
                        final matrixFile = snapshot.data;
                        if (matrixFile == null) {
                          controller.loadingModeOn();
                          final hash = event.infoMap['xyz.amorgan.blurhash'];
                          return hash is String
                              ? BlurHash(
                                  hash: hash,
                                  imageFit: BoxFit.cover,
                                )
                              : Container();
                        }
                        controller.loadingModeOff();
                        return Image.memory(
                          matrixFile.bytes,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    gradient: event.messageType == MessageTypes.Text
                        ? LinearGradient(
                            colors: [
                              backgroundColorDark,
                              backgroundColor,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    controller.loadingMode
                        ? L10n.of(context)!.loadingPleaseWait
                        : event.content.tryGet<String>('body') ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      backgroundColor: event.messageType == MessageTypes.Text
                          ? null
                          : Colors.black,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < events.length; i++)
                          Expanded(
                            child: i == controller.index
                                ? LinearProgressIndicator(
                                    color: Colors.white,
                                    minHeight: 2,
                                    backgroundColor: Colors.grey.shade600,
                                    value: controller.loadingMode
                                        ? null
                                        : controller.progress.inMilliseconds /
                                            StoryPageController
                                                .maxProgress.inMilliseconds,
                                  )
                                : Container(
                                    margin: const EdgeInsets.all(4),
                                    height: 2,
                                    color: i < controller.index
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
