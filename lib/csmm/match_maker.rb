# frozen_string_literal: true

# prepare LOAD_PATH so that we can require matchmaker_services_pb
# without too much boilerplate
#
this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(File.dirname(this_dir), 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
$LOAD_PATH.unshift(this_dir) unless $LOAD_PATH.include?(this_dir)

require 'aws-sdk-sqs' # v2: require 'aws-sdk'

module CSMM
  class MatchMaker
    MEAN_TIME_FEEDBACKS = 'mean_time_feedbacks'
    MEAN_TIME_UPDATES = 'mean_time_updates'
    AVG_TIME_SUBMITED_TO_APPLY = 'average_time_submited_to_apply'
    AVG_TIME_APPLIED_TO_INTERVIEWED = 'average_time_applied_to_interviewed'
    AVG_STAGE_CHANGES = 'avg_stage_changes'

    def self.current
      @current ||= MatchMaker.new
    end

    class << self
      attr_writer :current
    end

    def initialize(csmm_host: nil)
      return if Rails.env.test? || Rails.env.development?
      @sqs = Aws::SQS::Client.new(
        access_key_id: ENV['SQS_AWS_KEY'],
        secret_access_key: ENV['SQS_AWS_SECRET'],
        region: ENV['SQS_REGION']
      )
      @queue_url = @sqs.get_queue_url({ queue_name: ENV['SQS_QUEUE_NAME'] }).queue_url
    end

    # Triggers calculation for average times in Jobs feedback and
    # job changes
    #
    def calculate_feedback(job_id, time, action_type, talents_job_id = '', stage = '')
      return if Rails.env.test? || Rails.env.development?
      request = {
        job_id: job_id,
        timestamp_of_update: time.to_s,
        type: action_type,
        talents_job_id: talents_job_id,
        stage: stage,
      }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'calculate_feedback', message: request }.to_json
      )
    end

    # Handles and decide what method triggers to activate CSMM
    # shared DB
    def handle_csmm_update(obj)
      return false if Rails.env.test? || Rails.env.development?
      return false unless obj
      case obj.class.name
      when 'Talent'
        handle_candidate_save(obj.id)
      when 'User'
        handle_recruiter_save(obj.id)
      when 'Job'
        handle_job_save(obj.id)
      else
        return false
      end
    end

    # Triggers handler for candidate and shared DB
    #
    # ==== Examples
    #   candidate_id = 'e923a901-95a1-4020-9661-cad9d962d577'
    #   mc = CSMM:MatchMaker.current.trigger_candidate_handler(candidate_id)
    def handle_candidate_save(candidate_id)
      return if Rails.env.test? || Rails.env.development?
      request = { candidate_id: candidate_id }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'handle_candidate_save', message: request }.to_json
      )
    end

    # Triggers handler for candidate and shared DB
    #
    # ==== Examples
    #   job_id = 'e923a901-95a1-4020-9661-cad9d962d577'
    #   mc = CSMM:MatchMaker.current.trigger_job_handler(job_id)
    def handle_job_save(job_id)
      return if Rails.env.test? || Rails.env.development?
      request = { job_id: job_id }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'handle_job_save', message: request }.to_json
      )
    end

    # Triggers handler for candidate and shared DB
    #
    # ==== Examples
    #   candidate_id = 'e923a901-95a1-4020-9661-cad9d962d577'
    #   mc = CSMM:MatchMaker.current.trigger_recruiter_handler(recruiter_id)
    def handle_recruiter_save(recruiter_id)
      return if Rails.env.test? || Rails.env.development?
      request = { recruiter_id: recruiter_id }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'handle_recruiter_save', message: request }.to_json
      )
    end

    # Triggers calculation for job's perceived renevue
    #
    def calculate_job_perceived_revenue(job_id, time)
      return if Rails.env.test? || Rails.env.development?
      request = { job_id: job_id, time: time }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'calculate_job_perceived_revenue', message: request }.to_json
      )
    end 

    # Triggers handler for new recruiter
    #
    # On new recruiter save with roles agency admin, team admin, team member, sourcing agent
    # CSMM recommend 10 jobs
    def recommend_jobs_new_recruiter(recruiter_id, amount=10)
      return if Rails.env.test? || Rails.env.development?
      request = { recruiter_id: recruiter_id, amount: amount }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'recommend_10_jobs_new_recruiter', message: request }.to_json
      )
    end

    # Triggers calculation for job's generic actions
    def calculate_job_generic_actions_metrics(job_id, time)
      return if Rails.env.test? || Rails.env.development?
      request = { job_id: job_id, time: time }

      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'calculate_job_generic_action_metrics', message: request }.to_json
      )
    end

    # Request destroy of CSMM objects that depends on api3 handled objects
    def destroy_csmm_dependent_objects(obj_type, obj_id)
      return if Rails.env.test? || Rails.env.development?
      request = { object_type: obj_type, object_id: obj_id }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'destroy_dependent_objects', message: request }.to_json
      )
    end
  end
end
