import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/cloudinary.dart';
import '../theme.dart';
import 'media_view.dart';

/// Аватар — квадратик со скруглёнными краями, как дни в календаре.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.user,
    this.size = 40,
    this.ring = false,
  });
  final AppUser user;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.3);
    Widget child;
    if (user.avatarBytes != null) {
      child = Image.memory(
        Uint8List.fromList(user.avatarBytes!),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (user.avatarUrl != null) {
      child = Image.network(
        sizedImageUrl(user.avatarUrl!, (size * 3).round()),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            SizedBox.square(dimension: size),
      );
    } else {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              user.avatarColor.withValues(alpha: 0.55),
              user.avatarColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.42,
          ),
        ),
      );
    }
    final img = ClipRRect(borderRadius: r, child: child);
    if (!ring) return img;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: AppColors.turquoise, width: 2),
      ),
      child: img,
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({
    super.key,
    required this.user,
    this.onTap,
    this.trailing,
    this.subtitle,
  });
  final AppUser user;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Avatar(user: user, size: 44),
    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle ?? '@${user.nick}'),
    trailing: trailing,
  );
}

/// Выбор «кто видит запись».
class AudiencePicker extends StatelessWidget {
  const AudiencePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Audience value;
  final ValueChanged<Audience> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.t('whoSees'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        for (final a in Audience.values)
          ChoiceChip(
            label: Text(audienceLabel(context, a)),
            avatar: Icon(audienceIcon(a), size: 16),
            selected: value == a,
            onSelected: (_) => onChanged(a),
          ),
      ],
    );
  }
}

String audienceLabel(BuildContext context, Audience a) => switch (a) {
  Audience.onlyMe => context.t('onlyMe'),
  Audience.followers => context.t('followersAudience'),
  Audience.everyone => context.t('everyone'),
};

IconData audienceIcon(Audience a) => switch (a) {
  Audience.onlyMe => Icons.lock_outline,
  Audience.followers => Icons.group_outlined,
  Audience.everyone => Icons.public,
};

/// Небольшая плашка-превью медиа с закруглёнными краями.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.media,
    this.size = 56,
    this.radius = 10,
  });
  final Media media;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: size,
      height: size,
      child: MediaView(media: media, thumbnail: true),
    ),
  );
}

String timeAgo(BuildContext context, DateTime t) {
  final d = context.read<AppState>().now.difference(t);
  if (d.inMinutes < 1) return context.t('justNow');
  if (d.inHours < 1) return context.t('minAgo', {'n': '${d.inMinutes}'});
  if (d.inDays < 1) return context.t('hAgo', {'n': '${d.inHours}'});
  if (d.inDays < 7) return context.t('dAgo', {'n': '${d.inDays}'});
  return formatDate(context, t);
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

Future<bool> confirm(BuildContext context, String text, {String? ok}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(context.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok ?? context.t('ok')),
        ),
      ],
    ),
  );
  return r ?? false;
}
