class AdminAction < ApplicationRecord
  ACTIONS = %w[force_approve revoke reset_nda destroy_signature sync_airtable].freeze

  belongs_to :admin_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  validates :action, inclusion: { in: ACTIONS }
  validates :subject_type, :subject_id, presence: true
  validates :reason, presence: true, unless: -> { action == "sync_airtable" }

  def self.record!(admin:, target_user:, action:, subject:, reason: nil, details: {})
    create!(admin_user: admin, target_user:, action:, subject_type: subject.class.name,
      subject_id: subject.id, reason: reason.to_s.strip.presence, details:)
  end
end
