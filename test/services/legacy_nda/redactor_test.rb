require "test_helper"

class LegacyNda::RedactorTest < ActiveSupport::TestCase
  BODY = <<~TEXT
    MUTUAL NON-DISCLOSURE AGREEMENT
    Recipient information (“Recipient”)
    Full name:              Ada Lovelace
    Email:      ada@example.com
    Co-signer information (if under 18, “Co-signer”)
    Full name:         Grace Hopper
    Email:   grace@example.com
    This Mutual Non-Disclosure Agreement (the “Agreement”) is entered into by and between the Hack
    Foundation and Recipient.
    1. Confidential Information Defined
    All information furnished or disclosed in connection with the Discussions.
    AGREED
    Printed Name:            Ada Lovelace
    Date:        2026-06-14 05:41 AM
  TEXT

  setup { @redacted = LegacyNda::Redactor.call(BODY) }

  test "removes the recipient and co-signer information block" do
    assert_not_includes @redacted, "Ada Lovelace"
    assert_not_includes @redacted, "Grace Hopper"
    assert_not_includes @redacted, "Recipient information"
  end

  test "removes the signature block at the foot of the agreement" do
    assert_not_includes @redacted, "AGREED"
    assert_not_includes @redacted, "2026-06-14"
  end

  test "removes every email address" do
    assert_empty @redacted.scan(LegacyNda::Redactor::EMAIL)
  end

  test "keeps the agreement text itself" do
    assert_includes @redacted, "MUTUAL NON-DISCLOSURE AGREEMENT"
    assert_includes @redacted, "1. Confidential Information Defined"
    assert_includes @redacted, "All information furnished or disclosed"
  end

  test "handles text with nothing to redact" do
    assert_equal "plain agreement text", LegacyNda::Redactor.call("plain agreement text")
    assert_equal "", LegacyNda::Redactor.call(nil)
  end
end
