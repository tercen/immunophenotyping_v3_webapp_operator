/// Complete set of analysis settings for a single run.
class RunSettings {
  /// User-defined run name.
  final String runName;

  /// FCS zip filename.
  final String fcsFilename;

  /// Number of FCS files.
  final int fcsFileCount;

  /// Number of channels in the FCS data.
  final int totalChannels;

  /// Annotation CSV filename.
  final String annotationFilename;

  /// Number of samples in annotation.
  final int sampleCount;

  /// Conditions from annotation.
  final List<String> conditions;

  /// Number of selected analysis channels.
  final int selectedChannelCount;

  /// Max events per file for downsampling.
  final int maxEventsPerFile;

  /// PhenoGraph k parameter.
  final int phenographK;

  /// UMAP n_neighbors parameter.
  final int umapNNeighbors;

  /// UMAP min_dist parameter.
  final double umapMinDist;

  /// Random seed for reproducibility.
  final int randomSeed;

  const RunSettings({
    required this.runName,
    required this.fcsFilename,
    required this.fcsFileCount,
    required this.totalChannels,
    required this.annotationFilename,
    required this.sampleCount,
    required this.conditions,
    required this.selectedChannelCount,
    required this.maxEventsPerFile,
    required this.phenographK,
    required this.umapNNeighbors,
    required this.umapMinDist,
    required this.randomSeed,
  });

  Map<String, dynamic> toMap() => {
        'runName': runName,
        'fcsFilename': fcsFilename,
        'fcsFileCount': fcsFileCount,
        'totalChannels': totalChannels,
        'annotationFilename': annotationFilename,
        'sampleCount': sampleCount,
        'conditions': conditions,
        'selectedChannelCount': selectedChannelCount,
        'maxEventsPerFile': maxEventsPerFile,
        'phenographK': phenographK,
        'umapNNeighbors': umapNNeighbors,
        'umapMinDist': umapMinDist,
        'randomSeed': randomSeed,
      };

  factory RunSettings.fromMap(Map<String, dynamic> map) => RunSettings(
        runName: map['runName'] as String? ?? '',
        fcsFilename: map['fcsFilename'] as String? ?? '',
        fcsFileCount: map['fcsFileCount'] as int? ?? 0,
        totalChannels: map['totalChannels'] as int? ?? 0,
        annotationFilename: map['annotationFilename'] as String? ?? '',
        sampleCount: map['sampleCount'] as int? ?? 0,
        conditions: (map['conditions'] as List?)?.cast<String>() ?? [],
        selectedChannelCount: map['selectedChannelCount'] as int? ?? 0,
        maxEventsPerFile: map['maxEventsPerFile'] as int? ?? 0,
        phenographK: map['phenographK'] as int? ?? 30,
        umapNNeighbors: map['umapNNeighbors'] as int? ?? 15,
        umapMinDist: (map['umapMinDist'] as num?)?.toDouble() ?? 0.5,
        randomSeed: map['randomSeed'] as int? ?? 42,
      );
}
