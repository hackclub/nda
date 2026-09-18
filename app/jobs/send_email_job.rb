class SendEmailJob < ApplicationJob
  KEY_SALT = "send email job payload".freeze

  queue_as :default

  discard_on ActiveSupport::MessageEncryptor::InvalidMessage
  retry_on LoopsClient::TransientError, wait: :polynomially_longer, attempts: 5

  def self.deliver_later(template, to:, data: {})
    return unless to.present? && LoopsClient.deliverable?(template)

    payload = { template: template.to_s, to: to, data: data.deep_stringify_keys }
    perform_later(encryptor.encrypt_and_sign(payload))
  end

  def perform(encrypted_payload)
    payload = self.class.encryptor.decrypt_and_verify(encrypted_payload).with_indifferent_access
    LoopsClient.deliver(payload.fetch(:template).to_sym, to: payload.fetch(:to), data: payload.fetch(:data))
  end

  def self.encryptor
    key = Rails.application.key_generator.generate_key(KEY_SALT, ActiveSupport::MessageEncryptor.key_len)
    ActiveSupport::MessageEncryptor.new(key, serializer: JSON)
  end
end
