import 'package:flutter/material.dart';

import '/shared_pages/events/event_create_widget.dart';

class EventEditWidget extends StatelessWidget {
  const EventEditWidget({
    super.key,
    required this.eventId,
  });

  // Kept on the edit route wrapper for the upcoming prefill/save flow.
  final String eventId;

  static String routeName = 'eventEdit';
  static String routePath = '/events/:eventId/edit';

  @override
  Widget build(BuildContext context) {
    return const EventCreateWidget(
      formMode: EventFormMode.edit,
    );
  }
}
