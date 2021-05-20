# Constants
module Constants
  # ConstantsJob
  module ConstantsJob
    # There are 3 types of billing which must be strored in <tt>billing_type</tt>
    # * Full Times
    # * Contracts
    TYPES_OF_JOB = ['Full Time', 'Contract', 'Corp To Corp'].freeze

    ALL_STAGES = [
      'On Hold', 'Closed', 'Open', 'Disabled', 'Draft', 'Scheduled', 'Under Review',
    ].freeze

    ACTIVE_STAGES = ['On Hold', 'Closed', 'Open'].freeze

    STAGES_FOR_APPLICATION = ['On Hold', 'Open'].freeze

    STAGES_FOR_CLOSED = %w(Closed).freeze

    ALL_STATUS = [
      'Draft',
      'On Hold',
      'Closed',
      'Scheduled',
      'Open',
      'Disabled',
      'Archived',
      'Under Review',
    ].freeze

    NOT_CLOSED_STAGES = [
      'Draft', 'Scheduled', 'Open', 'On Hold', 'Disabled', 'Under Review',
    ].freeze

    INACTIVE_STAGES = ['Disabled', 'Draft', 'Scheduled', 'Under Review'].freeze

    # There are three types of working location
    # * Onsite
    # * Remote
    # * Field
    LOCATION_TYPES = ['Onsite', 'Remote', 'Field Work', 'Flexible'].freeze

    BENEFITS =
      [
        'Dental',
        'Eye Care',
        'Medical',
        'Stock Options',
        'Vacation Pay',
        'Incentive Plans',
        'Remote Work',
        'Relocation Assistance',
      ].freeze

    HUMANIZED_ATTRIBUTES = {
      job_id: 'Job ID',
    }.freeze

    JOB_STAGE_NOTES = {
      reason_to_close_job: :is_closed?,
      reason_to_onhold_job: :is_onhold?,
    }.freeze

    OPEN_STATUS = %w(Open).freeze

    CLOSING_REASONS =
      [
        'Filled by Us',
        'Position filled other vendor',
        'Closed by request of client',
        'Other',
      ].freeze

    HOLD_UNHOLD_REASON = {
      AUTO_HOLD_REASON: 'Applied candidate profiles are being screened by the hiring manager',
      AUTO_RESUME_REASON: 'This job has resumed and accepting candidates',
    }.freeze

    ENTERPRISE_CLOSING_REASONS =
      [
        'Position filled by internal candidate',
        'Position filled by outside vendor',
        'Position cancelled',
        'Other',
      ].freeze

    DELETABLE = ['Draft', 'Under Review'].freeze

    JOB_SCORE_VALUES = {
      client: 1,
      hiring_organization: 1,
      billing_term: 1,
      recruitment_pipeline: 1,
      supervisor: 2,
      account_manager: 4,
      onboarding_agent: 1,
      title: 2,
      job_id: 1,
      type_of_job: 2,
      start_date: 2,
      duration: 2,
      positions: 2,
      max_applied_limit: 2,
      years_of_experience: 1,
      address: 1,
      city: 1,
      postal_code: 1,
      country: 1,
      state: 1,
      work_permits: 3,
      suggested_pay_rate: { type: 'json', score: 1 },
      marketplace_reward: { type: 'json', score: 5 },
      benefits: { type: 'array', max: 4 },
      skills: { type: 'array', max: 7 },
      summary: { type: 'text', char_per_point: 50, max: 10 },
      responsibilities: { type: 'text', char_per_point: 44, max: 8 },
      minimum_qualification: { type: 'text', char_per_point: 50, max: 7 },
      preferred_qualification: { type: 'text', char_per_point: 22, max: 7 },
      additional_detail: { type: 'text', char_per_point: 50, max: 2 },
      recruiter_tips: { type: 'text', char_per_point: 30, max: 5 },
    }.freeze
  end
end
