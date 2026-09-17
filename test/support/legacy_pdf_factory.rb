require "openssl"

# we forging ndas just for tests smh
module LegacyPdfFactory
  extend self

  RESERVED_BYTES = 8192
  BYTE_RANGE_PLACEHOLDER = "[ 0000000000 0000000000 0000000000 0000000000 ]".freeze
  DEFAULT_LINES = [
    "MUTUAL NON-DISCLOSURE AGREEMENT",
    "Recipient: Test Person",
    "Last revised 2025-04-01"
  ].freeze

  def key = @key ||= OpenSSL::PKey::RSA.generate(2048)

  def certificate = @certificate ||= self_signed(key, serial: 1)

  def rogue_key = @rogue_key ||= OpenSSL::PKey::RSA.generate(2048)

  def rogue_certificate = @rogue_certificate ||= self_signed(rogue_key, serial: 2)

  def allowlist(*certificates)
    certificates = [ certificate ] if certificates.empty?
    LegacyNda::CertificateAllowlist.new(certificates.map { |cert|
      LegacyNda::CertificateAllowlist::Pin.new(
        name: cert.subject.to_utf8,
        spki_sha256: LegacyNda::CertificateAllowlist.spki_sha256(cert),
        certificate_sha256: nil
      )
    })
  end

  def signed_pdf(lines: DEFAULT_LINES, pages: [ lines ], key: self.key, certificate: self.certificate,
    subfilter: "ETSI.CAdES.detached")
    sign(unsigned_pdf(pages, subfilter), key, certificate)
  end

  def tampered_pdf(...) = signed_pdf(...).sub("Test Person", "Xest Person")

  def appended_update_pdf(...) = signed_pdf(...) + "\n% incremental update appended after signing\n"

  def second_signature_pdf(...) = signed_pdf(...) + "\n/ByteRange [ 0 1 2 3 ]\n"

  def corrupt_signature_pdf(...)
    pdf = signed_pdf(...)
    pdf[pdf.index("/Contents <") + "/Contents <".bytesize, 8] = "ffffffff"
    pdf
  end

  def short_byte_range_pdf(...)
    pdf = signed_pdf(...)
    match = pdf.match(LegacyNda::PadesSignature::BYTE_RANGE)
    pdf.sub(match[0], match[0].sub(/#{match[4]}\s*\]\z/, format("%0#{match[4].length}d ]", match[4].to_i - 16)))
  end

  def legacy_document_pdf(recipient_name: "Ada Lovelace", recipient_email: "ada@example.com",
    cosigner_name: nil, cosigner_email: nil, envelope_id: "envelope_lhecmvlheriakemt",
    signed_at: Time.current.utc, body_date: Date.current.to_s, body: NdaDocument::LEGACY_TEXT,
    certificate_page: true, **options)
    lines = body_lines(recipient_name, recipient_email, cosigner_name, cosigner_email, body, body_date)
    pages = lines.each_slice(40).to_a
    if certificate_page
      pages << certificate_lines(recipient_name, recipient_email, cosigner_name, cosigner_email,
        envelope_id, signed_at)
    end
    signed_pdf(pages: pages, **options)
  end

  def body_lines(name, email, cosigner_name, cosigner_email, body, body_date)
    [
      "Recipient information (Recipient)",
      "Full name:              #{name}",
      "Email:      #{email}",
      "Co-signer information (if under 18, Co-signer)",
      "Full name:         #{cosigner_name}",
      "Email:   #{cosigner_email}",
      *body.lines.flat_map { |line| wrap(line.chomp) }.reject(&:empty?),
      "AGREED",
      "Recipient Signature: ______________________________________",
      "Printed Name:            #{name}",
      "Date:        #{body_date} 05:41 AM",
      "(If Recipient is under 18)",
      "Co-signer Signature: ______________________________________",
      "Printed Name:         #{cosigner_name}",
      "Date:        #{cosigner_name ? "#{body_date} 06:19 AM" : ""}"
    ]
  end

  def wrap(line, width: 95)
    return [ line ] if line.length <= width

    line.scan(/\S.{0,#{width - 1}}(?:\s|\z)/).map(&:rstrip)
  end

  def certificate_lines(name, email, cosigner_name, cosigner_email, envelope_id, signed_at)
    lines = signer_lines(name, email, signed_at)
    lines += signer_lines(cosigner_name, cosigner_email, signed_at + 26) if cosigner_name
    lines + [ "", "Envelope ID: #{envelope_id}" ]
  end

  def signer_lines(name, email, signed_at)
    stamp = signed_at.strftime("%Y-%m-%d %I:%M:%S %p UTC")
    [
      "   #{name}                                        Sent: #{stamp}",
      "   #{email}",
      "                                                  Viewed: #{stamp}",
      "   Signer",
      "                                                  Signed: #{stamp}",
      "   Authentication Level:            Signature ID",
      "   Email                            #{SecureRandom.alphanumeric(25).upcase}",
      ""
    ]
  end

  private

  def self_signed(key, serial:)
    name = OpenSSL::X509::Name.parse("/C=US/ST=Vermont/L=Shelburne/O=Hack Club/CN=hackclub.com")
    OpenSSL::X509::Certificate.new.tap do |cert|
      cert.version = 2
      cert.serial = serial
      cert.subject = name
      cert.issuer = name
      cert.public_key = key.public_key
      # real docs are also expired lol
      cert.not_before = 2.years.ago
      cert.not_after = 1.day.ago
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
    end
  end

  def unsigned_pdf(pages, subfilter)
    first = 6
    page_numbers = pages.each_index.map { |index| first + index * 2 }
    objects = {
      1 => "<< /Type /Catalog /Pages 2 0 R /AcroForm << /Fields [ 5 0 R ] /SigFlags 3 >> >>",
      2 => "<< /Type /Pages /Kids [ #{page_numbers.map { |n| "#{n} 0 R" }.join(" ")} ] /Count #{pages.size} >>",
      3 => "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      4 => "<< /Type /Sig /Filter /Adobe.PPKLite /SubFilter /#{subfilter} " \
           "/ByteRange #{BYTE_RANGE_PLACEHOLDER} /Contents <#{"0" * (RESERVED_BYTES * 2)}> >>",
      5 => "<< /Type /Annot /Subtype /Widget /FT /Sig /Rect [ 0 0 0 0 ] /T (Signature1) /V 4 0 R " \
           "/P #{page_numbers.first} 0 R >>"
    }
    pages.each_with_index do |lines, index|
      number = page_numbers[index]
      objects[number] = "<< /Type /Page /Parent 2 0 R /MediaBox [ 0 0 612 792 ] " \
                        "/Resources << /Font << /F1 3 0 R >> >> /Contents #{number + 1} 0 R" \
                        "#{index.zero? ? " /Annots [ 5 0 R ]" : ""} >>"
      objects[number + 1] = content_stream(lines)
    end
    serialize(objects)
  end

  def content_stream(lines)
    text = lines.each_with_index.map { |line, index|
      escaped = line.to_s.gsub(/[^\x20-\x7E]/, " ").gsub(/([\\()])/, '\\\\\1')
      "BT /F1 11 Tf 56 #{720 - index * 18} Td (#{escaped}) Tj ET"
    }.join("\n") + "\n"
    "<< /Length #{text.bytesize} >>\nstream\n#{text}endstream"
  end

  def serialize(objects)
    pdf = +"%PDF-1.7\n%\xE2\xE3\xCF\xD3\n".b
    offsets = {}
    objects.each do |number, body|
      offsets[number] = pdf.bytesize
      pdf << "#{number} 0 obj\n#{body}\nendobj\n"
    end
    startxref = pdf.bytesize
    pdf << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    objects.each_key { |number| pdf << format("%010d 00000 n \n", offsets[number]) }
    pdf << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\n"
    pdf << "startxref\n#{startxref}\n%%EOF\n"
  end

  def sign(pdf, key, certificate)
    gap_start = pdf.index("/Contents <") + "/Contents ".bytesize
    gap_end = gap_start + RESERVED_BYTES * 2 + 2
    pdf = pdf.sub(BYTE_RANGE_PLACEHOLDER, format(
      "[ %010d %010d %010d %010d ]", 0, gap_start, gap_end, pdf.bytesize - gap_end
    ))
    signed = pdf.byteslice(0, gap_start) + pdf.byteslice(gap_end, pdf.bytesize - gap_end)
    der = OpenSSL::PKCS7.sign(
      certificate, key, signed, [], OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY
    ).to_der
    raise "signature needs #{der.bytesize} bytes, only #{RESERVED_BYTES} reserved" if der.bytesize > RESERVED_BYTES

    pdf[gap_start + 1, RESERVED_BYTES * 2] = der.unpack1("H*").ljust(RESERVED_BYTES * 2, "0")
    pdf
  end
end
