class SendEmailJob < ApplicationJob
  queue_as :default

  discard_on LoopsClient::ConfigurationError
  retry_on LoopsClient::TransientError, wait: :polynomially_longer, attempts: 5

  def self.deliver_later(template, to:, data: {})
    return unless to.present? && LoopsClient.deliverable?(template)

    perform_later(template.to_s, to, data.deep_stringify_keys)
  end

  def perform(template, to, data)
    LoopsClient.deliver(template.to_sym, to: to, data: data)
  end
end
