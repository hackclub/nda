class ZeroDataRetention
  class Error < StandardError; end

  def self.verify!(response)
    return if response["x-zero-data-retention"].to_s.casecmp?("true")

    raise Error, "xAI did not confirm zero data retention"
  end
end
