module ZeroDataRetention
  HEADER = "x-zero-data-retention".freeze

  # https://docs.x.ai/developers/faq/security#how-to-check-that-zdr-is-enabled
  def enforce_zero_data_retention!(response, error_class, subject)
    zdr = response[HEADER].to_s.strip
    return if zdr.blank? || zdr.casecmp?("true")

    raise error_class, "xAI reports that zero data retention is disabled; #{subject} rejected."
  end
end
