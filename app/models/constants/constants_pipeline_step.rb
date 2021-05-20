# Constants
module Constants
  # ConstantsPipelineStep
  module ConstantsPipelineStep
    GROUPED_STAGES = {
      Submitted: %w(Sourced Invited Signed Submitted),
      Applied: ['Applied'],
      # Interview: [],
      Offer: ['Offer'],
      Hired: ['Hired'],
      Onboarding: ['On-boarding'],
      Job: ['Assignment Begins', 'Assignment Ends']
    }.freeze

    # Names of pipeline stages which can be in any orders
    DYNAMIC_STAGE_TYPES =
      ['Shortlist', 'Phone Screen', 'Assessment', 'On-site Interview',
       'Phone Interview', 'Background Check',
       'Security Clearance', 'Custom'].freeze
    # Names of all pipeline stages
    # * Sourced
    # * Invited
    # * Signed
    # * Submitted
    # * Applied
    # * Shortlist
    # * Phone Screen
    # * Interview
    # * Custom
    # * Offer
    # * Hired
    # * On-boarding
    # * Assignment Begins
    # * Assignment Ends
    STAGE_TYPES =
      %w(Sourced Invited Signed Submitted Applied) +
      DYNAMIC_STAGE_TYPES +
      ['Offer', 'Hired', 'On-boarding', 'Assignment Begins',
       'Assignment Ends'].freeze

    # Pipeline steps which need to be fixed in starting of recruitment pipeline in following order:
    # * Sourced
    # * Invited
    # * Signed
    # * Submitted
    # * Applied
    FIXED_STARTING_STEPS = [{visible: true, stage_label: "Sourced", stage_description: "Uploaded or selected candidates will be initially placed in 'Sourced'. Sourced candidates are people who need to be reached out to establish their genuine interest in the position.", stage_order: 1.1},
          {visible: false, stage_label: "Invited", stage_description: "Candidate Invited for job.", stage_order: 1.2},
          {visible: false, stage_label: "Signed", stage_description: "Candidates accepted the 'Right to Represent' terms of service.", stage_order: 1.3},
          {visible: true, stage_label: "Submitted", stage_description: "Only candidates who have been screened and accepted the 'Right to Represent' terms of service can be applied to a job.", stage_order: 1.4},
          {visible: true, stage_label: "Applied", stage_description: "On final review by account managers only qualified applicants are then submitted to the client for consideration.", stage_order: 1.5}]
      # {visible: true, stage_label: "Shortlisted", stage_description: "Client shortlist the candidate submitted by account manager.", stage_order: 1.6}

    # Pipeline steps which need to be fixed in end of recruitment pipeline in following order:
    # * Offer
    # * Hired
    # * On-boarding
    # * Assignment Begins
    # * Assignment Ends
    FIXED_END_STEPS = [{visible: true, stage_label: "Offer", stage_description: "Offer the job to selected candidate.", stage_order: 3.1},
        {visible: true, stage_label: "Hired", stage_description: "Candidate is hired if he accepts the job.", stage_order: 3.2},
        {visible: true, stage_label: "On-boarding", stage_description: "On-boarding package sent to candidate.", stage_order: 3.3},
        {visible: false, stage_label: "Assignment Begins", stage_description: "Assignment Begins.", stage_order: 3.4},
        {visible: false, stage_label: "Assignment Ends", stage_description: "Assignment Ends.", stage_order: 3.5}]

    BEELINE_FIXED_END_STEPS = [{visible: true, stage_label: "Offer", stage_description: "Offer the job to selected candidate.", stage_order: 3.1},
        {visible: true, stage_label: "Hired", stage_description: "Candidate is hired if he accepts the job.", stage_order: 3.2},
        {visible: false, stage_label: "Assignment Begins", stage_description: "Assignment Begins.", stage_order: 3.4}]

    FIXED_DETAILED_STAGES = (FIXED_STARTING_STEPS + FIXED_END_STEPS)
    FIXED_STAGES = FIXED_DETAILED_STAGES.collect{|stage| stage[:stage_label]}

    # * Sourced
    # * Invited
    # * Signed
    RECRUITER_STAGES = %w[Sourced Invited Signed].freeze

    FILLED_STAGES =
      ['Hired', 'On-boarding', 'Assignment Begins', 'Assignment Ends'].freeze

    INVITED = %w[Sourced Invited].freeze

    REVISED_RTR = %w[Sourced Offer].concat FILLED_STAGES

    HOPPING = ['Sourced', 'Invited', 'Signed', 'Assignment Ends'].freeze

    DISQUALIFIABLE_TYPES = %w[Submitted Applied].concat(DYNAMIC_STAGE_TYPES).concat(%w[Offer Hired]).freeze

    PROFILE_CHECK = GROUPED_STAGES.except(:Submitted).values
                                  .flatten
                                  .concat DYNAMIC_STAGE_TYPES

    STAGES_FILTER = [
      { label: 'Sourced', value: ['Sourced'] },
      { label: 'Invited', value: ['Invited'] },
      { label: 'Signed', value: ['Signed'] },
      { label: 'Submitted', value: ['Submitted'] },
      { label: 'Applied', value: ['Applied'] },
      { label: 'Interview', value: DYNAMIC_STAGE_TYPES },
      { label: 'Offer', value: ['Offer'] },
      { label: 'Hired', value: ['Hired'] },
      { label: 'Onboarding', value: ['On-boarding'] },
      { label: 'On-assignment', value: ['Assignment Begins'] },
    ]

    NON_BACK_STAGES = [
      'Sourced',
      'Invited',
      'Signed',
      'Submitted',
      'Offer',
      'Hired',
      'On-boarding',
      'Assignment Begins',
    ].freeze

    TS_BILL_RATE = ['Sourced', 'Assignment Begins', 'Assignment Ends'].freeze
    HO_BILL_RATE = GROUPED_STAGES[:Submitted] + GROUPED_STAGES[:Job]

    ACTIVITY_STAGES = %w(Sourced Submitted Applied Rejected).freeze

    OBA_STAGES = [
      'Submitted',
      'Applied',
      'Interview',
      'Offer',
      'Hired',
      'On-boarding',
      'Assignment Begins',
      'Disqualified',
    ].freeze

    STATISTICS_TILE_STAGES = [
      'Sourced',
      'Invited',
      'Submitted',
      'Applied',
      'Interview',
      'Offer',
      'Hired',
      'Disqualified',
    ].freeze
  end
end
