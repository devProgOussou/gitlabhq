# frozen_string_literal: true

class ChatNotificationWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :sticky

  TimeoutExceeded = Class.new(StandardError)

  sidekiq_options retry: false
  feature_category :integrations
  urgency :low # Can't be high as it has external dependencies
  weight 2
  worker_has_external_dependencies!

  RESCHEDULE_INTERVAL = 2.seconds
  RESCHEDULE_TIMEOUT = 5.minutes

  def perform(build_id, reschedule_count = 0)
    Ci::Build.find_by_id(build_id).try do |build|
      send_response(build)
    end
  rescue Gitlab::Chat::Output::MissingBuildSectionError
    raise TimeoutExceeded if timeout_exceeded?(reschedule_count)

    # The creation of traces and sections appears to be eventually consistent.
    # As a result it's possible for us to run the above code before the trace
    # sections are present. To better handle such cases we'll just reschedule
    # the job instead of producing an error.
    self.class.perform_in(RESCHEDULE_INTERVAL, build_id, reschedule_count + 1)
  end

  def send_response(build)
    Gitlab::Chat::Responder.responder_for(build).try do |responder|
      if build.success?
        output = Gitlab::Chat::Output.new(build)

        responder.success(output.to_s)
      else
        responder.failure
      end
    end
  end

  private

  def timeout_exceeded?(reschedule_count)
    (reschedule_count * RESCHEDULE_INTERVAL) >= RESCHEDULE_TIMEOUT
  end
end
