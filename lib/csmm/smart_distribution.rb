# frozen_string_literal: true

# prepare LOAD_PATH so that we can require smart_distribution_services_pb
# without too much boilerplate
#
this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(File.dirname(this_dir), 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
$LOAD_PATH.unshift(this_dir) unless $LOAD_PATH.include?(this_dir)

require 'aws-sdk-sqs' # v2: require 'aws-sdk'

module CSMM
  FEEDBACK_CLICK = 0
  FEEDBACK_REJECT = 1

  class SmartDistribution
    def self.current
      @current ||= SmartDistribution.new
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

    # Recommend recruiters give a job_id, by default, the function returns
    # the top 3 recruiters, this can be changed by providing top_n argument
    #
    # To view a list of recommended recruiters without storing the recommendation
    # in csmm, set query_only to true
    #
    # ==== Examples
    # job_id = '018309ea-aa9f-4ec8-94ed-025508628363'
    #
    # response = CSMM::SmartDistribution.current.recommend_recruiters(job_id, 3)
    def recommend_recruiters(job_id,
                             top_n: 3,
                             exclude_on_reopen: false,
                             manual_request_id: '',
                             minimum_sd_score: 0.02)
      return if Rails.env.test? || Rails.env.development?
      request = {
        job_id: job_id,
        top_n: top_n,
        minimum_sd_score: minimum_sd_score,
        exclude_on_reopen: exclude_on_reopen,
        manual_request_id: manual_request_id
      }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'recommend_recruiters_to_a_job', message: request }.to_json
      )
    end

    # Add a smartdistribution matched recruiter as being manually distributed
    # by internal user
    #
    # After running recommend_recruiters(..., query_only=true) it's imperative
    # to call add_recommended_recruiter if an internal user manually distribute
    # a recruiter to a job. This keeps the states sane
    #
    #
    # ==== Examples
    # stub_job_id = '018309ea-aa9f-4ec8-94ed-025508628363'
    # stub_recruiter_id = '000000ea-aa9f-4ec8-94ed-000000000000'
    # score = score_returned_by_recommend_recruiter
    # created_by = user_id_of_internal_user_that_manually_distributed
    #
    # response = CSMM::SmartDistribution.current.add_recommend_recruiter(
    #   stub_job_id, stub_recruiter_id, score, created_by
    # )
    #
    def add_recommended_recruiter(job_id, recruiter_id, score, created_by)
      return if Rails.env.test? || Rails.env.development?
      request = {
        job_id: job_id,
        recruiter_id: recruiter_id,
        score: score,
        created_by: created_by,
      }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'add_recommended_recruiter', message: request }.to_json
      )
    end

    # Relay the recruiter's feedback on the recommendation back to the system
    # ==== Examples
    # stub_job_id = '018309ea-aa9f-4ec8-94ed-025508628363'
    # stub_recruiter_id = '0a2e5823-7c31-4f04-bbcc-950c03a584db'
    #
    # # report recruiter clicking on the recommendation
    # response = CSMM::SmartDistribution.current.recommendation_feedback(
    #     stub_job_id,
    #     stub_recruiter_id,
    #     FeedbackType::CLICK,
    #     )
    #
    # # report recruiter rejecting on the recommendation
    # response = CSMM::SmartDistribution.current.recommendation_feedback(
    #     stub_job_id,
    #     stub_recruiter_id,
    #     FeedbackType::REJECT,
    #     "Does not pay enough"
    #     )
    def recommendation_feedback(job_id, recruiter_id, feedback_type, feedback_detail)
      return if Rails.env.test? || Rails.env.development?
      feedback_detail = "" if feedback_detail.blank?
      request = {
        job_id: job_id,
        recruiter_id: recruiter_id,
        feedback_type: feedback_type,
        feedback_detail: feedback_detail,
      }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'recommendation_feedback', message: request }.to_json
      )
    end
    # Set expired_at as now()  for all recruiters that were recommended for the job_id
    #
    # ==== Examples
    # job_id = "3ec996f1-b1e1-400d-86fc-0b3fc966ca10",
    #
    # response = CSMM::SmartDistribution.current.expired_recommended_recruiters(job_id)
    def expire_recommended_recruiters(job_id)
      return if Rails.env.test? || Rails.env.development?
      request = { job_id: job_id }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'expire_recommended_recruiters', message: request }.to_json
      )
    end

    # Request calculation of similarity score for a job
    def compute_similarity_score(job_id)
      return if Rails.env.test? || Rails.env.development?
      request = { job_id: job_id }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'compute_similarity_score', message: request }.to_json
      )
    end

    # Request calculation of Static POH elements. Attractivness and estimation
    def compute_static_poh(job_id)
      # return if Rails.env.test? || Rails.env.development?
      request = { job_id: job_id }
      @sqs.send_message(
        queue_url: @queue_url,
        message_body: { type: 'compute_static_poh_scores', message: request }.to_json
      )
    end
  end
end

# If this file is run directly with ruby, we show the example code's output
example if $PROGRAM_NAME == __FILE__
