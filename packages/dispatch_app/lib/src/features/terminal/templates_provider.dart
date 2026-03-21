import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/template.dart';

class TemplatesNotifier extends Notifier<List<Template>> {
  @override
  List<Template> build() => [];

  void addTemplate(Template template) {
    state = [...state, template];
  }

  void removeTemplate(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }
}

final templatesProvider =
    NotifierProvider<TemplatesNotifier, List<Template>>(TemplatesNotifier.new);
