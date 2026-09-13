String normalizeWordContentValue(String? value) {
  var normalized = (value ?? '').trim().replaceAll(
        RegExp(r'\s+', unicode: true),
        ' ',
      );
  if (normalized.isEmpty) {
    return '';
  }

  const edgePunctuation = r'''[\s.,!?;:…'"“”‘’«»()\[\]{}<>/\\|_\-]''';
  normalized = normalized
      .replaceFirst(RegExp('^$edgePunctuation+', unicode: true), '')
      .replaceFirst(RegExp('$edgePunctuation+\$', unicode: true), '');
  return normalized.toLowerCase();
}

String normalizedWordLanguageCode(String? value) {
  return (value ?? '').trim().toLowerCase().replaceAll('_', '-');
}
