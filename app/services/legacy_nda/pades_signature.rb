require "openssl"

module LegacyNda
  class PadesSignature
    MAX_BYTES = 25.megabytes
    SUBFILTERS = %w[ETSI.CAdES.detached adbe.pkcs7.detached].freeze
    BYTE_RANGE = %r{/ByteRange\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*\]}
    SUBFILTER = %r{/SubFilter\s*/([A-Za-z0-9.]+)}
    CONTENTS_PREFIX = %r{/Contents\s*\z}
    VERIFY_FLAGS = OpenSSL::PKCS7::NOINTERN | OpenSSL::PKCS7::NOVERIFY

    Result = Data.define(
      :signing_time, :subfilter, :spki_sha256, :certificate_sha256, :certificate_subject, :byte_range
    )

    Error = Class.new(CodedError)

    class << self
      def verify!(bytes, allowlist: CertificateAllowlist.default)
        bytes = bytes.b
        validate_container!(bytes)
        byte_range = byte_range!(bytes)
        cms = parse_cms!(contents!(bytes, byte_range))
        certificate = pinned_certificate!(cms, allowlist)
        raise Error, :signature_mismatch unless
          cms.verify([ certificate ], OpenSSL::X509::Store.new, signed_bytes(bytes, byte_range), VERIFY_FLAGS)

        Result.new(
          signing_time: signing_time!(cms),
          subfilter: bytes[SUBFILTER, 1],
          spki_sha256: CertificateAllowlist.spki_sha256(certificate),
          certificate_sha256: CertificateAllowlist.certificate_sha256(certificate),
          certificate_subject: certificate.subject.to_utf8,
          byte_range: byte_range
        )
      rescue OpenSSL::PKCS7::PKCS7Error, OpenSSL::ASN1::ASN1Error, OpenSSL::X509::CertificateError
        raise Error, :unparsable_signature
      end

      private

      def parse_cms!(der)
        OpenSSL::PKCS7.new(der)
      rescue ArgumentError, OpenSSL::PKCS7::PKCS7Error, OpenSSL::ASN1::ASN1Error
        raise Error, :unparsable_signature
      end

      def validate_container!(bytes)
        raise Error, :too_large if bytes.bytesize > MAX_BYTES
        raise Error, :not_a_pdf unless bytes.start_with?("%PDF-")
        raise Error, :encrypted_pdf if bytes.include?("/Encrypt")
      end

      def byte_range!(bytes)
        raise Error, :multiple_signatures if bytes.scan("/ByteRange").size > 1

        match = bytes.match(BYTE_RANGE) or raise Error, :missing_signature
        raise Error, :unsupported_subfilter unless bytes[SUBFILTER, 1].in?(SUBFILTERS)

        range = match.captures.map(&:to_i)
        validate_byte_range!(bytes, range)
        range
      end

      # The signed ranges must be the whole file bar the hole holding the signature, or bytes went
      # unsigned: an incremental update, a trailing payload, a decoy /ByteRange in a stream.
      def validate_byte_range!(bytes, range)
        first_start, first_length, second_start, second_length = range
        gap_start = first_start + first_length

        raise Error, :byte_range_not_from_start unless first_start.zero?
        raise Error, :byte_range_not_to_end unless second_start + second_length == bytes.bytesize
        raise Error, :byte_range_gap_mismatch unless second_start > gap_start + 1
        raise Error, :byte_range_gap_mismatch unless
          bytes.byteslice(gap_start, 1) == "<" && bytes.byteslice(second_start - 1, 1) == ">"
        raise Error, :byte_range_gap_mismatch unless
          bytes.byteslice([ gap_start - 32, 0 ].max, [ gap_start, 32 ].min).match?(CONTENTS_PREFIX)
      end

      def contents!(bytes, range)
        gap_start = range[0] + range[1]
        hex = bytes.byteslice(gap_start + 1, range[2] - gap_start - 2)
        raise Error, :malformed_contents unless hex.match?(/\A\h*\z/) && hex.length.even?

        [ hex ].pack("H*")
      end

      def signed_bytes(bytes, range)
        bytes.byteslice(range[0], range[1]) + bytes.byteslice(range[2], range[3])
      end

      def pinned_certificate!(cms, allowlist)
        signers = cms.signers
        raise Error, :missing_signer if signers.empty?
        raise Error, :multiple_signers if signers.size > 1

        signer = signers.first
        certificate = Array(cms.certificates).find do |candidate|
          candidate.issuer == signer.issuer && candidate.serial == signer.serial
        end
        raise Error, :missing_certificate unless certificate
        raise Error, :untrusted_certificate unless allowlist.include?(certificate)

        certificate
      end

      def signing_time!(cms)
        cms.signers.first.signed_time&.utc or raise Error, :missing_signing_time
      rescue OpenSSL::PKCS7::PKCS7Error
        raise Error, :missing_signing_time
      end
    end
  end
end
