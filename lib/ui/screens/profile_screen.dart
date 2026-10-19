import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/day_panel.dart';
import '../widgets/month_calendar.dart';
import '../widgets/post_actions.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'story_viewer.dart';

Future<void> openProfile(BuildContext context, String userId) {
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId, this.isTab = false});
  final String userId;
  final bool isTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(context.read<AppState>().now);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.users[widget.userId];
    if (u == null) return const Scaffold();
    final me = s.currentUserId!;
    final own = u.id == me;
    final blocked = s.isBlockedBetween(me, u.id);
    final closed = !own && u.isPrivate && !s.isFollowing(me, u.id);
    final iBlocked = s.blocked[me]?.contains(u.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (u.isPrivate)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_outline, size: 18),
              ),
            Text(u.nick),
          ],
        ),
        actions: [
          if (own)
            IconButton(
              key: const Key('openSettings'),
              tooltip: context.t('settings'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            )
          else
            IconButton(
              tooltip: context.t('more'),
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _otherMenu(context, u, iBlocked),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Header(user: u, own: own, blocked: blocked),
          if (blocked)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.t('blockedUser'),
                textAlign: TextAlign.center,
              ),
            )
          else if (closed)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    context.t('privateProfile'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t('privateProfileText', {'nick': u.nick}),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            MonthCalendar(
              ownerId: u.id,
              selected: _selected,
              onSelect: (d) => setState(() => _selected = d),
              onOpenStories: (day, st) => openStories(context, st),
            ),
            const SizedBox(height: 8),
            DayPanel(ownerId: u.id, day: _selected),
          ],
        ],
      ),
    );
  }

  Future<void> _otherMenu(BuildContext context, AppUser u, bool iBlocked) {
    final s = context.read<AppState>();
    return showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              title: Text(
                context.t('report'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(c);
                showReport(context, userId: u.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(context.t(iBlocked ? 'unblock' : 'block')),
              onTap: () {
                Navigator.pop(c);
                iBlocked ? s.unblock(u.id) : blockUser(context, u);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.own, required this.blocked});
  final AppUser user;
  final bool own;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.currentUserId!;
    final active = blocked ? <Story>[] : s.activeStoriesOf(user.id);
    final followers = s.followersOf(user.id).length;
    final followingN = s.followingOf(user.id).length;
    final days = s.publishedDays(user.id).length;
    final streak = s.streak(user.id);
    final canSeeLists = own || !user.isPrivate || s.isFollowing(me, user.id);
    final details = [
      if (user.city.isNotEmpty) user.city,
      if (user.birthday != null)
        DateFormat('d MMMM', langOf(context)).format(user.birthday!),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: active.isEmpty
                    ? null
                    : () => openStories(context, active),
                child: Avatar(user: user, size: 80, ring: active.isNotEmpty),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Count(
                      value: followers,
                      label: plural(context, followers, 'followers'),
                      onTap: canSeeLists
                          ? () => _openList(
                              context,
                              context.t('followersTitle'),
                              s.followersOf(user.id).toList(),
                            )
                          : null,
                    ),
                    _Count(
                      value: followingN,
                      label: context.t('followingCount'),
                      onTap: canSeeLists
                          ? () => _openList(
                              context,
                              context.t('followingTitle'),
                              s.followingOf(user.id).toList(),
                            )
                          : null,
                    ),
                    _Count(value: days, label: plural(context, days, 'days')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: context.t('streakHint'),
                  child: Text(
                    '🔥 $streak',
                    style: const TextStyle(
                      color: Color(0xFFD98C5F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (details.isNotEmpty)
            Text(
              details,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (user.link.isNotEmpty)
            Text(user.link, style: const TextStyle(color: AppColors.turquoise)),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(user.bio),
          ],
          const SizedBox(height: 12),
          if (own)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                child: Text(context.t('editProfile')),
              ),
            )
          else if (!blocked)
            Row(
              children: [
                Expanded(child: _FollowButton(userId: user.id)),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('messageButton'),
                    onPressed: () => openChat(context, s.chatWith(user.id)),
                    child: Text(context.t('message')),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _openList(BuildContext context, String title, List<String> ids) {
    final s = context.read<AppState>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ids.isEmpty
              ? Center(child: Text(context.t('nobodyYet')))
              : ListView(
                  children: [
                    for (final id in ids)
                      UserTile(
                        user: s.user(id),
                        onTap: () => openProfile(context, id),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.onTap});
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.currentUserId!;
    if (s.isFollowing(me, userId)) {
      return OutlinedButton(
        key: const Key('unfollowButton'),
        onPressed: () => s.unfollow(userId),
        child: Text(context.t('following')),
      );
    }
    if (s.hasRequested(me, userId)) {
      return OutlinedButton(
        onPressed: () => s.unfollow(userId),
        child: Text(context.t('requested')),
      );
    }
    return FilledButton(
      key: const Key('followButton'),
      onPressed: () => s.follow(userId),
      child: Text(context.t('follow')),
    );
  }
}
