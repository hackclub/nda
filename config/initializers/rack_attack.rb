Rack::Attack.throttle("requests per IP", limit: 10, period: 1.second, &:ip)

Rack::Attack.throttle("legacy import uploads per IP", limit: 10, period: 1.hour) do |request|
  request.ip if request.post? && request.path == "/legacy_nda_import"
end

Rack::Attack.throttle("legacy import challenges per IP", limit: 20, period: 1.hour) do |request|
  request.ip if request.post? && request.path == "/legacy_nda_import/challenge"
end

Rack::Attack.throttle("legacy import lookups per IP", limit: 10, period: 1.hour) do |request|
  request.ip if request.post? && request.path.in?(%w[/legacy_nda_import/lookup /legacy_nda_import/lookup_email])
end

Rack::Attack.throttled_response_retry_after_header = true
