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

  test "a row someone already holds cannot be claimed again" do
    first = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(first) }

    users(:two).update!(email: "ada@example.com")
    second = import_for(users(:two))
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(second) }

    assert_predicate second.reload, :email_pending?
    assert_nil second.nda_signature
    assert_nil users(:two).reload.reportable_nda_signature
  end

  test "a crafted address cannot widen the lookup to somebody else's row" do
    @user.update!(email: %q{a"),{Signed?})+("@example.com})
    import = import_for
    with_airtable(rows: [ SIGNED ]) { LegacyNda::AirtableImport.claim!(import) }

    assert_predicate import.reload, :email_pending?
    assert_empty NdaSignature.all
  end
end
