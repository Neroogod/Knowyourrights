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

  test('custody alert builds an addressed unsent SMS draft', () {
    final uri = buildCustodyAlertUri(phone: '+2348012345678');
    expect(uri.scheme, 'sms');
    expect(uri.queryParameters['body'], custodyAlertMessage);
    expect(uri.path, '+2348012345678');
  });

  group('resolveStepAction', () {
    const directory = [
      DirectoryEntry(
        id: 'nhrc',
        name: 'NHRC',
        entryType: 'ngo',
        url: 'https://nigeriarights.gov.ng/',
      ),
      DirectoryEntry(
        id: 'legal-aid-council',
        name: 'Legal Aid Council',
        entryType: 'legal_aid',
      ),
      DirectoryEntry(
        id: 'police-emergency',
        name: 'Police',
        entryType: 'emergency',
        phone: '112',
      ),
    ];

    test('semantic values keep their meaning', () {
      expect(
        resolveStepAction('call', 'emergency_line', directory)!.phone,
        '112',
      );
      expect(
        resolveStepAction('call', 'emergency_line', directory)!.urgent,
        isTrue,
      );
      expect(
        resolveStepAction('call', 'lawyer', directory)!.opensEmptyDialer,
        isTrue,
      );
    });

    test(
      'a directory id with no phone offers its website instead of a dead dialer',
      () {
        final t = resolveStepAction('call', 'nhrc', directory)!;
        expect(t.url, 'https://nigeriarights.gov.ng/');
        expect(t.phone, isNull);
      },
    );

    test('a directory entry_type resolves too', () {
      final t = resolveStepAction('call', 'legal_aid', directory)!;
      expect(t.label, contains('Legal Aid Council'));
    });

    test('an entry with a phone dials it', () {
      expect(
        resolveStepAction('call', 'police-emergency', directory)!.phone,
        '112',
      );
    });

    test('link actions open the URL', () {
      final t = resolveStepAction('link', 'https://example.org', directory)!;
      expect(t.url, 'https://example.org');
    });

    test('steps with no action get no button', () {
      expect(resolveStepAction(null, null, directory), isNull);
      expect(resolveStepAction('link', null, directory), isNull);
    });

    test(
      'an unknown call value still offers the dialer rather than nothing',
      () {
        expect(
          resolveStepAction('call', 'mystery', directory)!.opensEmptyDialer,
          isTrue,
        );
      },
    );
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
        {'source_name': '1999 Constitution', 'locator': 's.35(2)'},
      ],
      'status': 'verified',
      'reviewed_by': 'Seed',
      'reviewed_at': '2026-07-23',
    });
    expect(t.id, 'rights-when-arrested');
    expect(t.status, 'verified');
    expect(t.citations.single.locator, 's.35(2)');
  });

  test('Obligation and company checklist parse from the content pack', () {
    final obligation = Obligation.fromJson({
      'id': 'annual-returns',
      'title': 'File annual returns',
      'category': 'annual-compliance',
      'summary': 'File the required annual return.',
      'applies_to': ['registered companies'],
      'requirements': ['Prepare the return.'],
      'citations': [
        {'source_name': 'CAMA 2020', 'locator': 'ss.417-423'},
      ],
      'status': 'draft',
    });
    expect(obligation.requirements, hasLength(1));
    expect(obligation.citations.single.locator, 'ss.417-423');

    final checklist = CompanyChecklist.fromJson({
      'id': 'first-year',
      'title': 'First year',
      'description': 'Starter checklist',
      'items': [
        {'text': 'Prepare the return.', 'obligation_id': 'annual-returns'},
      ],
      'citations': [
        {'source_name': 'CAMA 2020', 'locator': 'ss.417-423'},
      ],
    });
    expect(checklist.items.single.obligationId, 'annual-returns');
  });

  test('CaseBrief parses student case digests', () {
    final caseBrief = CaseBrief.fromJson({
      'id': 'agbakoba-passport',
      'name': 'Director SSS v Agbakoba',
      'court': 'Supreme Court of Nigeria',
      'year': 1999,
      'area_of_law': 'freedom-of-movement',
      'summary': 'Passport seizure can violate freedom of movement.',
      'facts': 'Security agents seized a citizen passport.',
      'issues': ['Does passport seizure violate section 41?'],
      'holding': 'Arbitrary passport seizure engages freedom of movement.',
      'ratio': 'Freedom of movement includes travel with a passport.',
      'linked_topic_ids': ['freedom-of-movement'],
      'interpretations': [
        {
          'id': 'note-1',
          'kind': 'significance',
          'body': 'Connect to Constitution s.41.',
          'status': 'verified',
        },
      ],
      'citations': [
        {'source_name': 'Director SSS v Agbakoba', 'locator': 'SC 1999'},
      ],
      'status': 'verified',
    });
    expect(caseBrief.year, 1999);
    expect(caseBrief.interpretations.single.kind, 'significance');
  });

  test('searchCases ranks the matching case first', () {
    final repo = ContentRepository();
    repo.cases = [
      const CaseBrief(
        id: 'fair-hearing',
        name: 'Garba v University of Maiduguri',
        court: 'Supreme Court',
        year: 1986,
        areaOfLaw: 'fair-hearing',
        summary: 'University discipline and natural justice.',
        facts: 'Students challenged disciplinary process.',
        issues: ['Was fair hearing observed?'],
        holding: 'Natural justice binds disciplinary bodies.',
        ratio: 'Fair opportunity to be heard is required.',
        linkedTopicIds: [],
        interpretations: [],
        citations: [],
        status: 'verified',
      ),
      const CaseBrief(
        id: 'movement',
        name: 'Director SSS v Agbakoba',
        court: 'Supreme Court',
        year: 1999,
        areaOfLaw: 'freedom-of-movement',
        summary: 'Passport seizure and freedom of movement.',
        facts: 'Passport seized by security agents.',
        issues: ['Does passport seizure violate movement?'],
        holding: 'Passport seizure can violate section 41.',
        ratio: 'Movement includes ability to travel abroad.',
        linkedTopicIds: [],
        interpretations: [],
        citations: [],
        status: 'verified',
      ),
    ];
    expect(repo.searchCases('passport freedom movement').first.id, 'movement');
  });

  test('AskResponse.fromJson parses refusal and citations', () {
    final r = AskResponse.fromJson({
      'refused': false,
      'answer': 'answer',
      'citations': [
        {'source_name': '1999 Constitution', 'locator': 's.37'},
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
