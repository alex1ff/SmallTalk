import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_inter_model.dart';
export 'add_inter_model.dart';

enum _IntervalField {
  start,
  end,
}

class AddInterWidget extends StatefulWidget {
  const AddInterWidget({
    super.key,
    this.act,
  });

  final Future Function()? act;

  @override
  State<AddInterWidget> createState() => _AddInterWidgetState();
}

class _AddInterWidgetState extends State<AddInterWidget> {
  static const int _minuteStep = 5;
  static const int _defaultDurationMinutes = 60;
  static const int _durationAdjustmentStepMinutes = 15;
  static const int _lastMinuteOfDay = (24 * 60) - _minuteStep;
  static const int _latestStartMinute = _lastMinuteOfDay - _minuteStep;

  late AddInterModel _model;
  _IntervalField _activeField = _IntervalField.start;

  Map<String, dynamic> _buildTimezoneMetadataUpdate() {
    final now = DateTime.now();
    return {
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timezoneName': now.timeZoneName,
      'timezoneUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddInterModel());

    final initialStart = _buildInitialStartTime();
    final initialEnd = _buildInitialEndTime(initialStart);
    _setInterval(start: initialStart, end: initialEnd);
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  DateTime get _startOfToday => DateUtils.dateOnly(DateTime.now());

  DateTime _buildInitialStartTime() {
    final now = DateTime.now();
    final roundedMinutes = _roundUpToStep(now.hour * 60 + now.minute);
    return _minutesToDateTime(
      _clampMinutes(
        roundedMinutes,
        min: 0,
        max: _latestStartMinute,
      ),
    );
  }

  DateTime _buildInitialEndTime(DateTime start) {
    final startMinutes = _minutesOfDay(start);
    return _minutesToDateTime(
      _clampMinutes(
        startMinutes + _defaultDurationMinutes,
        min: startMinutes + _minuteStep,
        max: _lastMinuteOfDay,
      ),
    );
  }

  int _minutesOfDay(DateTime value) => value.hour * 60 + value.minute;

  DateTime _minutesToDateTime(int minutes) =>
      _startOfToday.add(Duration(minutes: minutes));

  int _roundUpToStep(int minutes) {
    final remainder = minutes % _minuteStep;
    if (remainder == 0) {
      return minutes;
    }
    return minutes + (_minuteStep - remainder);
  }

  int _clampMinutes(
    int value, {
    required int min,
    required int max,
  }) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  DateTime _parseTime(
    String? rawValue, {
    required DateTime fallback,
  }) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(rawValue ?? '');
    if (match == null) {
      return fallback;
    }

    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        hours > 23 ||
        minutes < 0 ||
        minutes > 59) {
      return fallback;
    }

    return _minutesToDateTime(hours * 60 + minutes);
  }

  String _formatTime(DateTime value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  void _setInterval({
    required DateTime start,
    required DateTime end,
  }) {
    _model.timeStart = _formatTime(start);
    _model.timeEnd = _formatTime(end);
  }

  DateTime get _selectedStartTime => _parseTime(
        _model.timeStart,
        fallback: _buildInitialStartTime(),
      );

  DateTime get _selectedEndTime => _parseTime(
        _model.timeEnd,
        fallback: _buildInitialEndTime(_selectedStartTime),
      );

  int get _selectedStartMinutes => _minutesOfDay(_selectedStartTime);

  int get _selectedEndMinutes => _minutesOfDay(_selectedEndTime);

  int get _durationMinutes => _selectedEndMinutes - _selectedStartMinutes;

  int get _maxAvailableDurationMinutes =>
      _lastMinuteOfDay - _selectedStartMinutes;

  List<int> _availableSlotsFor(_IntervalField field) {
    if (field == _IntervalField.start) {
      return [
        for (int minutes = 0;
            minutes <= _latestStartMinute;
            minutes += _minuteStep)
          minutes,
      ];
    }

    final firstEnd = _selectedStartMinutes + _minuteStep;
    return [
      for (int minutes = firstEnd;
          minutes <= _lastMinuteOfDay;
          minutes += _minuteStep)
        minutes,
    ];
  }

  int _selectedMinutesFor(_IntervalField field) {
    return field == _IntervalField.start
        ? _selectedStartMinutes
        : _selectedEndMinutes;
  }

  void _updateActiveField(_IntervalField field) {
    if (_activeField == field) {
      return;
    }
    setState(() {
      _activeField = field;
    });
  }

  void _updateSelectedMinutes(int newMinutes) {
    final startMinutes = _selectedStartMinutes;
    final endMinutes = _selectedEndMinutes;

    if (_activeField == _IntervalField.start) {
      final preservedDuration = endMinutes - startMinutes;
      final nextEndMinutes = _clampMinutes(
        newMinutes + preservedDuration,
        min: newMinutes + _minuteStep,
        max: _lastMinuteOfDay,
      );
      setState(() {
        _setInterval(
          start: _minutesToDateTime(newMinutes),
          end: _minutesToDateTime(nextEndMinutes),
        );
      });
      return;
    }

    final minEnd = startMinutes + _minuteStep;
    final validEndMinutes = _clampMinutes(
      newMinutes,
      min: minEnd,
      max: _lastMinuteOfDay,
    );
    setState(() {
      _setInterval(
        start: _minutesToDateTime(startMinutes),
        end: _minutesToDateTime(validEndMinutes),
      );
    });
  }

  void _updateDuration(int nextDurationMinutes) {
    final validDuration = _clampMinutes(
      nextDurationMinutes,
      min: _minuteStep,
      max: _maxAvailableDurationMinutes,
    );
    final startMinutes = _selectedStartMinutes;

    setState(() {
      _setInterval(
        start: _minutesToDateTime(startMinutes),
        end: _minutesToDateTime(startMinutes + validDuration),
      );
    });
  }

  void _changeDurationBy(int deltaMinutes) {
    _updateDuration(_durationMinutes + deltaMinutes);
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours ч $minutes мин';
    }
    if (hours > 0) {
      return '$hours ч';
    }
    return '$minutes мин';
  }

  Widget _buildDurationAdjustButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 42.0,
        height: 42.0,
        decoration: BoxDecoration(
          color: isEnabled
              ? FlutterFlowTheme.of(context).primaryBackground
              : const Color(0xFFF5F5F8),
          borderRadius: BorderRadius.circular(18.0),
          border: Border.all(
            color:
                isEnabled ? const Color(0xFFE6E6EB) : const Color(0xFFEDEEF2),
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled
              ? FlutterFlowTheme.of(context).primaryText
              : FlutterFlowTheme.of(context).secondaryText,
          size: 18.0,
        ),
      ),
    );
  }

  Future<void> _saveInterval() async {
    if (_selectedEndMinutes <= _selectedStartMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите корректный интервал времени'),
        ),
      );
      return;
    }

    final availabilityUpdate = createUsersRecordData(
      availabilityToday: createAvailabilityTodayStruct(
        enabled: true,
        fieldValues: {
          'intervals': FieldValue.arrayUnion([
            getIntervalsFirestoreData(
              updateIntervalsStruct(
                IntervalsStruct(
                  start: _model.timeStart,
                  end: _model.timeEnd,
                ),
                clearUnsetFields: false,
              ),
              true,
            )
          ]),
        },
        clearUnsetFields: false,
      ),
    );
    availabilityUpdate.addAll(_buildTimezoneMetadataUpdate());
    await currentUserReference!.update(availabilityUpdate);
    await widget.act?.call();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildSelectionCard({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF7EEF6)
                : FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: isSelected
                  ? FlutterFlowTheme.of(context).primaryText
                  : const Color(0xFFE6E6EB),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 13.0,
                      letterSpacing: 0.0,
                    ),
              ),
              const SizedBox(height: 6.0),
              Text(
                value,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      fontSize: 24.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final previewText = '${_model.timeStart} - ${_model.timeEnd}';
    final pickerOptions = _availableSlotsFor(_activeField);
    final canDecreaseDuration = _durationMinutes > _minuteStep;
    final canIncreaseDuration = _durationMinutes < _maxAvailableDurationMinutes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 16.0,
          child: custom_widgets.NotchedClipper(
            width: double.infinity,
            height: 16.0,
          ),
        ),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional(0.0, -1.0),
                child: Text(
                  FFLocalizations.of(context).getText(
                    'doo4eaqe' /* Добавить интервал */,
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Cool',
                        fontSize: 22.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 24.0, 6.0, 0.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(26.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 52.0,
                        height: 52.0,
                        decoration: BoxDecoration(
                          color: Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(22.0),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Icon(
                            FFIcons.kclockPlus,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20.0,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              12.0, 0.0, 0.0, 0.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                previewText,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      fontSize: 18.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                'Длительность ${_formatDuration(_durationMinutes)}',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 13.0,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 32.0, 0.0, 0.0),
                child: Text(
                  'Выберите интервал',
                  textAlign: TextAlign.start,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Cool',
                        fontSize: 20.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 12.0, 6.0, 0.0),
                child: Row(
                  children: [
                    _buildSelectionCard(
                      label: 'Начало',
                      value: _model.timeStart ?? '--:--',
                      isSelected: _activeField == _IntervalField.start,
                      onTap: () => _updateActiveField(_IntervalField.start),
                    ),
                    const SizedBox(width: 10.0),
                    _buildSelectionCard(
                      label: 'Конец',
                      value: _model.timeEnd ?? '--:--',
                      isSelected: _activeField == _IntervalField.end,
                      onTap: () => _updateActiveField(_IntervalField.end),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 18.0, 16.0, 0.0),
                child: Row(
                  children: [
                    Text(
                      'Длительность',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            fontSize: 16.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    _buildDurationAdjustButton(
                      icon: Icons.remove_rounded,
                      onTap: canDecreaseDuration
                          ? () => _changeDurationBy(
                                -_durationAdjustmentStepMinutes,
                              )
                          : null,
                    ),
                    const SizedBox(width: 10.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(18.0),
                        border: Border.all(
                          color: const Color(0xFFE6E6EB),
                        ),
                      ),
                      child: Text(
                        _formatDuration(_durationMinutes),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              fontSize: 15.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    _buildDurationAdjustButton(
                      icon: Icons.add_rounded,
                      onTap: canIncreaseDuration
                          ? () => _changeDurationBy(
                                _durationAdjustmentStepMinutes,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 18.0, 16.0, 0.0),
                child: Text(
                  _activeField == _IntervalField.start
                      ? 'Сдвиг начала сохраняет текущую длительность. Ниже её можно быстро менять.'
                      : 'Конец можно выбрать вручную или скорректировать длительность кнопками выше.',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: FlutterFlowTheme.of(context).secondaryText,
                        fontSize: 13.0,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 18.0, 6.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 220.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(26.0),
                  ),
                  child: Stack(
                    alignment: AlignmentDirectional(0.0, 0.0),
                    children: [
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                        child: Container(
                          width: double.infinity,
                          height: 52.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            18.0, 16.0, 18.0, 0.0),
                        child: Align(
                          alignment: AlignmentDirectional(-1.0, -1.0),
                          child: Text(
                            _activeField == _IntervalField.start
                                ? 'Выбираем время начала'
                                : 'Выбираем время окончания',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 13.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        top: 22.0,
                        child: _TimeSlotsPicker(
                          options: pickerOptions,
                          selectedMinutes: _selectedMinutesFor(_activeField),
                          onSelected: _updateSelectedMinutes,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: EdgeInsetsDirectional.fromSTEB(
                    0.0, 40.0, 6.0, keyboardVisible ? 6.0 : 35.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: wrapWithModel(
                        model: _model.buttonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: ButtonWidget(
                          text: FFLocalizations.of(context).getText(
                            'bzho8r5y' /* Добавить интервал */,
                          ),
                          keyboardAwarePadding: false,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 6.0, 0.0),
                          loadingText:
                              FFLocalizations.of(context).getVariableText(
                            ruText: 'Сохраняем...',
                            enText: 'Saving...',
                          ),
                          busyStyle: ButtonBusyStyle.spinner,
                          action: _saveInterval,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 7.0,
                            color: Color(0x0D2C2C2C),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        shape: BoxShape.circle,
                      ),
                      child: FlutterFlowIconButton(
                        borderRadius: 50.0,
                        buttonSize: 60.0,
                        fillColor:
                            FlutterFlowTheme.of(context).primaryBackground,
                        icon: Icon(
                          Icons.close_sharp,
                          color: FlutterFlowTheme.of(context).error,
                          size: 20.0,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ].addToStart(SizedBox(height: 16.0)),
          ),
        ),
      ],
    );
  }
}

class _TimeSlotsPicker extends StatefulWidget {
  const _TimeSlotsPicker({
    required this.options,
    required this.selectedMinutes,
    required this.onSelected,
  });

  final List<int> options;
  final int selectedMinutes;
  final ValueChanged<int> onSelected;

  @override
  State<_TimeSlotsPicker> createState() => _TimeSlotsPickerState();
}

class _TimeSlotsPickerState extends State<_TimeSlotsPicker> {
  late final FixedExtentScrollController _controller;

  int get _selectedIndex {
    final index = widget.options.indexOf(widget.selectedMinutes);
    return index >= 0 ? index : 0;
  }

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant _TimeSlotsPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      if (_controller.selectedItem != _selectedIndex) {
        _controller.jumpToItem(_selectedIndex);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatMinutes(int totalMinutes) {
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker.builder(
      scrollController: _controller,
      itemExtent: 48.0,
      useMagnifier: true,
      magnification: 1.08,
      diameterRatio: 1.25,
      squeeze: 1.1,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: (index) {
        HapticFeedback.selectionClick();
        widget.onSelected(widget.options[index]);
      },
      childCount: widget.options.length,
      itemBuilder: (context, index) {
        return Center(
          child: Text(
            _formatMinutes(widget.options[index]),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  fontSize: 26.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
        );
      },
    );
  }
}
