import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'add_inter_model.dart';
export 'add_inter_model.dart';

enum _IntervalField {
  start,
  end,
}

class AddInterWidget extends StatefulWidget {
  const AddInterWidget({
    super.key,
  });

  @override
  State<AddInterWidget> createState() => _AddInterWidgetState();
}

class _AddInterWidgetState extends State<AddInterWidget> {
  static const int _minuteStep = 5;
  static const int _defaultDurationMinutes = 60;
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

  void _updateActiveField(_IntervalField field) {
    if (_activeField == field) {
      return;
    }
    setState(() {
      _activeField = field;
    });
  }

  void _updateSelectedTime(DateTime value) {
    final newMinutes = _roundUpToStep(_minutesOfDay(value));
    final startMinutes = _selectedStartMinutes;
    final endMinutes = _selectedEndMinutes;

    if (_activeField == _IntervalField.start) {
      final preservedDuration = endMinutes - startMinutes;
      final validStartMinutes = _clampMinutes(
        newMinutes,
        min: 0,
        max: _latestStartMinute,
      );
      final nextEndMinutes = _clampMinutes(
        validStartMinutes + preservedDuration,
        min: validStartMinutes + _minuteStep,
        max: _lastMinuteOfDay,
      );
      setState(() {
        _setInterval(
          start: _minutesToDateTime(validStartMinutes),
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
    if (mounted) {
      Navigator.pop(context, true);
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
    final previewText = '${_model.timeStart} - ${_model.timeEnd}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.background,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BottomSheetHeader(
                title: FFLocalizations.of(context).getText(
                  'doo4eaqe' /* Добавить интервал */,
                ),
                onClose: () => Navigator.pop(context, false),
                onConfirm: _saveInterval,
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.card,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 52.0,
                        height: 52.0,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.mutedSurface,
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
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 18.0, 6.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 188.0,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.card,
                    borderRadius: BorderRadius.circular(16.0),
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
                        top: 8.0,
                        child: CupertinoDatePicker(
                          key: ValueKey(_activeField),
                          mode: CupertinoDatePickerMode.time,
                          use24hFormat: true,
                          minuteInterval: _minuteStep,
                          initialDateTime: _activeField == _IntervalField.start
                              ? _selectedStartTime
                              : _selectedEndTime,
                          onDateTimeChanged: _updateSelectedTime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 35.0),
            ],
          ),
        ),
      ],
    );
  }
}
