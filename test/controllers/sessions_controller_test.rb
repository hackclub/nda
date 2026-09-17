require "test_helper"
require_relative "../support/airtable_stub"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include AirtableStub

  IDENTITY = {
    "id" => "ident!one", "slack_id" => "U0123ABCDE",
    "first_name" => "Ada", "last_name" => "Lovelace", "primary_email" => "ada@example.com"
  }.freeze

  SIGNED_ROW = {
    id: "recSigned", "Email": "ada@example.com", "Legal First Name": "Ada", "Legal Last Name": "Lovelace",
    "Signed?": true, "Loops - ndaCompletedAt": "2025-06-01T10:00:00.000Z"
  }.freeze

  test "logout clears the session" do
    delete logout_url
    assert_redirected_to root_url
  end

  test "a returning member is told they are already covered, without signing again" do
    with_auth { with_airtable(rows: [ SIGNED_ROW ]) { sign_in } }

    assert_redirected_to legacy_nda_import_path
    assert_match(/already have an NDA/i, flash[:notice])

    signature = users(:one).reload.reportable_nda_signature
    assert_equal "legacy", signature.signature_type
    assert_equal "recSigned", signature.airtable_record_id
  end

  test "a member with no row signs as normal" do
    with_auth { with_airtable(rows: []) { sign_in } }

    assert_redirected_to nda_signature_path
    assert_nil users(:one).reload.reportable_nda_signature
  end

  test "a backfilled member is recognized locally without Airtable configuration" do
    record = LegacyNda::AirtableRecord::Found.new(
      id: "recSigned", email: "ada@example.com", name: "Ada Lovelace",
      signed_at: Time.utc(2025, 6, 1, 10), document_url: nil, document_filename: nil, document_bytes: nil
    )
    AirtableNdaRecord.replace_from_airtable!([ record ])

    with_auth { sign_in }

    assert_redirected_to legacy_nda_import_path
    assert_equal "recSigned", users(:one).reload.reportable_nda_signature.airtable_record_id
  end

  test "a backfill recognizes a member who had an earlier negative check" do
    users(:one).update!(airtable_checked_at: 1.day.ago)
    record = LegacyNda::AirtableRecord::Found.new(
      id: "recSigned", email: "ada@example.com", name: "Ada Lovelace",
      signed_at: Time.utc(2025, 6, 1, 10), document_url: nil, document_filename: nil, document_bytes: nil
    )
    AirtableNdaRecord.replace_from_airtable!([ record ])

    with_auth { sign_in }

    assert_redirected_to legacy_nda_import_path
    assert_equal "recSigned", users(:one).reload.reportable_nda_signature.airtable_record_id
  end

  test "the base is only asked about a member once" do
    with_auth do
      with_airtable(rows: []) { sign_in }
      fake = with_airtable(rows: [ SIGNED_ROW ]) { sign_in }

      assert_empty fake.created, "a member already checked must not be looked up again"
    end
    assert_nil users(:one).reload.reportable_nda_signature
  end

  test "a member who already signed here is never looked up" do
    create_signature(users(:one), signed_at: Time.current)

    with_auth { with_airtable(rows: [ SIGNED_ROW ]) { sign_in } }

    assert_redirected_to nda_signature_path
    assert_nil users(:one).reload.airtable_checked_at
  end

  test "an Airtable outage does not stop anyone logging in" do
    with_auth do
      with_broken_airtable { sign_in }
    end

    assert_redirected_to nda_signature_path
    assert_equal users(:one).id, session[:user_id]
    assert_nil users(:one).reload.airtable_checked_at, "an unanswered check must be retried next time"
  end

  private

  def sign_in
    get login_url
    get oauth_callback_url(code: "auth-code", state: session[:oauth_state])
  end

  def with_auth
    singleton = HackClubAuth.singleton_class
    originals = { authorization_url: singleton.instance_method(:authorization_url),
                  identity_for: singleton.instance_method(:identity_for) }
    singleton.define_method(:authorization_url) { |state:| "https://auth.example.com/?state=#{state}" }
    singleton.define_method(:identity_for) { |_code| IDENTITY }
    yield
  ensure
    originals.each { |name, method| singleton.define_method(name, method) }
  end

  def with_broken_airtable
    singleton = AirtableClient.singleton_class
    originals = { configured?: singleton.instance_method(:configured?),
                  records: singleton.instance_method(:records) }
    singleton.define_method(:configured?) { true }
    singleton.define_method(:records) { |**| raise AirtableClient::TransientError, "Airtable is unavailable" }
    yield
  ensure
    originals.each { |name, method| singleton.define_method(name, method) }
  end
end
