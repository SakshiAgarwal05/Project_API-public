module Validations
  # ValidationsProfile
  module ValidationsProfile
    def self.included(receiver)
      receiver.class_eval do
        validates :sin, length: { maximum: 4 }
        validates :languages,validate_uniqueness_in_memory: {
          message: 'Duplicate languages selected.',
          uniq_attr: :name,
          attrs: [:embeddable_id, :embeddable_type]
        }

        validate :check_saved_talents
        validates :summary, html_content_length: { maximum: 5000 }
        validate :uniqueness_of_my_candidate_profile, on: :create
      end
    end

    ########################
    private
    ########################

    def uniqueness_of_my_candidate_profile
      return if !my_candidate ||
        profilable_type != "User" ||
        talent.get_profile_for(profilable).nil?

      errors.add(:base, 'This candidate has already been saved in your candidates')
    end

    def check_saved_talents
      return unless my_candidate && !talent.enable
      errors.add(:base, I18n.t('talent.error_messages.disabled'))
    end

  end
end
