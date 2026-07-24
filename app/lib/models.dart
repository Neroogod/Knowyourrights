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
  final List<String> commonSituations;
  final List<String> wordsToUse;
  final List<String> ifViolated;
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
    this.commonSituations = const [],
    this.wordsToUse = const [],
    this.ifViolated = const [],
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
    commonSituations: (json['common_situations'] as List? ?? []).cast<String>(),
    wordsToUse: (json['words_to_use'] as List? ?? []).cast<String>(),
    ifViolated: (json['if_violated'] as List? ?? []).cast<String>(),
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

class Obligation {
  final String id;
  final String title;
  final String category;
  final String summary;
  final List<String> appliesTo;
  final String? frequency;
  final String? deadlineRule;
  final String? consequence;
  final List<String> requirements;
  final List<Citation> citations;
  final String status;

  const Obligation({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.appliesTo,
    required this.requirements,
    required this.citations,
    required this.status,
    this.frequency,
    this.deadlineRule,
    this.consequence,
  });

  factory Obligation.fromJson(Map<String, dynamic> json) => Obligation(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    summary: json['summary'] as String,
    appliesTo: (json['applies_to'] as List? ?? []).cast<String>(),
    frequency: json['frequency'] as String?,
    deadlineRule: json['deadline_rule'] as String?,
    consequence: json['consequence'] as String?,
    requirements: (json['requirements'] as List? ?? []).cast<String>(),
    citations: (json['citations'] as List? ?? [])
        .map((c) => Citation.fromJson(c as Map<String, dynamic>))
        .toList(),
    status: json['status'] as String? ?? 'draft',
  );
}

class ChecklistItem {
  final String text;
  final String? obligationId;

  const ChecklistItem({required this.text, this.obligationId});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    text: json['text'] as String,
    obligationId: json['obligation_id'] as String?,
  );
}

class CompanyChecklist {
  final String id;
  final String title;
  final String description;
  final List<ChecklistItem> items;
  final List<Citation> citations;
  final String status;

  const CompanyChecklist({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
    required this.citations,
    required this.status,
  });

  factory CompanyChecklist.fromJson(Map<String, dynamic> json) =>
      CompanyChecklist(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        items: (json['items'] as List? ?? [])
            .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        citations: (json['citations'] as List? ?? [])
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList(),
        status: json['status'] as String? ?? 'draft',
      );
}

class CaseInterpretation {
  final String id;
  final String kind;
  final String body;
  final String status;
  final String? reviewedBy;

  const CaseInterpretation({
    required this.id,
    required this.kind,
    required this.body,
    required this.status,
    this.reviewedBy,
  });

  factory CaseInterpretation.fromJson(Map<String, dynamic> json) =>
      CaseInterpretation(
        id: json['id'] as String,
        kind: json['kind'] as String,
        body: json['body'] as String,
        status: json['status'] as String? ?? 'draft',
        reviewedBy: json['reviewed_by'] as String?,
      );
}

/// How one case relates to another in the citator graph.
///
/// Saying that a case overrules or distinguishes another is a legal claim, so a
/// relation carries a review status like any other content and is shown as
/// pending until a lawyer verifies it.
class CaseRelation {
  final String relation;
  final String caseId;
  final String name;
  final String court;
  final int year;
  final String? note;
  final String status;

  const CaseRelation({
    required this.relation,
    required this.caseId,
    required this.name,
    required this.court,
    required this.year,
    required this.status,
    this.note,
  });

  factory CaseRelation.fromJson(Map<String, dynamic> json) => CaseRelation(
    relation: json['relation'] as String,
    caseId: json['case_id'] as String,
    name: json['name'] as String? ?? json['case_id'] as String,
    court: json['court'] as String? ?? '',
    year: json['year'] as int? ?? 0,
    note: json['note'] as String?,
    status: json['status'] as String? ?? 'draft',
  );

  bool get isVerified => status == 'verified';
}

/// A named list of cases a student is working through.
class ReadingList {
  final String id;
  final String name;
  final List<String> caseIds;

  const ReadingList({required this.id, required this.name, required this.caseIds});

  factory ReadingList.fromSyncItem(Map<String, dynamic> item) {
    final payload = (item['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    return ReadingList(
      id: item['item_id'] as String,
      name: payload['name'] as String? ?? 'Untitled list',
      caseIds: ((payload['case_ids'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// The filter values actually present in the case library.
class CaseFilters {
  final List<String> areasOfLaw;
  final List<String> courts;
  final List<int> years;

  const CaseFilters({this.areasOfLaw = const [], this.courts = const [], this.years = const []});

  factory CaseFilters.fromJson(Map<String, dynamic> json) => CaseFilters(
    areasOfLaw: ((json['areas_of_law'] as List?) ?? const []).cast<String>(),
    courts: ((json['courts'] as List?) ?? const []).cast<String>(),
    years: ((json['years'] as List?) ?? const []).cast<int>(),
  );
}

class CaseBrief {
  final String id;
  final String name;
  final String court;
  final int year;
  final String areaOfLaw;
  final String summary;
  final String facts;
  final List<String> issues;
  final String holding;
  final String ratio;
  final String? reportCitation;
  final String? sourceUrl;
  final List<String> linkedTopicIds;
  final List<CaseInterpretation> interpretations;
  final List<Citation> citations;
  final String status;
  final String? reviewedBy;

  const CaseBrief({
    required this.id,
    required this.name,
    required this.court,
    required this.year,
    required this.areaOfLaw,
    required this.summary,
    required this.facts,
    required this.issues,
    required this.holding,
    required this.ratio,
    required this.linkedTopicIds,
    required this.interpretations,
    required this.citations,
    required this.status,
    this.reportCitation,
    this.sourceUrl,
    this.reviewedBy,
  });

  factory CaseBrief.fromJson(Map<String, dynamic> json) => CaseBrief(
    id: json['id'] as String,
    name: json['name'] as String,
    court: json['court'] as String,
    year: json['year'] as int,
    areaOfLaw: json['area_of_law'] as String,
    summary: json['summary'] as String,
    facts: json['facts'] as String,
    issues: (json['issues'] as List? ?? []).cast<String>(),
    holding: json['holding'] as String,
    ratio: json['ratio'] as String,
    reportCitation: json['report_citation'] as String?,
    sourceUrl: json['source_url'] as String?,
    linkedTopicIds: (json['linked_topic_ids'] as List? ?? []).cast<String>(),
    interpretations: (json['interpretations'] as List? ?? [])
        .map(
          (item) => CaseInterpretation.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    citations: (json['citations'] as List? ?? [])
        .map((c) => Citation.fromJson(c as Map<String, dynamic>))
        .toList(),
    status: json['status'] as String? ?? 'draft',
    reviewedBy: json['reviewed_by'] as String?,
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
