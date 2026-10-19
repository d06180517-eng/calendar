import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n.dart';
import '../../services/media_picker.dart';
import '../../services/reminder_service.dart';
import '../widgets/common.dart';
import '../theme.dart';

Future<void> openNoteEditor(
  BuildContext context, {
  DateTime? day,
  Note? note,
  NoteTemplate? template,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NoteEditor(day: day, note: note, template: template),
    ),
  );
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, this.day, this.note, this.template});
  final DateTime? day;
  final Note? note;
  final NoteTemplate? template;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late NoteTemplate _template;
  late final TextEditingController _text;
  Media? _photo;
  late DateTime _date;
  late TimeOfDay _time;
  bool _remind = true;
  late Audience _audience;
  bool _audienceTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final n = widget.note;
    _template = n?.template ?? widget.template ?? NoteTemplate.moment;
    _text = TextEditingController(text: n?.text ?? '');
    _photo = n?.photo;
    final now = s.now;
    final base = n?.planAt ?? n?.createdAt;
    if (base != null) {
      _date = dateOnly(base);
      _time = TimeOfDay.fromDateTime(base);
    } else {
      _date = dateOnly(widget.day ?? now);
      final future = _date.isAfter(dateOnly(now));
      if (future) _template = widget.template ?? NoteTemplate.plan;
      _time = sameDay(_date, now)
          ? TimeOfDay.fromDateTime(now)
          : const TimeOfDay(hour: 12, minute: 0);
      if (_template == NoteTemplate.plan && !future) {
        _date = dateOnly(now.add(const Duration(days: 1)));
        _time = const TimeOfDay(hour: 10, minute: 0);
      }
    }
    _remind = n?.remind ?? true;
    _audience = n?.visibility ?? _defaultAudience(_template);
    _audienceTouched = n != null;
  }

  Audience _defaultAudience(NoteTemplate t) =>
      t == NoteTemplate.plan ? Audience.onlyMe : Audience.everyone;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  DateTime get _at =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
  bool get _isPlan => _template == NoteTemplate.plan;

  Future<void> _pickPhoto() async {
    try {
      final m = await MediaPicker().image();
      if (m != null) setState(() => _photo = m);
    } catch (_) {
      if (mounted) showSnack(context, context.t('pickFailed'));
    }
  }

  Future<void> _pickDate() async {
    final s = context.read<AppState>();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
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
    if (_isPlan && _remind && !_at.isAfter(s.now)) {
      setState(() => _error = context.t('planInPast'));
      return;
    }
    final title = context.t('planReminderTitle');
    Note note;
    if (widget.note == null) {
      note = s.createNote(
        template: _template,
        text: text,
        photo: _photo,
        at: _isPlan ? s.now : _at,
        planAt: _isPlan ? _at : null,
        remind: _remind,
        visibility: _audience,
      );
    } else {
      note = widget.note!;
      s.updateNote(note, (n) {
        n
          ..template = _template
          ..text = text
          ..photo = _photo
          ..planAt = _isPlan ? _at : null
          ..remind = _isPlan && _remind
          ..visibility = _audience;
        if (!_isPlan) n.createdAt = _at;
      });
    }
    await reminders.schedulePlan(note, title);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = context.read<AppState>();
    final reminders = context.read<ReminderService>();
    if (!await confirm(
      context,
      context.t('deleteNoteQ'),
      ok: context.t('delete'),
    )) {
      return;
    }
    await reminders.cancelPlan(widget.note!);
    s.deletePost(widget.note!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final st = noteStyle(_template);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(widget.note == null ? 'newNote' : 'editNote')),
        actions: [
          if (widget.note != null)
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
              child: Text(context.t('save')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in NoteTemplate.values)
                ChoiceChip(
                  avatar: Icon(noteStyle(t).icon, size: 16),
                  label: Text(templateLabel(context, t)),
                  selected: _template == t,
                  selectedColor: noteStyle(t).color,
                  onSelected: (_) => setState(() {
                    final wasPlan = _isPlan;
                    _template = t;
                    if (!_audienceTouched) _audience = _defaultAudience(t);
                    final now = context.read<AppState>().now;
                    if (_isPlan && !wasPlan && !_at.isAfter(now)) {
                      _date = dateOnly(now.add(const Duration(days: 1)));
                      _time = const TimeOfDay(hour: 10, minute: 0);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: st.color,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: TextField(
              key: const Key('noteText'),
              controller: _text,
              maxLength: maxNoteLength,
              maxLines: 6,
              minLines: 3,
              autofocus: widget.note == null,
              style: const TextStyle(color: AppColors.text, fontSize: 17),
              decoration: InputDecoration(
                hintText: templateHint(context, _template),
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterStyle: const TextStyle(color: AppColors.text),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_photo != null) ...[
                MediaThumb(media: _photo!, size: 64),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _photo = null),
                  child: Text(context.t('removePhoto')),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.t('addPhoto')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_isPlan) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(formatDate(context, _date)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          if (_isPlan)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              title: Text(context.t('remind')),
              secondary: const Icon(Icons.notifications_active_outlined),
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
