class Problem {
  final String title;
  final String statement;
  final String contestName; // Added contestName
  final String constraints;
  final String inputFormat;
  final String outputFormat;
  final List<SampleIO> samples;
  final String url;

  Problem({
    required this.title,
    required this.statement,
    required this.contestName, // Added contestName
    required this.constraints,
    required this.inputFormat,
    required this.outputFormat,
    required this.samples,
    required this.url,
  });
}

class SampleIO {
  final String input;
  final String output;
  final int index;

  SampleIO({
    required this.input,
    required this.output,
    required this.index,
  });
}