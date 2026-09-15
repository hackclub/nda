class SseCustomerBlob
  S3_SERVICE = "ActiveStorage::Service::S3Service".freeze

  class Error < StandardError; end

  class << self
    def download(blob)
      encrypted?(blob) ? read_encrypted(blob) : blob.download
    end

    private

    def encrypted?(blob) = ENV["R2_SSE_CUSTOMER_KEY"].present? && blob.service.class.name == S3_SERVICE

    def read_encrypted(blob)
      service = blob.service
      service.client.client.get_object(
        bucket: service.bucket.name,
        key: blob.key,
        sse_customer_algorithm: "AES256",
        sse_customer_key: ENV.fetch("R2_SSE_CUSTOMER_KEY")
      ).body.read
    rescue Aws::S3::Errors::ServiceError => error
      raise Error, "could not read #{blob.key}: #{error.class}"
    end
  end
end
