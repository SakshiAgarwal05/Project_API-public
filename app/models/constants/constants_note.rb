module Constants
  module ConstantsNote
    HO_VISIBILITY = [
      'HO',
      'HO_AND_CROWDSTAFFING',
      'HO_AND_CROWDSTAFFING_AND_TS',
      'EVERYONE',
    ].freeze

    CROWDSTAFFING_VISIBILITY = [
      'CROWDSTAFFING',
      'CROWDSTAFFING_AND_TS',
      'HO_AND_CROWDSTAFFING',
      'HO_AND_CROWDSTAFFING_AND_TS',
      'EVERYONE',
    ].freeze

    TS_VISIBILITY = [
      'TS',
      'CROWDSTAFFING_AND_TS',
      'HO_AND_CROWDSTAFFING_AND_TS',
      'EVERYONE',
    ].freeze
  end
end
