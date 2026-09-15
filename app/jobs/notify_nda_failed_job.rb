class NotifyNdaFailedJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on SlackClient::TransientError, wait: :polynomially_longer, attempts: 5

  MESSAGE = ":dog_ded: We couldn't process your NDA. Log in and try again here: https://nda.hackclub.com/nda_signature".freeze

  def perform(user_id)
    user = User.find(user_id)
    SlackClient.post_message(channel: user.slack_id, text: MESSAGE)
  end
end
