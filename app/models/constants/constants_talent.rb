module Constants
  # ConstantsTalent
  module ConstantsTalent
    # Profile status for talent
    # * waiting
    # * parsed
    # * ready
    PROFILE_STATUS = {
      WAITING: 'waiting',
      PARSED: 'parsed',
      READY: 'ready',
      FAIL: 'fail',
      NOT_APPLICABLE: 'not applicable'
    }.freeze

    TALENT_STATUSES = [
      'Onboarding',
      'Available',
      'Hired',
      'On Assignment',
      'Do Not Call',
      'Do Not Contact',
      'Disabled',
    ].freeze

    # Benefits available for talent.
    # * 401k
    # * Healthcare
    # * Dental
    # * Eye Care
    # * Bonus
    # * Stock Options
    # * vacation Pay
    # * Personal days
    # * Flexible Hours
    # * Limo Services
    BENEFITS =
      [
        'Dental ',
        'Eye Care',
        'Medical',
        'Stock Options',
        'Vacation Pay',
        'Incentive Plans',
        'Remote Work',
        'Relocation Assistance',
      ].freeze

    # Possible valiues of work authorization
    # * U.S. Citizen
    # * H1B
    # * Green Card
    # * Security Clearance
    # * Requires Sponsorship'
    WORK_AUTHORIZATIONS =
      ['U.S. Citizen', 'H1B', 'Green Card', 'Security Clearance',
       'Requires Sponsorship'].freeze

    EXPERIENCE =
      { 'Training' => { 'min' => '0', 'max' => '1' },
        'Entry Level' => { 'min' => '1', 'max' => '3' },
        'Experienced' => { 'min' => '3', 'max' => '7' },
        'Manager' => { 'min' => '7', 'max' => '10' },
        'Director' => { 'min' => '10', 'max' => '15' },
        'Executive' => { 'min' => '15', 'max' => '15+' } }.freeze

    NOT_AVAILABLE = [
      'Hired',
      'Onboarding',
      'On Assignment',
      'Do Not Call',
      'Do Not Contact',
      'Disabled',
    ].freeze
  end
end
