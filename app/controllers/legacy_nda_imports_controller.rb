class LegacyNdaImportsController < ApplicationController
  before_action :require_login

  REJECTION = "We could not validate your NDA. If this keeps happening, please sign a new one.".freeze
  MAX_ATTEMPTS_PER_DAY = 5
  TOO_MANY = "Slow down there, you already tried several times today! May I recommend that you just sign a new NDA instead?".freeze

  def show
    @import = current_import
  end

  def create
    return redirect_to legacy_nda_import_path, notice: "You're already covered by an NDA." if already_covered?

    if attempts_today >= MAX_ATTEMPTS_PER_DAY
      return redirect_to legacy_nda_import_path, alert: TOO_MANY
    end

    document = params.require(:document)
    if (error = upload_error(document))
      return redirect_to legacy_nda_import_path, alert: error
    end

    import = current_user.legacy_nda_imports.create!(source: "upload", ip_address: request.remote_ip)
    import.document.attach(document)
    VerifyLegacyNdaImportJob.perform_later(import.id)
    redirect_to legacy_nda_import_path, notice: "Checking your document. This usually takes a few seconds."
  end

  def lookup
    return redirect_to legacy_nda_import_path, notice: "You're already covered by an NDA." if already_covered?

    if attempts_today >= MAX_ATTEMPTS_PER_DAY
      return redirect_to legacy_nda_import_path, alert: TOO_MANY
    end

    import = current_user.legacy_nda_imports.create!(source: "airtable", ip_address: request.remote_ip)
    ImportAirtableNdaJob.perform_later(import.id)
    redirect_to legacy_nda_import_path, notice: "Checking our records for your NDA."
  end

  def lookup_email
    import = current_import
    return redirect_to legacy_nda_import_path unless import&.email_pending?

    LegacyNda::AirtableImport.challenge!(import, params[:email])
    redirect_to legacy_nda_import_path
  end

  def challenge
    import = current_import
    return redirect_to legacy_nda_import_path unless import&.challenge_pending?

    unless LegacyNda::EmailChallenge.verify(import, params[:code])
      return redirect_to legacy_nda_import_path, alert: "That code isn't right, or it has expired."
    end

    if import.source_airtable?
      LegacyNda::AirtableImport.settle_challenge!(import)
    else
      LegacyNda::Claim.settle!(import)
    end
    redirect_to legacy_nda_import_path
  end

  private

  def current_import = @current_import ||= current_user.legacy_nda_imports.order(:created_at).last

  def already_covered? = current_user.reportable_nda_signature.present?

  def attempts_today = current_user.legacy_nda_imports.where(created_at: 24.hours.ago..).count

  def upload_error(document)
    return "Please choose a PDF to upload." unless document.respond_to?(:content_type)
    return "Please upload a PDF." unless document.content_type.in?(LegacyNdaImport::DOCUMENT_TYPES)
    return "Yowza! That file is bigger than 25 MB, try a smaller one." if document.size > LegacyNdaImport::MAX_DOCUMENT_BYTES

    nil
  end
end
