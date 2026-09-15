class NotifyNdaSignedJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on SlackClient::TransientError, wait: :polynomially_longer, attempts: 5

  MESSAGE = ":hii: Your NDA has been processed! You can view your signed agreement here: https://nda.hackclub.com/nda_signature".freeze

  def perform(signature_id)
    signature = NdaSignature.includes(:user).find(signature_id)
    SlackClient.post_message(channel: signature.user.slack_id, text: MESSAGE)
  end
end
