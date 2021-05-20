module Constants
  # ConstantsTalentsJob
  module ConstantsTalentsJob
    DISQUALIFY_REASONS = {
      'Candidate Not Interested' => [
        'Distance to work location',
        'Compensation is to low',
        'Work hours are not suitable',
        'The job is not of interest',
        'Candidate Interest',
        'Change of heart ',
        'Not responsive',
        'Accepted another offer',
      ],

      'Candidate Not Available' => [
        'Happily Employed',
        'Currently On-Assignment',
        'Start dates are not suitable',
        'Could Not Contact',
        'Candidate is already represented',
      ],

      'Candidate Profile' => [
        'Resume quality not acceptable',
        'Employment Gaps',
        'Appears Over qualified',
        'No relevant work experience',
        'Missing skill sets',
        'Missing required information',
        'Missing required degree',
        'Missing required certification',
      ],

      'Candidate Assessment' => [
        'Over qualified ',
        'Does not meet min requirements',
        'Poor communication skills',
        'Not a cultural fit',
        'Late for interview',
        'Unprofessional appearance',
        'Failed background check',
        'More qualified candidates reviewed',
        'High salary expectation',
        'No references',
      ],

      'Work Authorization' => [
        'Does not have work permit/visa',
        'Does not have required accreditation',
        'Does not have security clearance',
      ],

      'Rate Compliance' => [
        'Bill Rate is not within range',
        'Pay Rate is not within range',
      ],
    }.freeze

    PRIMARY_SENTIMENTS = {
      'Candidate Not Interested' => 'Neutral',
      'Candidate Not Available' => 'Neutral',
      'Candidate Profile' => 'Negative',
      'Candidate Assessment' => 'Negative',
      'Work Authorization' => 'Negative',
      'Rate Compliance' => 'Negative',
    }.freeze

    SECONDARY_SENTIMENTS = {
      'Over qualified' => 'Neutral',
      'More qualified candidates reviewed' => 'Neutral',
    }.freeze

    ASSIGNMENT_END_REASONS = {
      'Completed' => ['Tenure limit', 'Successful', 'Converted', 'Budget'],
      'Resignation' => ['Personal Reasons', 'Better Opportunity', 'Dissatisfaction'],
      'Assessment' => ['Performance', 'Attendance', 'Abandonment'],
    }.freeze

    HIRED = ['On-boarding', 'Hired'].freeze
    ON_ASSIGNMENT = ['Assignment Begins'].freeze
    COMPLETED = ['Assignment Ends'].freeze

    OLD_REASONS = {
      ["Incomplete candidate information", "Incomplete submission"] => ['Candidate Profile', 'Missing required information', 'Negative'],

      [
        "Other",
        "Candidate disengaged, did not show interest",
        'Candidate declined invitation',
      ] => ['Candidate Not Interested', 'Not responsive', 'Neutral'],

      [
        "More qualified candidates have been submitted",
        "More competitive candidates have been submitted",
        "Client selected a different candidate",
      ] => ['Candidate Assessment', 'More qualified candidates reviewed', 'Neutral'],

      [
        "Work shift or hours not suitable",
        "Instructed by client",
        'Not qualified enough for the position',
        "Did not interview well",
      ] => ['Candidate Assessment', 'Does not meet min requirements', 'Negative'],

      [
        "Experience not relevant for position",
        "Does not meet screening requirements",
        "Experience not relevant for the position",
        "Not qualified",
        "Experience was not relevant",
      ] => ['Candidate Profile', 'No relevant work experience', 'Negative'],

      [
        "Did not meet pre-screening requirements",
        "Does not meet onboarding requirements i.e. Drug/Background",
        "Failed background check", "Previously submitted",
        "Did not meet post assessment requirements",
      ] => ['Candidate Assessment', 'Failed background check', 'Negative'],

      [
        "Accepted another job",
        "Accepted another job offer",
        "Offer was rejected",
        "Offer was rejected by candidate",
        "Brianna Saccaro on boarded for Job: Sr On-Site Service Specialist.MS Ops",
        "Lori Botuchis on boarded for Job: Manufacturing Technician I",
        "Accepted counter offer from current employer",
      ] => ['Candidate Not Interested', 'Accepted another offer', 'Neutral'],

      [
        "Duplicate submission to client",
        "Duplicate Submission to client",
        "Already signed this job with other recruiter",
        "Submitted to client by another supplier",
        "Duplicate submission",
        "Already signed job with other recruiter",
      ] => ['Candidate Not Available', 'Candidate is already represented', 'Neutral'],

      [
        "Problem with work authorization",
        "Missing proper work authorization",
        "Work authorization",
      ] => ['Work Authorization', 'Does not have work permit/visa', 'Negative'],

      [
        "Work shift or hours not suitable",
      ] => ['Candidate Not Interested', 'Work hours are not suitable', 'Neutral'],

      ["Poor communication skills"] => ['Candidate Assessment', 'Poor communication skills', 'Negative'],

      ["Poor quality of Resume/Candidate Overview"] => ['Candidate Profile', 'Resume quality not acceptable', 'Negative'],

      ["Overqualified for the position"] => ['Candidate Assessment', 'Over qualified', 'Neutral'],

      ["Candidate Cancelled/ Late to interview"] => ['Candidate Assessment', 'Late for interview', 'Negative'],

      ["Candidate unable to start when required."] => ['Candidate Not Available', 'Start date(s) are not suitable', 'Neutral'],

      ["Location, commute, or distance is too far"] => ['Candidate Not Interested', 'Distance to work location', 'Neutral'],

      ["Gaps in employment history"] => ['Candidate Profile', 'Employment Gaps', 'Negative'],

      ["Compensation is not within accepted range"] => ['Rate Compliance', 'Pay Rate is not within range', 'Negative'],

      ["Bill Rate is not within accepted range"] => ['Rate Compliance', 'Bill Rate is not within range', 'Negative'],

      [
        "Team, culture, or personality not a fit",
        "Personality wasn't a fit",
        "Candidate finds company or team not a good fit",
      ] => ['Candidate Assessment', 'Not a cultural fit', 'Negative'],

      ["Current position/assignment has been extended"] => ['Candidate Not Available', 'Currently On-Assignment', 'Neutral'],

      ["Compensation"] => ['Candidate Not Available', 'Happily Employed', 'Neutral'],
    }.freeze

    ASSIGNMENT_OLD_REASONS = {
      [
        "Assignment Completed",
        "Assignment End",
        "Assignment Successfully Completed",
        "Assignment Successfully Completed- Client Tenure Limit",
        "Moving him to  Cantel Req 000722",
      ] => ['Completed', 'Successful'],

      [
        "Converted to full-time",
        "Vendor change model",
        "Converted to full time with Client",
        "She reached her max BIS on her assignment and transition to the vendor role",
        "assignment transitioning to a vendor model",
        "TEST",
        "vendor transition",
        "Change to vendor model",
        "Internal employee",
      ] => ['Completed', 'Converted'],

      [
        "she resigned due to no work or hours",
        "Employee Resignation- Position/Client not a good match",
        "Employee resignation",
      ] => ['Resignation', 'Dissatisfaction'],

      ["Employee Performance"] => ['Assessment', 'Performance'],

      [
        "Employee Resignation- Found a better paying position",
      ] => ['Resignation', 'Better Opportunity'],

      [
        "Job Abandonment",
        "Carlos was a NO Show NO call to the client twice! We will not be moving forward with him.",
      ] => ['Assessment', 'Abandonment'],

      ['Employee Resignation- Personal matters'] => ['Resignation', 'Personal Reasons'],

      ['Employee Attendance'] => ['Assessment', 'Attendance'],
    }.freeze
  end
end
