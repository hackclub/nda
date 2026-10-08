# A second Hack Club account covered by a legacy signature another account holds, because it proved
# control of the same address the signature was settled on. See LegacyNda::Link.
class NdaSignatureLink < ApplicationRecord
  belongs_to :nda_signature
  belongs_to :user
  belongs_to :legacy_nda_import, optional: true

  enum :proven_via, { account_email: "account_email", challenge: "challenge" }, validate: true
end
