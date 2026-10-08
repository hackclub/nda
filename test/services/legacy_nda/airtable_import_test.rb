require "test_helper"
require_relative "../../support/airtable_stub"

class LegacyNda::AirtableImportTest < ActiveSupport::TestCase
  include AirtableStub

  SIGNED = {
    id: "recSigned", "Email": "ada@example.com", "Legal First Name": "Ada", "Legal Last Name": "Lovelace",
    "Signed?": true, "Loops - ndaCompletedAt": "2025-06-01T10:00:00.000Z"
  }.freeze

  setup do
    @user = users(:one)
    @user.update!(email: "ada@example.com")
    AirtableNdaRecord.delete_all
    AirtableNdaBackfill.delete_all
  end

  def import_for(user = @user) = user.legacy_nda_imports.create!(source: "airtable", ip_address: "192.0.2.1")

  test "records a legacy signature when the account email matches a signed row" do
    import = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :approved?
    signature = import.nda_signature
    assert_equal "legacy", signature.signature_type
    assert_equal "airtable", signature.legacy_source
    assert_equal "recSigned", signature.airtable_record_id
    assert_equal NdaDocument::LEGACY_VERSION, signature.document_version
    assert_equal "Ada Lovelace", signature.signed_name
    assert_equal Time.utc(2025, 6, 1, 10), signature.signed_at
    assert_equal signature, @user.reload.reportable_nda_signature
  end

  test "a row someone started and abandoned is not a signature" do
    import = import_for
    unsigned = SIGNED.merge("Signed?": false, "Loops - ndaCompletedAt": nil)
    with_airtable(rows: [ unsigned ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :email_pending?
    assert_nil import.nda_signature
    assert_nil @user.reload.reportable_nda_signature
  end

  test "takes the earliest signing when an address appears twice" do
    import = import_for
    later = SIGNED.merge(id: "recLater", "Loops - ndaCompletedAt": "2026-02-02T10:00:00.000Z")
    with_airtable(rows: [ later, SIGNED ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_equal "recSigned", import.reload.nda_signature.airtable_record_id
  end

  test "an unmatched account email asks for another address rather than settling" do
    import = import_for
    with_airtable(rows: []) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :email_pending?
    assert_empty NdaSignature.all
  end

  test "changing the contact email cannot claim another member's Airtable row" do
    @user.update!(email: "victim@example.com")
    victim = SIGNED.merge("Email": "victim@example.com")
    import = import_for

    with_airtable(rows: [ victim ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :email_pending?
    assert_nil import.nda_signature
  end

  test "an address in the base is sent a code" do
    import = import_for
    import.update!(state: "email_pending")
    with_airtable(rows: [ SIGNED ]) do
      with_stubbed_mail { LegacyNda::AirtableImport.challenge!(import, "ada@example.com") }
    end

    assert_predicate import.reload, :challenge_pending?
    assert_equal [ "ada@example.com" ], sent_mail_for(:import_challenge).map { _1[:to] }
    assert import.challenge_digest.present?
  end

  test "an address that never signed reaches the same page and is sent nothing" do
    import = import_for
    import.update!(state: "email_pending")
    with_airtable(rows: [ SIGNED ]) do
      with_stubbed_mail { LegacyNda::AirtableImport.challenge!(import, "stranger@example.com") }
    end

    assert_predicate import.reload, :challenge_pending?, "the page must not reveal that the address is unknown"
    assert_empty sent_mail_for(:import_challenge)
    assert_nil import.challenge_digest
    assert_not LegacyNda::EmailChallenge.verify(import, "000000")
  end

  test "a code settles the claim under the address that was challenged" do
    @user.update!(email: "school@example.com")
    import = import_for
    import.update!(state: "email_pending")
    with_airtable(rows: [ SIGNED ]) do
      with_stubbed_mail { LegacyNda::AirtableImport.challenge!(import, "ada@example.com") }
      assert LegacyNda::EmailChallenge.verify(import, sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"])
      LegacyNda::AirtableImport.settle_challenge!(import)
    end

    assert_predicate import.reload, :approved?
    assert_equal "ada@example.com", import.nda_signature.legacy_signer_email
  end

  test "a second account on the same verified address is covered by the row's one signature" do
    first = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(first) }

    users(:two).update!(email: "ada@example.com", verified_email: "ada@example.com")
    second = import_for(users(:two))
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(second) }

    held = first.reload.nda_signature
    assert_predicate second.reload, :approved?
    assert_nil second.nda_signature, "the row must still back only one signature"
    assert_equal held, second.covering_signature
    assert_equal held, users(:two).reload.reportable_nda_signature
    assert_equal "account_email", second.nda_signature_link.proven_via
    assert_equal 1, NdaSignature.count
  end

  test "a second account can prove a held row's address with a code" do
    first = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(first) }

    second = import_for(users(:two))
    second.update!(state: "email_pending")
    with_airtable(rows: [ SIGNED ]) do
      with_stubbed_mail { LegacyNda::AirtableImport.challenge!(second, "ada@example.com") }
      assert_equal [ "ada@example.com" ], sent_mail_for(:import_challenge).pluck(:to)
      assert LegacyNda::EmailChallenge.verify(second, sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"])
      LegacyNda::AirtableImport.settle_challenge!(second)
    end

    assert_predicate second.reload, :approved?
    assert_equal "challenge", second.nda_signature_link.proven_via
    assert_equal first.reload.nda_signature, users(:two).reload.reportable_nda_signature
  end

  test "a row held under a different address is not shared" do
    held = create_legacy_signature(users(:two), legacy_source: "airtable", airtable_record_id: "recSigned",
      legacy_signer_email: "grace@example.com")
    import = import_for
    with_airtable(rows: [ SIGNED ]) do
      LegacyNda::AirtableImport.claim!(import)
      import.update!(state: "email_pending")
      with_stubbed_mail { LegacyNda::AirtableImport.challenge!(import, "ada@example.com") }
    end

    assert_empty sent_mail_for(:import_challenge)
    assert_empty held.nda_signature_links
    assert_nil @user.reload.reportable_nda_signature
  end

  test "a link stops counting once the signature behind it is revoked" do
    first = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(first) }
    users(:two).update!(verified_email: "ada@example.com")
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import_for(users(:two))) }

    first.reload.nda_signature.update!(verification_state: "rejected")

    assert_nil users(:two).reload.reportable_nda_signature
  end

  test "a sign-in on a second account with the same address is covered without asking" do
    held = create_legacy_signature(users(:two), legacy_source: "airtable", airtable_record_id: "recSigned")

    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.check_on_sign_in(@user) }

    assert_predicate @user.legacy_nda_imports.sole, :approved?
    assert_equal held, @user.reload.reportable_nda_signature
  end

  test "a crafted address cannot widen the lookup to somebody else's row" do
    @user.update!(verified_email: %q{a"),{Signed?})+("@example.com})
    import = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :email_pending?
    assert_empty NdaSignature.all
  end

  test "uses a backfilled record without querying Airtable" do
    record = LegacyNda::AirtableRecord::Found.new(
      id: "recSigned", email: "Ada@Example.com", name: "Ada Lovelace",
      signed_at: Time.utc(2025, 6, 1, 10), document_url: nil, document_filename: nil, document_bytes: nil
    )
    AirtableNdaRecord.replace_from_airtable!([ record ])
    import = import_for

    LegacyNda::AirtableImport.claim!(import)

    assert_predicate import.reload, :approved?
    assert_equal "recSigned", import.nda_signature.airtable_record_id
  end

  test "a completed backfill makes a missing email a local negative lookup at sign-in" do
    AirtableNdaRecord.replace_from_airtable!([])

    with_airtable(rows: [ SIGNED ]) { assert_nil LegacyNda::AirtableImport.check_on_sign_in(@user) }

    assert_empty NdaSignature.all
  end

  test "an explicit lookup finds a row signed after the backfill" do
    AirtableNdaRecord.replace_from_airtable!([])
    import = import_for

    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :approved?
    assert_equal "recSigned", import.nda_signature.airtable_record_id
  end

  test "a code goes to an address signed after the backfill" do
    AirtableNdaRecord.replace_from_airtable!([])
    import = import_for
    import.update!(state: "email_pending")

    with_airtable(rows: [ SIGNED ]) do
      with_stubbed_mail { LegacyNda::AirtableImport.challenge!(import, "ada@example.com") }
    end

    assert_predicate import.reload, :challenge_live?
    assert_equal [ "ada@example.com" ], sent_mail_for(:import_challenge).pluck(:to)
  end

  test "a completed backfill stays a local negative lookup when Airtable is not configured" do
    AirtableNdaRecord.replace_from_airtable!([])
    import = import_for

    LegacyNda::AirtableImport.claim!(import)

    assert_predicate import.reload, :email_pending?
  end
  test "fresh lookup uses the corrected live email despite a cached match" do
    AirtableNdaRecord.create!(airtable_record_id: "recStale", email: @user.verified_email,
      normalized_email: @user.verified_email, signer_name: "Old match", signed_at: 1.year.ago)
    AirtableNdaBackfill.create!(completed_at: Time.current)
    import = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import, fresh: true) }
    assert_equal "recSigned", import.reload.nda_signature.airtable_record_id
  end

  test "fresh lookup still requires the verified email and an unclaimed signed row" do
    @user.update!(email: "other@example.com")
    import = import_for
    with_airtable(rows: [ SIGNED.merge("Email": "other@example.com") ]) do
      LegacyNda::AirtableImport.claim!(import, fresh: true)
    end
    assert_predicate import.reload, :email_pending?
    create_legacy_signature(users(:two), airtable_record_id: "recSigned", legacy_signer_email: "grace@example.com")
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import, fresh: true) }
    assert_nil import.reload.covering_signature
  end
end
