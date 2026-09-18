require "test_helper"
require_relative "../support/legacy_pdf_factory"

class LegacyNdaImportsControllerAuthTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get legacy_nda_import_url
    assert_redirected_to root_url
  end
end

class LegacyNdaImportsControllerTest < ActionController::TestCase
  include ActiveJob::TestHelper
  tests LegacyNdaImportsController

  setup do
    session[:user_id] = users(:one).id
    @pdf = LegacyPdfFactory.legacy_document_pdf(recipient_email: users(:one).email)
  end

  def upload(bytes = @pdf, content_type: "application/pdf", filename: "nda.pdf")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), content_type, original_filename: filename)
  end

  test "offers the upload form to a member with no import" do
    get :show

    assert_response :success
    assert_select "input[name='document'][accept*='pdf']"
  end

  test "accepts a PDF and queues verification without blocking the request" do
    assert_enqueued_with(job: VerifyLegacyNdaImportJob) do
      post :create, params: { document: upload }
    end

    import = users(:one).legacy_nda_imports.sole
    assert_predicate import, :pending?
    assert_predicate import.document, :attached?
    assert_redirected_to legacy_nda_import_path
  end

  test "refuses anything that is not a PDF" do
    post :create, params: { document: upload("not a pdf", content_type: "text/plain", filename: "x.txt") }

    assert_empty users(:one).legacy_nda_imports
    assert_match(/upload a PDF/i, flash[:alert])
  end

  test "refuses an upload over the size cap" do
    post :create, params: { document: upload("%PDF-" + "x" * LegacyNdaImport::MAX_DOCUMENT_BYTES) }

    assert_empty users(:one).legacy_nda_imports
    assert_match(/bigger than 25 MB/i, flash[:alert])
  end

  test "limits how many times a member can try in a day" do
    LegacyNdaImportsController::MAX_ATTEMPTS_PER_DAY.times { users(:one).legacy_nda_imports.create! }

    post :create, params: { document: upload }

    assert_equal LegacyNdaImportsController::MAX_ATTEMPTS_PER_DAY, users(:one).legacy_nda_imports.count
    assert_match(/sign a new NDA instead/i, flash[:alert])
  end

  test "does not ask a member who is already covered to import anything" do
    create_signature(users(:one), signed_at: Time.current)

    post :create, params: { document: upload }

    assert_empty users(:one).legacy_nda_imports
    assert_match(/already covered/i, flash[:notice])
  end

  test "tells a member nothing about why a document failed" do
    users(:one).legacy_nda_imports.create!(state: "rejected", reasons: %w[untrusted_certificate])

    get :show

    assert_response :success
    assert_select "p.flash-alert", text: LegacyNdaImportsController::REJECTION
    assert_not_includes response.body, "untrusted_certificate"
    assert_not_includes response.body, "signature_mismatch"
  end

  test "shows a pending import as still being checked" do
    users(:one).legacy_nda_imports.create!(state: "verifying")

    get :show

    assert_select "[data-import-pending]"
  end

  test "offers an approved legacy holder an explicit path to sign the new version" do
    signature = create_legacy_signature(users(:one))
    users(:one).legacy_nda_imports.create!(state: "approved", nda_signature: signature)

    get :show

    assert_select "h1", "Your old NDA is on file!"
    assert_select "a[href=?]", nda_signature_path(sign_new: 1), text: "Sign the new NDA"
  end

  test "offers the records check alongside the upload form" do
    get :show

    assert_response :success
    assert_select "form[action=?]", lookup_legacy_nda_import_path
  end

  test "checking the records needs no file and does not block the request" do
    assert_enqueued_with(job: ImportAirtableNdaJob) do
      post :lookup
    end

    import = users(:one).legacy_nda_imports.sole
    assert_predicate import, :source_airtable?
    assert_predicate import, :pending?
    assert_not import.document.attached?
  end

  test "the records check counts against the same daily limit" do
    LegacyNdaImportsController::MAX_ATTEMPTS_PER_DAY.times { users(:one).legacy_nda_imports.create! }

    post :lookup

    assert_equal LegacyNdaImportsController::MAX_ATTEMPTS_PER_DAY, users(:one).legacy_nda_imports.count
    assert_match(/sign a new NDA instead/i, flash[:alert])
  end

  test "does not check the records for a member who is already covered" do
    create_signature(users(:one), signed_at: Time.current)

    post :lookup

    assert_empty users(:one).legacy_nda_imports
    assert_match(/already covered/i, flash[:notice])
  end

  test "asks for another address when the account email finds nothing" do
    users(:one).legacy_nda_imports.create!(source: "airtable", state: "email_pending")

    get :show

    assert_response :success
    assert_select "form[action=?]", lookup_email_legacy_nda_import_path
  end

  test "will not take an address unless the import is waiting for one" do
    users(:one).legacy_nda_imports.create!(source: "airtable", state: "pending")

    post :lookup_email, params: { email: "ada@example.com" }

    assert_predicate users(:one).legacy_nda_imports.sole, :pending?
  end

  test "does not consume a valid code when settlement has a transient failure" do
    import = users(:one).legacy_nda_imports.create!(source: "airtable")
    with_stubbed_mail { LegacyNda::EmailChallenge.issue!(import, email: "ada@example.com") }
    code = sent_mail_for(:import_challenge).last[:data_variables]["challenge_code"]
    singleton = LegacyNda::AirtableImport.singleton_class
    original = singleton.instance_method(:settle_challenge!)
    singleton.define_method(:settle_challenge!) { |_| raise AirtableClient::TransientError, "temporary outage" }

    assert_raises(AirtableClient::TransientError) { post :challenge, params: { code: code } }

    assert import.reload.challenge_digest.present?
    assert_predicate import, :challenge_pending?
  ensure
    singleton&.define_method(:settle_challenge!, original) if original
  end

  test "can issue a fresh code after the resend interval" do
    import = users(:one).legacy_nda_imports.create!(source: "upload")
    with_stubbed_mail { LegacyNda::EmailChallenge.issue!(import, email: "ada@example.com") }
    old_digest = import.challenge_digest
    import.update_column(:updated_at, LegacyNda::EmailChallenge::RESEND_INTERVAL.ago - 1.second)

    with_stubbed_mail { post :resend_challenge }

    assert_redirected_to legacy_nda_import_path
    assert_not_equal old_digest, import.reload.challenge_digest
  end
end
