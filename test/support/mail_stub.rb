module MailStub
  def sent_mail = @sent_mail ||= []
  def sent_mail_for(template) = sent_mail.select { |mail| mail[:transactional_id] == "tmpl_#{template}" }

  def with_stubbed_mail(&block)
    with_loops_env do
      singleton = LoopsClient.singleton_class
      original = singleton.instance_method(:send_email)
      collector = sent_mail
      singleton.define_method(:send_email) do |to:, transactional_id:, data_variables: {}|
        collector << { to: to, transactional_id: transactional_id,
                       data_variables: data_variables.with_indifferent_access }
      end
      begin
        perform_enqueued_jobs(only: SendEmailJob, &block)
      ensure
        singleton.define_method(:send_email, original)
      end
    end
  end

  private

  def with_loops_env
    previous = {}
    values = { "LOOPS_API_KEY" => "test-loops-key" }
      .merge(LoopsClient::TEMPLATES.to_h { |name, var| [ var, "tmpl_#{name}" ] })
    previous = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
