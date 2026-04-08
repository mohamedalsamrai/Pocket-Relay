import 'package:pocket_relay/src/core/errors/pocket_error_base.dart';

abstract final class ChatComposerPocketErrorCatalog {
  static const PocketErrorDefinition imageAttachmentEmpty =
      PocketErrorDefinition(
        code: 'PR-COMP-1101',
        domain: PocketErrorDomain.chatComposer,
        meaning:
            'Attaching an image failed because the selected file was empty.',
      );
  static const PocketErrorDefinition
  imageAttachmentTooLarge = PocketErrorDefinition(
    code: 'PR-COMP-1102',
    domain: PocketErrorDomain.chatComposer,
    meaning:
        'Attaching an image failed because the selected file exceeded Pocket Relay attachment limits.',
  );
  static const PocketErrorDefinition
  imageAttachmentUnsupportedType = PocketErrorDefinition(
    code: 'PR-COMP-1103',
    domain: PocketErrorDomain.chatComposer,
    meaning:
        'Attaching an image failed because the selected file was not a supported image type.',
  );
  static const PocketErrorDefinition
  imageAttachmentDecodeFailed = PocketErrorDefinition(
    code: 'PR-COMP-1104',
    domain: PocketErrorDomain.chatComposer,
    meaning:
        'Attaching an image failed because Pocket Relay could not decode the selected file as an image payload.',
  );
  static const PocketErrorDefinition
  imageAttachmentTooLargeForRemote = PocketErrorDefinition(
    code: 'PR-COMP-1105',
    domain: PocketErrorDomain.chatComposer,
    meaning:
        'Attaching an image failed because Pocket Relay could not shrink the selected image enough for remote sending.',
  );
  static const PocketErrorDefinition
  imageAttachmentUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-COMP-1106',
    domain: PocketErrorDomain.chatComposer,
    meaning:
        'Attaching an image failed for an unexpected local picker or preprocessing reason outside the known attachment-validation states.',
  );

  static const List<PocketErrorDefinition> definitions =
      <PocketErrorDefinition>[
        imageAttachmentEmpty,
        imageAttachmentTooLarge,
        imageAttachmentUnsupportedType,
        imageAttachmentDecodeFailed,
        imageAttachmentTooLargeForRemote,
        imageAttachmentUnexpectedFailure,
      ];
}
