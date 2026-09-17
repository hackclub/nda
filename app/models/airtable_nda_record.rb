class AirtableNdaRecord < ApplicationRecord
  validates :airtable_record_id, :email, :normalized_email, :signed_at, presence: true
  validates :airtable_record_id, uniqueness: true

  def self.signed_for(email)
    address = normalize_email(email)
    return if address.blank?

    order(:signed_at).find_by(normalized_email: address)&.to_airtable_record
  end

  def self.backfill_complete? = AirtableNdaBackfill.exists?

  def self.replace_from_airtable!(records)
    rows = records.filter_map do |record|
      normalized_email = normalize_email(record.email)
      next if normalized_email.blank?

      {
        airtable_record_id: record.id,
        email: record.email,
        normalized_email: normalized_email,
        signer_name: record.name,
        signed_at: record.signed_at,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    transaction do
      upsert_all(rows, unique_by: :airtable_record_id) if rows.any?
      where.not(airtable_record_id: rows.pluck(:airtable_record_id)).delete_all
      AirtableNdaBackfill.delete_all
      AirtableNdaBackfill.create!(completed_at: Time.current)
    end

    rows.size
  end

  def to_airtable_record
    LegacyNda::AirtableRecord::Found.new(
      id: airtable_record_id,
      email: email,
      name: signer_name,
      signed_at: signed_at,
      document_url: nil,
      document_filename: nil,
      document_bytes: nil
    )
  end

  def self.normalize_email(email) = email.to_s.strip.downcase
  private_class_method :normalize_email
end
