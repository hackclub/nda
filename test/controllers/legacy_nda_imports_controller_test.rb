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
    assert_match(/larger than 25 MB/i, flash[:alert])
  end

  test "limits how many times a member can try in a day" do
    LegacyNdaImportsController::MAX_ATTEMPTS_PER_DAY.times { users(:one).legacy_nda_imports.create! }

    post :create, params: { document: upload }

    assert_equal LegacyNdaImportsController::MAX_ATTEMPTS_PER_DAY, users(:one).legacy_nda_imports.count
    assert_match(/try again tomorrow/i, flash[:alert])
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
end
