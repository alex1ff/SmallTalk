import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/services/availability_interval_time.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'add_inter_model.dart';
export 'add_inter_model.dart';

class AddInterWidget extends StatefulWidget {
  const AddInterWidget({
    super.key,
  });

  @override
  State<AddInterWidget> createState() => _AddInterWidgetState();
}

class _AddInterWidgetState extends State<AddInterWidget> {
  late AddInterModel _model;
  AvailabilityIntervalField _activeField = AvailabilityIntervalField.start;

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

  DateTime get _startOfToday => availabilityIntervalDay(DateTime.now());

  DateTime _buildInitialStartTime() {
    return buildInitialAvailabilityIntervalStartTime(DateTime.now());
  }

  DateTime _buildInitialEndTime(DateTime start) {
    return buildInitialAvailabilityIntervalEndTime(start);
  }

  int _minutesOfDay(DateTime value) => availabilityIntervalMinutesOfDay(value);

  DateTime _minutesToDateTime(int minutes) =>
      availabilityIntervalDateTimeFromMinutes(
        day: _startOfToday,
        minutes: minutes,
      );

  DateTime _parseTime(
    String? rawValue, {
    required DateTime fallback,
  }) {
    return parseAvailabilityIntervalTime(rawValue, fallback: fallback);
  }

  String _formatTime(DateTime value) => formatAvailabilityIntervalTime(value);

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

  DateTime get _pickerMinimumTime {
    if (_activeField == AvailabilityIntervalField.end) {
      return _minutesToDateTime(
        _selectedStartMinutes + kAvailabilityIntervalMinuteStep,
      );
    }
    return _minutesToDateTime(0);
  }

  DateTime get _pickerMaximumTime {
    if (_activeField == AvailabilityIntervalField.start) {
      return _minutesToDateTime(
        _selectedEndMinutes - kAvailabilityIntervalMinuteStep,
      );
    }
    return _minutesToDateTime(kAvailabilityIntervalLastMinuteOfDay);
  }

  void _updateActiveField(AvailabilityIntervalField field) {
    if (_activeField == field) {
      return;
    }
    setState(() {
      _activeField = field;
    });
  }

  void _updateSelectedTime(DateTime value) {
    final draft = updateAvailabilityIntervalDraft(
      field: _activeField,
      selectedMinutes: _minutesOfDay(value),
      currentStartMinutes: _selectedStartMinutes,
      currentEndMinutes: _selectedEndMinutes,
    );
    setState(() {
      _setInterval(
        start: _minutesToDateTime(draft.startMinutes),
        end: _minutesToDateTime(draft.endMinutes),
      );
    });
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
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 52.0,
                        height: 52.0,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.mutedSurface,
                          borderRadius: BorderRadius.circular(16.0),
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
                      isSelected:
                          _activeField == AvailabilityIntervalField.start,
                      onTap: () => _updateActiveField(
                        AvailabilityIntervalField.start,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    _buildSelectionCard(
                      label: 'Конец',
                      value: _model.timeEnd ?? '--:--',
                      isSelected: _activeField == AvailabilityIntervalField.end,
                      onTap: () => _updateActiveField(
                        AvailabilityIntervalField.end,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 18.0, 6.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 148.0,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.card,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            18.0, 14.0, 18.0, 0.0),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _activeField == AvailabilityIntervalField.start
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
                      SizedBox(
                        height: 112.0,
                        child: CupertinoDatePicker(
                          key: ValueKey(_activeField),
                          mode: CupertinoDatePickerMode.time,
                          use24hFormat: true,
                          minuteInterval: kAvailabilityIntervalMinuteStep,
                          itemExtent: 34.0,
                          minimumDate: _pickerMinimumTime,
                          maximumDate: _pickerMaximumTime,
                          initialDateTime:
                              _activeField == AvailabilityIntervalField.start
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
