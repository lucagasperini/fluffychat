import 'dart:async';

import 'package:adaptive_dialog/adaptive_dialog.dart';

import 'package:matrix/matrix.dart';
import 'package:file_picker_cross/file_picker_cross.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/sentry_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_lock/flutter_app_lock.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vrouter/vrouter.dart';

import 'views/settings_view.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'bootstrap_dialog.dart';
import '../widgets/matrix.dart';
import '../config/app_config.dart';
import '../config/setting_keys.dart';

class Settings extends StatefulWidget {
  @override
  SettingsController createState() => SettingsController();
}

class SettingsController extends State<Settings> {
  Future<dynamic> profileFuture;
  Profile profile;
  Future<bool> crossSigningCachedFuture;
  bool crossSigningCached;
  Future<bool> megolmBackupCachedFuture;
  bool megolmBackupCached;
  bool profileUpdated = false;

  void updateProfile() => setState(() {
        profileUpdated = true;
        profile = profileFuture = null;
      });

  void logoutAction() async {
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context).areYouSureYouWantToLogout,
          okLabel: L10n.of(context).yes,
          cancelLabel: L10n.of(context).cancel,
        ) ==
        OkCancelResult.cancel) {
      return;
    }
    final matrix = Matrix.of(context);
    await showFutureLoadingDialog(
      context: context,
      future: () => matrix.client.logout(),
    );
  }

  void changePasswordAccountAction() async {
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).changePassword,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      textFields: [
        DialogTextField(
          hintText: L10n.of(context).pleaseEnterYourPassword,
          obscureText: true,
          minLines: 1,
          maxLines: 1,
        ),
        DialogTextField(
          hintText: L10n.of(context).chooseAStrongPassword,
          obscureText: true,
          minLines: 1,
          maxLines: 1,
        ),
      ],
    );
    if (input == null) return;
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context)
          .client
          .changePassword(input.last, oldPassword: input.first),
    );
    if (success.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).passwordHasBeenChanged)));
    }
  }

  void deleteAccountAction() async {
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context).warning,
          message: L10n.of(context).deactivateAccountWarning,
          okLabel: L10n.of(context).ok,
          cancelLabel: L10n.of(context).cancel,
        ) ==
        OkCancelResult.cancel) {
      return;
    }
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context).areYouSure,
          okLabel: L10n.of(context).yes,
          cancelLabel: L10n.of(context).cancel,
        ) ==
        OkCancelResult.cancel) {
      return;
    }
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).pleaseEnterYourPassword,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      textFields: [
        DialogTextField(
          obscureText: true,
          hintText: '******',
          minLines: 1,
          maxLines: 1,
        )
      ],
    );
    if (input == null) return;
    await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context).client.deactivateAccount(
            auth: AuthenticationPassword(
              password: input.single,
              user: Matrix.of(context).client.userID,
              identifier: AuthenticationUserIdentifier(
                  user: Matrix.of(context).client.userID),
            ),
          ),
    );
  }

  void setJitsiInstanceAction() async {
    const prefix = 'https://';
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).editJitsiInstance,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      textFields: [
        DialogTextField(
          initialText: AppConfig.jitsiInstance.replaceFirst(prefix, ''),
          prefixText: prefix,
        ),
      ],
    );
    if (input == null) return;
    var jitsi = prefix + input.single;
    if (!jitsi.endsWith('/')) {
      jitsi += '/';
    }
    final matrix = Matrix.of(context);
    await matrix.store.setItem(SettingKeys.jitsiInstance, jitsi);
    AppConfig.jitsiInstance = jitsi;
  }

  void setDisplaynameAction() async {
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).editDisplayname,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      textFields: [
        DialogTextField(
          initialText: profile?.displayname ??
              Matrix.of(context).client.userID.localpart,
        )
      ],
    );
    if (input == null) return;
    final matrix = Matrix.of(context);
    final success = await showFutureLoadingDialog(
      context: context,
      future: () =>
          matrix.client.setDisplayName(matrix.client.userID, input.single),
    );
    if (success.error == null) {
      updateProfile();
    }
  }

  void setAvatarAction() async {
    final action = profile?.avatarUrl == null
        ? AvatarAction.change
        : await showConfirmationDialog<AvatarAction>(
            context: context,
            title: L10n.of(context).pleaseChoose,
            actions: [
              AlertDialogAction(
                key: AvatarAction.change,
                label: L10n.of(context).changeYourAvatar,
                isDefaultAction: true,
              ),
              AlertDialogAction(
                key: AvatarAction.remove,
                label: L10n.of(context).removeYourAvatar,
                isDestructiveAction: true,
              ),
            ],
          );
    if (action == null) return;
    final matrix = Matrix.of(context);
    if (action == AvatarAction.remove) {
      final success = await showFutureLoadingDialog(
        context: context,
        future: () => matrix.client.setAvatarUrl(matrix.client.userID, null),
      );
      if (success.error == null) {
        updateProfile();
      }
      return;
    }
    MatrixFile file;
    if (PlatformInfos.isMobile) {
      final result = await ImagePicker().getImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 1600,
          maxHeight: 1600);
      if (result == null) return;
      file = MatrixFile(
        bytes: await result.readAsBytes(),
        name: result.path,
      );
    } else {
      final result =
          await FilePickerCross.importFromStorage(type: FileTypeCross.image);
      if (result == null) return;
      file = MatrixFile(
        bytes: result.toUint8List(),
        name: result.fileName,
      );
    }
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => matrix.client.setAvatar(file),
    );
    if (success.error == null) {
      updateProfile();
    }
  }

  Future<void> requestSSSSCache() async {
    final handle = Matrix.of(context).client.encryption.ssss.open();
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).askSSSSCache,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      textFields: [
        DialogTextField(
          hintText: L10n.of(context).passphraseOrKey,
          obscureText: true,
          minLines: 1,
          maxLines: 1,
        )
      ],
    );
    if (input != null) {
      final valid = await showFutureLoadingDialog(
          context: context,
          future: () async {
            // make sure the loading spinner shows before we test the keys
            await Future.delayed(Duration(milliseconds: 100));
            var valid = false;
            try {
              await handle.unlock(recoveryKey: input.single);
              valid = true;
            } catch (e, s) {
              SentryController.captureException(e, s);
            }
            return valid;
          });

      if (valid.result == true) {
        await handle.maybeCacheAll();
        await showOkAlertDialog(
          useRootNavigator: false,
          context: context,
          message: L10n.of(context).cachedKeys,
          okLabel: L10n.of(context).ok,
        );
        setState(() {
          crossSigningCachedFuture = null;
          crossSigningCached = null;
          megolmBackupCachedFuture = null;
          megolmBackupCached = null;
        });
      } else {
        await showOkAlertDialog(
          useRootNavigator: false,
          context: context,
          message: L10n.of(context).incorrectPassphraseOrKey,
          okLabel: L10n.of(context).ok,
        );
      }
    }
  }

  void setAppLockAction() async {
    final currentLock =
        await FlutterSecureStorage().read(key: SettingKeys.appLockKey);
    if (currentLock?.isNotEmpty ?? false) {
      await AppLock.of(context).showLockScreen();
    }
    final newLock = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).pleaseChooseAPasscode,
      message: L10n.of(context).pleaseEnter4Digits,
      cancelLabel: L10n.of(context).cancel,
      textFields: [
        DialogTextField(
          validator: (text) {
            if (text.isEmpty || (text.length == 4 && int.tryParse(text) >= 0)) {
              return null;
            }
            return L10n.of(context).pleaseEnter4Digits;
          },
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLines: 1,
          minLines: 1,
        )
      ],
    );
    if (newLock != null) {
      await FlutterSecureStorage()
          .write(key: SettingKeys.appLockKey, value: newLock.single);
      if (newLock.single.isEmpty) {
        AppLock.of(context).disable();
      } else {
        AppLock.of(context).enable();
      }
    }
  }

  void bootstrapSettingsAction() async {
    if (await Matrix.of(context).client.encryption.keyManager.isCached()) {
      if (OkCancelResult.ok ==
          await showOkCancelAlertDialog(
            useRootNavigator: false,
            context: context,
            title: L10n.of(context).keysCached,
            message: L10n.of(context).wipeChatBackup,
            isDestructiveAction: true,
            okLabel: L10n.of(context).ok,
            cancelLabel: L10n.of(context).cancel,
          )) {
        await BootstrapDialog(
          client: Matrix.of(context).client,
          wipe: true,
        ).show(context);
      }
      return;
    }
    await BootstrapDialog(
      client: Matrix.of(context).client,
    ).show(context);
  }

  void firstRunBootstrapAction() async {
    await BootstrapDialog(
      client: Matrix.of(context).client,
    ).show(context);
    VRouter.of(context).push('/rooms');
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    profileFuture ??= client
        .getProfileFromUserId(
      client.userID,
      cache: !profileUpdated,
      getFromRooms: !profileUpdated,
    )
        .then((p) {
      if (mounted) setState(() => profile = p);
      return p;
    });
    if (client.encryption != null) {
      crossSigningCachedFuture ??=
          client.encryption?.crossSigning?.isCached()?.then((c) {
        if (mounted) setState(() => crossSigningCached = c);
        return c;
      });
      megolmBackupCachedFuture ??=
          client.encryption?.keyManager?.isCached()?.then((c) {
        if (mounted) setState(() => megolmBackupCached = c);
        return c;
      });
    }
    return SettingsView(this);
  }
}

enum AvatarAction { change, remove }
