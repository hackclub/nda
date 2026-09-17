class User < ApplicationRecord
  SLACK_ID_FORMAT = /\A[UW][A-Z0-9]{8,20}\z/

  has_many :nda_signatures, dependent: :destroy
  has_many :legacy_nda_imports, dependent: :destroy
  has_many :admin_actions, foreign_key: :admin_user_id, dependent: :restrict_with_exception,
    inverse_of: :admin_user

  validates :hack_club_identity_id, presence: true, uniqueness: true
  validates :slack_id, presence: true, uniqueness: true, format: { with: SLACK_ID_FORMAT }
  with_options if: :signing_details_present? do
    validates :legal_first_name, :legal_last_name, :email, :birthdate, :address_line_1,
      :city, :region, :postal_code, :country, presence: true
    validates :country, inclusion: { in: Country::NAMES }, allow_blank: true
    validate :birthdate_is_in_the_past
  end

  before_validation { self.slack_id = slack_id.to_s.upcase }

  def self.admin_slack_ids
    ENV["ADMIN_SLACK_IDS"].to_s.upcase.split(",").map(&:strip).compact_blank
  end

  def legal_name
    [ legal_first_name, legal_last_name ].compact_blank.join(" ")
  end

  def default_legal_first_name
    legal_first_name.presence || first_name
  end

  def default_legal_last_name
    legal_last_name.presence || last_name
  end

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || slack_id
  end

  def signature_for_current_version
    nda_signatures.find_by(document_version: NdaDocument::VERSION)
  end

  def reportable_nda_signature
    nda_signatures.approved.native.find_by(document_version: NdaDocument::VERSION) ||
      nda_signatures.approved.legacy.order(:signed_at).first
  end

  def age(on: Date.current)
    return unless birthdate

    on.year - birthdate.year - (on.yday < birthdate.yday ? 1 : 0)
  end

  def location_for_pledge
    [ city, region, country ].compact_blank.join(", ")
  end

  private

  def signing_details_present?
    legal_first_name.present? || birthdate.present?
  end

  def birthdate_is_in_the_past
    errors.add(:birthdate, "must be in the past") if birthdate && birthdate >= Date.current
  end
end
