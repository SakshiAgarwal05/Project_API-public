this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(File.dirname(this_dir), 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
$LOAD_PATH.unshift(this_dir) unless $LOAD_PATH.include?(this_dir)

require 'aws-sdk-sqs' # v2: require 'aws-sdk'

module CSMM
  class CsmmSqsTaskHandler
    def self.current
      @current ||= CsmmSqsTaskHandler.new
    end

    class << self
      attr_writer :current
    end

    def initialize
      return if Rails.env.test? || Rails.env.development?
      @sqs = Aws::SQS::Client.new(
        access_key_id: ENV['SQS_AWS_KEY'],
        secret_access_key: ENV['SQS_AWS_SECRET'],
        region: ENV['SQS_REGION']
      )
      @queue_url = @sqs.get_queue_url({ queue_name: ENV['SQS_QUEUE_NAME'] }).queue_url
    end

    def send_task_to_csmm(task_name, params)
      return if Rails.env.test? || Rails.env.development?
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: task_name, message: params }.to_json
      )
    end
  end
end
