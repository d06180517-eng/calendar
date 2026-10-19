import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/reminder_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Пометка: «Свободная» (текстовая сторис) или «План».
/// Будущий день или существующий план открывают сразу план.
Future<void> openNoteEditor(BuildContext context, {DateTime? day, Plan? plan}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NoteEditor(day: day, plan: plan),
    ),
  );
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, this.day, this.plan});
  final DateTime? day;
  final Plan? plan;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late bool _isPlan;
  late bool _planOnly;
  late final TextEditingController _text;
  Color _bg = textStoryColors.first;
  bool _keep = true;
  late DateTime _date;
  late TimeOfDay _time;
  bool _remind = true;
  late Audience _audience;
  bool _audienceTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = context.read<AppState>().now;
    final p = widget.plan;
    final future =
        widget.day != null && dateOnly(widget.day!).isAfter(dateOnly(now));
    _planOnly = p != null || future;
    _isPlan = _planOnly;
    _text = TextEditingController(text: p?.text ?? '');
    if (p != null) {
      _date = dateOnly(p.planAt);
      _time = TimeOfDay.fromDateTime(p.planAt);
      _remind = p.remind;
    } else {
      _date = future
          ? dateOnly(widget.day!)
          : dateOnly(now.add(const Duration(days: 1)));
      _time = const TimeOfDay(hour: 10, minute: 0);
    }
    _audience = p?.visibility ?? _defaultAudience();
    _audienceTouched = p != null;
  }

  Audience _defaultAudience() => _isPlan ? Audience.onlyMe : Audience.everyone;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  DateTime get _at =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final s = context.read<AppState>();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(dateOnly(s.now)) ? _date : dateOnly(s.now),
      lastDate: DateTime(s.now.year + 10),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    final reminders = context.read<ReminderService>();
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.t('emptyText'));
      return;
    }
    if (!_isPlan) {
      s.createTextStory(
        text: text,
        background: _bg,
        visibility: _audience,
        keepInCalendar: _keep,
      );
      showSnack(context, context.t('storyPublished'));
      Navigator.pop(context);
      return;
    }
    if (_remind && !_at.isAfter(s.now)) {
      setState(() => _error = context.t('planInPast'));
      return;
    }
    final title = context.t('planReminderTitle');
    Plan plan;
    if (widget.plan == null) {
      plan = s.createPlan(
        text: text,
        planAt: _at,
        remind: _remind,
        visibility: _audience,
      );
    } else {
      plan = widget.plan!;
      s.updatePlan(plan, (p) {
        p
          ..text = text
          ..planAt = _at
          ..remind = _remind
          ..visibility = _audience;
      });
    }
    await reminders.schedulePlan(plan, title);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = context.read<AppState>();
    final reminders = context.read<ReminderService>();
    if (!await confirm(
      context,
      context.t('deletePlanQ'),
      ok: context.t('delete'),
    )) {
      return;
    }
    await reminders.cancelPlan(widget.plan!);
    s.deletePost(widget.plan!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fg = onTextStory(_bg);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(widget.plan == null ? 'createNote' : 'notePlan')),
        actions: [
          if (widget.plan != null)
            IconButton(
              tooltip: context.t('delete'),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              key: const Key('saveNote'),
              onPressed: _save,
              child: Text(context.t(_isPlan ? 'save' : 'publish')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_planOnly) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.text_fields),
                  label: Text(context.t('noteFree')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(context.t('notePlan')),
                ),
              ],
              selected: {_isPlan},
              onSelectionChanged: (v) => setState(() {
                _isPlan = v.first;
                _error = null;
                if (!_audienceTouched) _audience = _defaultAudience();
              }),
            ),
            const SizedBox(height: 16),
          ],
          if (!_isPlan) ...[
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: TextField(
                  key: const Key('noteText'),
                  controller: _text,
                  maxLength: maxNoteLength,
                  maxLines: null,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: fg,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  cursorColor: fg,
                  decoration: InputDecoration(
                    hintText: context.t('noteFreeHint'),
                    hintStyle: TextStyle(color: fg.withValues(alpha: 0.6)),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterStyle: TextStyle(color: fg.withValues(alpha: 0.7)),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in textStoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _bg = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == _bg
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: c == _bg ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.t('textStoryHelp'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _keep,
              onChanged: (v) => setState(() => _keep = v),
              title: Text(context.t('keepInCalendar')),
            ),
          ] else ...[
            TextField(
              key: const Key('noteText'),
              controller: _text,
              maxLength: maxNoteLength,
              minLines: 3,
              maxLines: 6,
              autofocus: widget.plan == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: context.t('notePlanHint')),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(formatDate(context, _date)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              title: Text(context.t('remind')),
              secondary: const Icon(Icons.notifications_active_outlined),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          AudiencePicker(
            value: _audience,
            onChanged: (a) => setState(() {
              _audience = a;
              _audienceTouched = true;
            }),
          ),
        ],
      ),
    );
  }
}
