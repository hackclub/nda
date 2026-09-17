require "test_helper"

class NdaSignaturesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get nda_signature_url
    assert_redirected_to root_url
  end
end

class NdaSignaturesControllerPdfTest < ActionController::TestCase
  tests NdaSignaturesController

  setup { session[:user_id] = users(:one).id }

  test "hands a signed member their agreement as a PDF" do
    signature = create_signature(users(:one), signed_at: Time.current)

    get :show, format: :pdf

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/filename="Ada Lovelace - Hack Club Contributor NDA.pdf"/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-"), "expected a PDF"
    assert_equal NdaPdf.call(signature).bytesize, response.body.bytesize
  end

  test "has no PDF to hand over before anyone has signed" do
    get :show, format: :pdf

    assert_redirected_to nda_signature_path
  end

  test "offers the download on the receipt" do
    create_signature(users(:one), signed_at: Time.current)

    get :show

    assert_select "a[href=?]", nda_signature_path(format: :pdf)
  end

  test "shows a legacy holder the signed receipt instead of the signing form" do
    create_legacy_signature(users(:one))

    get :show

    assert_select "h1", "Your NDA is signed!"
    assert_select ".receipt", /Imported from the old signing system/
    assert_select "[data-wizard]", count: 0
    assert_select "a[href=?]", nda_signature_path(sign_new: 1), text: "Sign the new NDA"
  end

  test "lets a legacy holder deliberately open the new signing form" do
    create_legacy_signature(users(:one))

    get :show, params: { sign_new: "1" }

    assert_select "[data-wizard]"
    assert_select ".receipt", count: 0
  end

  test "opens the new signing form when an admin has moved a legacy holder" do
    user = users(:one)
    create_legacy_signature(user)
    user.update!(current_nda_required_at: Time.current)

    get :show

    assert_select "[data-wizard]"
    assert_select ".receipt", count: 0
  end
end

class NdaSignaturesControllerFormTest < ActionController::TestCase
  tests NdaSignaturesController

  test "prefills the legal name from the Hack Club profile" do
    session[:user_id] = users(:one).id
    get :show

    assert_select "input[name='user[legal_first_name]'][value='Ada']"
    assert_select "input[name='user[legal_last_name]'][value='Lovelace']"
    assert_select "input[name='user[birthdate]'][autocomplete='bday']"
    assert_select "input[name='cosigner_name'][autocomplete='off']"
    assert_select "input[name='cosigner_email'][autocomplete='off']"
    assert_select "select[name='user[country]'] option[value='United States']"
  end

  test "shows the signer context and revised pledge" do
    session[:user_id] = users(:one).id
    get :show

    assert_select ".lede p", count: NdaDocument::SIGNER_CONTEXT.size
    assert_select ".lede", /does not create an employment or independent contractor relationship/
    assert_select "[data-pledge] ul li", count: PledgeScript::BODY.size
    PledgeScript::BODY.each { |item| assert_select "[data-pledge] li", text: item }
  end
end

class NdaSignaturesControllerSubmissionTest < ActionController::TestCase
  include ActiveJob::TestHelper

  tests NdaSignaturesController

  setup do
    session[:user_id] = users(:one).id
  end

  test "saves the upload and queues verification without waiting for transcription" do
    assert_enqueued_with(job: VerifyNdaSignatureJob) do
      post :create, params: {
        accepted: "1",
        identity_video: fixture_file_upload("pledge.webm", "video/webm"),
        signed_name: "Ada Lovelace",
        user: SIGNING_DETAILS
      }
    end

    assert_redirected_to nda_signature_path
    signature = users(:one).signature_for_current_version
    assert_predicate signature, :processing?
    assert_predicate signature.identity_video, :attached?
    assert_nil signature.transcript
  end

  test "lets the signer discard a saved recording and retry" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(verification_state: "rejected")

    assert_difference("NdaSignature.count", -1) { delete :retry }

    assert_redirected_to nda_signature_path
  end
end

class NdaSignaturesControllerSuccessTest < ActionController::TestCase
  include ActiveJob::TestHelper

  tests NdaSignaturesController

  setup do
    session[:user_id] = users(:one).id
  end

  test "does not clear the current NDA request until verification succeeds" do
    users(:one).update!(current_nda_required_at: Time.current)
    post :create, params: {
      accepted: "1",
      identity_video: fixture_file_upload("pledge.webm", "video/webm"),
      signed_name: "Ada Lovelace",
      user: SIGNING_DETAILS
    }

    assert_redirected_to nda_signature_path
    assert users(:one).reload.current_nda_required_at?
  end

  test "shows a background processing receipt" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(verification_state: "processing", transcript: nil)

    get :show

    assert_select "[data-signature-processing]"
    assert_select "h1", "We got your video!"
    assert_select ".receipt", /close this page/
  end
end

class NdaSignaturesControllerMinorTest < ActionController::TestCase
  include ActiveJob::TestHelper

  tests NdaSignaturesController

  MINOR_DETAILS = SIGNING_DETAILS.merge(birthdate: Date.new(2011, 3, 4)).freeze

  setup { session[:user_id] = users(:one).id }

  def submit_as_minor
    post :create, params: {
      accepted: "1",
      identity_video: fixture_file_upload("pledge.webm", "video/webm"),
      signed_name: "Ada Lovelace",
      cosigner_name: "Byron Lovelace",
      cosigner_email: "parent@example.com",
      user: MINOR_DETAILS
    }
    users(:one).signature_for_current_version
  end

  test "a minor's submission waits for background verification before inviting the guardian" do
    assert_no_enqueued_jobs(only: SendEmailJob) do
      signature = submit_as_minor
      assert_predicate signature, :processing?
    end
  end

  test "nothing is announced or pushed to Airtable while consent is outstanding" do
    assert_no_enqueued_jobs(only: [ SignatureCompletedJob, NotifyNdaSignedJob, SyncSignatureToAirtableJob ]) do
      submit_as_minor
    end
  end

  test "the agreement is not downloadable until the guardian has signed" do
    submit_as_minor
    @request.env.delete("CONTENT_TYPE")

    get :show, format: :pdf
    assert_redirected_to nda_signature_path
  end

  test "a resend issues a fresh link but not a flood of them" do
    signature = submit_as_minor
    signature.user.reload
    signature.update!(verification_state: "awaiting_cosigner", transcript: "I pledge.")
    with_stubbed_mail { Cosignature.invite!(signature) }
    first = signature.cosigner_token_digest

    with_stubbed_mail { post :resend_cosigner_invite }
    assert_equal first, signature.reload.cosigner_token_digest, "a resend moments later is ignored"

    signature.update!(cosigner_invited_at: 1.hour.ago)
    with_stubbed_mail { post :resend_cosigner_invite }
    assert_not_equal first, signature.reload.cosigner_token_digest
  end
end
