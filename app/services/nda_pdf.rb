require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true

class NdaPdf
  PAGE = { page_size: "LETTER", margin: 54 }.freeze
  BODY = 9.5
  CLOSING_HEIGHT = 300
  RULE = "AAAAAA".freeze

  SUBSTITUTIONS = { "‑" => "-", "−" => "-", " " => " " }.freeze

  def self.call(signature) = new(signature).render

  def self.filename(signature)
    name = signature.user.legal_name.presence || signature.signed_name
    "#{name.to_s.gsub(/[^\w .-]/, "").squish} - Hack Club Contributor NDA.pdf"
  end

  def initialize(signature)
    @signature = signature
    @user = signature.user
  end

  def render
    pdf = Prawn::Document.new(**PAGE, info: info)
    pdf.font "Times-Roman"
    heading(pdf, NdaDocument::TITLE, size: 15, align: :center)
    parties(pdf)
    NdaDocument::INTRODUCTION.each { |type, text| block(pdf, type, text) }
    NdaDocument::SECTIONS.each do |title, blocks|
      heading(pdf, title, size: 10.5)
      blocks.each { |type, text| block(pdf, type, text) }
    end
    closing(pdf)
    pdf.render
  end

  private

  attr_reader :signature, :user

  def info
    {
      Title: "#{NdaDocument::TITLE} - #{user.legal_name}",
      Author: "Hack Club", Creator: "nda.hackclub.com", Subject: NdaDocument::VERSION,
      CreationDate: signature.signed_at
    }
  end

  def heading(pdf, text, size:, align: :left)
    pdf.move_down 12
    pdf.text sanitize(text), size: size, style: :bold, align: align
    pdf.move_down 4
  end

  def block(pdf, type, text)
    return heading(pdf, text, size: 10) if type == :subhead

    pdf.indent(type == :clause ? 18 : 0) do
      pdf.text sanitize(text), size: BODY, leading: 2, align: :justify, inline_format: false
    end
    pdf.move_down 6
  end

  def parties(pdf)
    panel(pdf, "Recipient information (“Recipient”)", {
      "Full name" => user.legal_name, "Email" => user.email, "Slack ID" => user.slack_id
    })
    return if signature.cosigner_name.blank?

    panel(pdf, "Co-signer information (“Co-signer”)", {
      "Full name" => signature.cosigner_name, "Email" => signature.cosigner_email
    })
  end

  def closing(pdf)
    pdf.start_new_page if pdf.cursor < CLOSING_HEIGHT
    agreed(pdf)
    certificate(pdf)
    footer(pdf)
  end

  def agreed(pdf)
    heading(pdf, "AGREED", size: 10.5)
    rows(pdf, {
      "Recipient Signature" => signature.signed_name, "Printed Name" => user.legal_name,
      "Date" => signature.signed_at.to_fs(:long)
    })
    return if signature.cosigner_name.blank?

    pdf.move_down 6
    return rows(pdf, { "Co-signer Signature" => "Awaiting signature from #{signature.cosigner_name}" }) unless signature.cosigned?

    rows(pdf, {
      "Co-signer Signature" => signature.cosigner_signed_name,
      "Printed Name" => signature.cosigner_signed_name,
      "Date" => signature.cosigner_signed_at.to_fs(:long)
    })
  end

  def certificate(pdf)
    panel(pdf, "Signing certificate", {
      "Slack ID" => user.slack_id,
      "Document version" => signature.document_version,
      "Document SHA-256" => signature.document_sha256,
      "Signed at" => signature.signed_at.utc.iso8601,
      "Verify at" => "https://nda.hackclub.com/api/v1/nda_status/#{user.slack_id}"
    })
  end

  def panel(pdf, title, values)
    pdf.move_down 12
    pdf.text sanitize(title), size: 10, style: :bold
    pdf.move_down 4
    rows(pdf, values)
  end

  def rows(pdf, values)
    values.compact_blank.each do |label, value|
      pdf.text "<b>#{sanitize(label)}:</b> #{sanitize(value)}", size: BODY, leading: 2, inline_format: true
    end
  end

  def footer(pdf)
    pdf.move_down 16
    pdf.stroke_color RULE
    pdf.stroke_horizontal_rule
    pdf.move_down 6
    pdf.text sanitize(NdaDocument::FOOTER), size: 8
    pdf.number_pages "<page> of <total>", at: [ 0, -12 ], align: :right, size: 8
  end

  def sanitize(value) = value.to_s.gsub(/[#{SUBSTITUTIONS.keys.join}]/, SUBSTITUTIONS)
end
