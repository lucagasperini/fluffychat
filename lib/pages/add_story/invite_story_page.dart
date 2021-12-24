//@dart=2.12

import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions.dart/client_stories_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';

class InviteStoryPage extends StatefulWidget {
  final Room? storiesRoom;
  const InviteStoryPage({
    required this.storiesRoom,
    Key? key,
  }) : super(key: key);

  @override
  _InviteStoryPageState createState() => _InviteStoryPageState();
}

class _InviteStoryPageState extends State<InviteStoryPage> {
  Set<String> _undecided = {};
  final Set<String> _invite = {};

  void _inviteAction() async {
    final result = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final client = Matrix.of(context).client;
        final room = await client.getStoriesRoom(context);
        if (room == null) {
          await client.createStoriesRoom(_invite.toList());
        } else {
          for (final userId in _invite) {
            room.invite(userId);
          }
        }

        _undecided.removeAll(_invite);
        await client.setStoriesBlockList(_undecided.toList());
      },
    );
    if (result.error != null) return;
    Navigator.of(context).pop<bool>(true);
  }

  Future<List<User>>? loadContacts;

  @override
  Widget build(BuildContext context) {
    loadContacts ??= Matrix.of(context)
        .client
        .getUndecidedContactsForStories(widget.storiesRoom)
        .then((contacts) {
      if (contacts.length < 20) {
        _invite.addAll(contacts.map((u) => u.id));
      }
      return contacts;
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<bool>(false),
        ),
        title: Text(L10n.of(context)!.whoCanSeeMyStories),
      ),
      body: FutureBuilder<List<User>>(
          future: loadContacts,
          builder: (context, snapshot) {
            final contacts = snapshot.data;
            if (contacts == null) {
              final error = snapshot.error;
              if (error != null) {
                return Center(child: Text(error.toLocalizedString(context)));
              }
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            _undecided = contacts.map((u) => u.id).toSet();
            return ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, i) => SwitchListTile.adaptive(
                value: _invite.contains(contacts[i].id),
                onChanged: (b) => setState(() => b
                    ? _invite.add(contacts[i].id)
                    : _invite.remove(contacts[i].id)),
                secondary: Avatar(
                  mxContent: contacts[i].avatarUrl,
                  name: contacts[i].calcDisplayname(),
                ),
                title: Text(contacts[i].calcDisplayname()),
              ),
            );
          }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inviteAction,
        label: Text(L10n.of(context)!.publish),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        icon: const Icon(Icons.upload_outlined),
      ),
    );
  }
}
