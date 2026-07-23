import 'package:flutter_test/flutter_test.dart';
import 'package:knowyourrights_app/actions.dart';
import 'package:knowyourrights_app/api_client.dart';
import 'package:knowyourrights_app/models.dart';

void main() {
  test('callTargetFor maps the emergency line to a concrete number', () {
    final t = callTargetFor('emergency_line');
    expect(t.number, '112');
    expect(t.label.contains('112'), isTrue);
  });

  test('callTargetFor leaves lawyer/trusted contact for the user to dial', () {
    expect(callTargetFor('lawyer').number, isNull);
    expect(callTargetFor('trusted_contact').number, isNull);
    expect(callTargetFor(null).number, isNull);
  });

  test('Topic.fromJson parses fields and citations', () {
    final t = Topic.fromJson({
      'id': 'rights-when-arrested',
      'title': 'Your rights when you are arrested',
      'category': 'arrest-and-police',
      'jurisdiction': 'NG-Federal',
      'summary': 'Stay silent until you speak to a lawyer.',
      'body_plain': 'body',
      'rights': ['You may remain silent (s.35(2)).'],
      'do_list': ['Ask why.'],
      'dont_list': ['Do not resist.'],
      'citations': [
        {'source_name': '1999 Constitution', 'locator': 's.35(2)'}
      ],
      'status': 'verified',
      'reviewed_by': 'Seed',
      'reviewed_at': '2026-07-23',
    });
    expect(t.id, 'rights-when-arrested');
    expect(t.status, 'verified');
    expect(t.citations.single.locator, 's.35(2)');
  });

  test('AskResponse.fromJson parses refusal and citations', () {
    final r = AskResponse.fromJson({
      'refused': false,
      'answer': 'answer',
      'citations': [
        {'source_name': '1999 Constitution', 'locator': 's.37'}
      ],
      'related_topic_ids': ['a'],
      'disclaimer': 'info not advice',
    });
    expect(r.refused, false);
    expect(r.citations.single.locator, 's.37');
    expect(r.relatedTopicIds, ['a']);
  });

  test('searchTopics ranks the most relevant topic first', () {
    final repo = ContentRepository();
    repo.topics = [
      const Topic(
        id: 'arrest',
        title: 'Your rights when you are arrested',
        category: 'c',
        jurisdiction: 'NG',
        summary: 'remain silent lawyer',
        bodyPlain: 'arrested police remain silent lawyer',
        rights: [],
        doList: [],
        dontList: [],
        citations: [],
        status: 'verified',
      ),
      const Topic(
        id: 'phone',
        title: 'Can the police search your phone?',
        category: 'c',
        jurisdiction: 'NG',
        summary: 'phone privacy protected',
        bodyPlain: 'police search phone privacy telephone protected',
        rights: [],
        doList: [],
        dontList: [],
        citations: [],
        status: 'verified',
      ),
    ];
    final results = repo.searchTopics('search my phone');
    expect(results.first.id, 'phone');
  });

  test('searchTopics returns nothing for an off-topic query', () {
    final repo = ContentRepository();
    repo.topics = [
      const Topic(
        id: 'phone',
        title: 'Can the police search your phone?',
        category: 'c',
        jurisdiction: 'NG',
        summary: 'phone privacy protected',
        bodyPlain: 'police search phone privacy telephone protected',
        rights: [],
        doList: [],
        dontList: [],
        citations: [],
        status: 'verified',
      ),
    ];
    expect(repo.searchTopics('bitcoin price lottery'), isEmpty);
  });
}
