import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/features/admin/selection_status.dart';
import 'package:modelapp/features/castings/casting_response_status.dart';
import 'package:modelapp/features/profile/profile_model.dart';

void main() {
  group('selection statuses', () {
    test('parses canonical and legacy aliases', () {
      expect(selectionStatusFromString('draft'), SelectionStatus.draft);
      expect(selectionStatusFromString('sent'), SelectionStatus.sentToClient);
      expect(
        selectionStatusFromString('client_viewed'),
        SelectionStatus.clientViewed,
      );
      expect(selectionStatusFromString('chosen'), SelectionStatus.selected);
      expect(selectionStatusFromString('declined'), SelectionStatus.rejected);
      expect(selectionStatusFromString('unknown'), SelectionStatus.draft);
    });

    test('storage values stay stable', () {
      expect(SelectionStatus.draft.storageValue, 'draft');
      expect(SelectionStatus.sentToClient.storageValue, 'sent_to_client');
      expect(SelectionStatus.clientViewed.storageValue, 'client_viewed');
      expect(SelectionStatus.selected.storageValue, 'selected');
      expect(SelectionStatus.rejected.storageValue, 'rejected');
    });
  });

  group('casting response statuses', () {
    test('parses and serializes response statuses', () {
      expect(
        castingResponseStatusFromString(' viewed '),
        CastingResponseStatus.viewed,
      );
      expect(
        castingResponseStatusFromString('invited'),
        CastingResponseStatus.invited,
      );
      expect(
        castingResponseStatusFromString('rejected'),
        CastingResponseStatus.rejected,
      );
      expect(
        castingResponseStatusFromString('unknown'),
        CastingResponseStatus.submitted,
      );
      expect(
        castingResponseStatusToString(CastingResponseStatus.invited),
        'invited',
      );
    });

    test('merges statuses by strongest pipeline state', () {
      expect(
        mergeCastingResponseStatuses([
          CastingResponseStatus.submitted,
          CastingResponseStatus.viewed,
        ]),
        CastingResponseStatus.viewed,
      );
      expect(
        mergeCastingResponseStatuses([
          CastingResponseStatus.rejected,
          CastingResponseStatus.invited,
        ]),
        CastingResponseStatus.invited,
      );
      expect(
        mergeCastingResponseStatuses(const []),
        CastingResponseStatus.rejected,
      );
    });
  });

  group('profile moderation and verification statuses', () {
    test('parses profile moderation statuses', () {
      expect(statusFromString('pending'), ProfileStatus.pending);
      expect(statusFromString('approved'), ProfileStatus.approved);
      expect(statusFromString('rejected'), ProfileStatus.rejected);
      expect(statusFromString('unknown'), ProfileStatus.draft);
      expect(statusToString(ProfileStatus.draft), 'draft');
    });

    test('parses profile verification statuses', () {
      expect(
        verificationStatusFromString('pending'),
        ProfileVerificationStatus.pending,
      );
      expect(
        verificationStatusFromString('verified'),
        ProfileVerificationStatus.verified,
      );
      expect(
        verificationStatusFromString('rejected'),
        ProfileVerificationStatus.rejected,
      );
      expect(
        verificationStatusFromString('unknown'),
        ProfileVerificationStatus.none,
      );
      expect(
        verificationStatusToString(ProfileVerificationStatus.verified),
        'verified',
      );
    });
  });
}
