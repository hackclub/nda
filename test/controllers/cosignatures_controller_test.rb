require "test_helper"

class CosignaturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(SIGNING_DETAILS.merge(
      birthdate: Date.new(2011, 3, 4), address_line_1: "2 Nowhere Lane", city: "Innsmouth",
      region: "MA", postal_code: "01966"
    ))
    @signature = @user.nda_signatures.build(
      document_version: NdaDocument::VERSION, document_sha256: NdaDocument.sha256,
      signed_name: "Ada Lovelace", signed_at: Time.current, transcript: "I pledge.",
      cosigner_name: "Byron Lovelace", cosigner_email: "parent@example.com",
      verification_state: "awaiting_cosigner"
    )
    @signature.identity_video.attach(
      io: file_fixture("pledge.webm").open, filename: "pledge.webm", content_type: "video/webm"
    )
    @signature.save!
    @token = with_stubbed_mail { Cosignature.invite!(@signature) } &&
      sent_mail_for(:cosign_request).sole[:data_variables]["cosign_url"].split("/cosign/").last
  end

  test "the guardian reaches the page without signing in" do
    get cosign_path(@token)

    assert_response :success
    assert_select "h1", "Your signature is needed"
    assert_match "Ada Lovelace", response.body
  end

  test "the page never exposes the teen's private details" do
    get cosign_path(@token)

    [ "2 Nowhere Lane", "Innsmouth", "01966", "2011-03-04", "I pledge.", "pledge.webm",
      @user.email, @user.slack_id ].each do |secret|
      assert_no_match(/#{Regexp.escape(secret)}/, response.body, "#{secret} must not reach the co-signer")
    end
  end

  test "the token is kept out of referrers and search engines" do
    get cosign_path(@token)

    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "signing completes the agreement" do
    post cosign_path(@token), params: { accepted: "1", cosigner_signed_name: "byron lovelace" }

    assert_response :success
    assert_predicate @signature.reload, :approved?
    assert_equal "byron lovelace", @signature.cosigner_signed_name
    assert_equal @signature, @user.reload.reportable_nda_signature
  end

  test "the agreement stays pending without the checkbox or a matching name" do
    post cosign_path(@token), params: { cosigner_signed_name: "Byron Lovelace" }
    assert_response :unprocessable_entity

    post cosign_path(@token), params: { accepted: "1", cosigner_signed_name: "Someone Else" }
    assert_response :unprocessable_entity

    assert_predicate @signature.reload, :awaiting_cosigner?
  end

  test "an unknown or spent token is a plain not-found" do
    get cosign_path("nope")
    assert_response :not_found

    post cosign_path(@token), params: { accepted: "1", cosigner_signed_name: "Byron Lovelace" }
    get cosign_path(@token)
    assert_response :not_found
  end

  test "the teen is not reported as signed while the guardian has not signed" do
    get api_v1_nda_status_path(@user.slack_id)

    assert_equal "not_signed", response.parsed_body["status"]

    post cosign_path(@token), params: { accepted: "1", cosigner_signed_name: "Byron Lovelace" }
    get api_v1_nda_status_path(@user.slack_id)

    assert_equal "signed", response.parsed_body["status"]
  end
end
