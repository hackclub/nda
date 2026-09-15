Rack::Attack.throttle("requests per IP", limit: 10, period: 1.second, &:ip)
Rack::Attack.throttled_response_retry_after_header = true
