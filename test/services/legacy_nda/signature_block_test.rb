require "test_helper"

class LegacyNda::SignatureBlockTest < ActiveSupport::TestCase
  COMPLETED = <<~TEXT
    AGREED
    Recipient Signature: ______________________________________
    Printed Name:            Ada Lovelace
    Date:
               2026-06-14 05:41 AM
    (If Recipient is under 18)
    Co-signer Signature: ______________________________________
    Printed Name:         Grace Hopper
    Date:        2026-06-14 06:19 AM
                                                          Last revised 2025-04-01
  TEXT

  ADULT = <<~TEXT
    AGREED
    Recipient Signature: ______________________________________
    Printed Name:            Ada Lovelace
    Date:        2026-06-14 05:41 AM
    (If Recipient is under 18)
    Co-signer Signature: ______________________________________
    Printed Name:
    Date:
  TEXT

  test "reads a value that wrapped onto the next line" do
    block = LegacyNda::SignatureBlock.parse(COMPLETED)

    assert_equal "Ada Lovelace", block.recipient_name
    assert_equal Date.new(2026, 6, 14), block.recipient_date
  end

  test "reads a value that stayed on the label line" do
    block = LegacyNda::SignatureBlock.parse(COMPLETED)

    assert_equal "Grace Hopper", block.cosigner_name
    assert_equal Date.new(2026, 6, 14), block.cosigner_date
    assert block.cosigner_present?
  end

  test "treats an unfilled co-signer block as absent" do
    block = LegacyNda::SignatureBlock.parse(ADULT)

    assert block.recipient_complete?
    assert_not block.cosigner_present?
    assert_nil block.cosigner_name
    assert_nil block.cosigner_date
  end

  test "reports an incomplete recipient block" do
    block = LegacyNda::SignatureBlock.parse("AGREED\nRecipient Signature: ____\nPrinted Name:\nDate:\n")

    assert_not block.recipient_complete?
  end

  test "yields nothing from text with no signature block" do
    block = LegacyNda::SignatureBlock.parse("just the agreement text, no block here")

    assert_nil block.recipient_name
    assert_nil block.recipient_date
    assert_not block.recipient_complete?
  end
end
