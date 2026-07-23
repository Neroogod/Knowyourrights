// Data models mirroring the KnowYourRights backend content schema.

class Citation {
  final String sourceName;
  final String locator;
  final String? quote;
  final String? url;

  const Citation({
    required this.sourceName,
    required this.locator,
    this.quote,
    this.url,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        sourceName: json['source_name'] as String,
        locator: json['locator'] as String,
        quote: json['quote'] as String?,
        url: json['url'] as String?,
      );
}

class Topic {
  final String id;
  final String title;
  final String category;
  final String jurisdiction;
  final String summary;
  final String bodyPlain;
  final List<String> rights;
  final List<String> doList;
  final List<String> dontList;
  final List<Citation> citations;
  final String status;
  final String? reviewedBy;
  final String? reviewedAt;

  const Topic({
    required this.id,
    required this.title,
    required this.category,
    required this.jurisdiction,
    required this.summary,
    required this.bodyPlain,
    required this.rights,
    required this.doList,
    required this.dontList,
    required this.citations,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        jurisdiction: json['jurisdiction'] as String,
        summary: json['summary'] as String,
        bodyPlain: json['body_plain'] as String,
        rights: (json['rights'] as List? ?? []).cast<String>(),
        doList: (json['do_list'] as List? ?? []).cast<String>(),
        dontList: (json['dont_list'] as List? ?? []).cast<String>(),
        citations: (json['citations'] as List? ?? [])
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList(),
        status: json['status'] as String? ?? 'draft',
        reviewedBy: json['reviewed_by'] as String?,
        reviewedAt: json['reviewed_at'] as String?,
      );
}

class ScenarioStep {
  final String text;
  final String? action;
  final String? value;

  const ScenarioStep({required this.text, this.action, this.value});

  factory ScenarioStep.fromJson(Map<String, dynamic> json) => ScenarioStep(
        text: json['text'] as String,
        action: json['action'] as String?,
        value: json['value'] as String?,
      );
}

class Scenario {
  final String id;
  final String trigger;
  final String description;
  final String jurisdiction;
  final List<ScenarioStep> steps;
  final List<String> linkedTopicIds;
  final List<Citation> citations;

  const Scenario({
    required this.id,
    required this.trigger,
    required this.description,
    required this.jurisdiction,
    required this.steps,
    required this.linkedTopicIds,
    required this.citations,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
        id: json['id'] as String,
        trigger: json['trigger'] as String,
        description: json['description'] as String,
        jurisdiction: json['jurisdiction'] as String,
        steps: (json['steps'] as List? ?? [])
            .map((s) => ScenarioStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        linkedTopicIds: (json['linked_topic_ids'] as List? ?? []).cast<String>(),
        citations: (json['citations'] as List? ?? [])
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class DirectoryEntry {
  final String id;
  final String name;
  final String entryType;
  final String? state;
  final String? phone;
  final String? url;

  const DirectoryEntry({
    required this.id,
    required this.name,
    required this.entryType,
    this.state,
    this.phone,
    this.url,
  });

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) => DirectoryEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        entryType: json['entry_type'] as String,
        state: json['state'] as String?,
        phone: json['phone'] as String?,
        url: json['url'] as String?,
      );
}

class AskResponse {
  final bool refused;
  final String answer;
  final List<Citation> citations;
  final List<String> relatedTopicIds;
  final String disclaimer;

  const AskResponse({
    required this.refused,
    required this.answer,
    required this.citations,
    required this.relatedTopicIds,
    required this.disclaimer,
  });

  factory AskResponse.fromJson(Map<String, dynamic> json) => AskResponse(
        refused: json['refused'] as bool,
        answer: json['answer'] as String,
        citations: (json['citations'] as List? ?? [])
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList(),
        relatedTopicIds: (json['related_topic_ids'] as List? ?? []).cast<String>(),
        disclaimer: json['disclaimer'] as String,
      );
}
