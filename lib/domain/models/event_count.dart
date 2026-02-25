/// Per-file event count summary for the QC section.
class EventCount {
  final String filename;
  final int rawEvents;
  final int postFilterEvents;

  const EventCount({
    required this.filename,
    required this.rawEvents,
    required this.postFilterEvents,
  });
}
