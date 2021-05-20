module ModelCallback
  module CallbacksHiringOrganization
    include Concerns::AcronymGenerator

    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_address
        before_validation :init_fields
        before_destroy :can_destroy
        after_create :default_rp
        after_create :generate_initials
      end
    end

    ########################
    private
    ########################

    def init_fields
      return unless direct? && client
      self.logo = client['logo']
      self.image_resized = client.image_resized
    end

    def can_destroy
      return if disabled?
      errors.add(:status, 'should be disabled')
      throw :abort
    end

    def default_rp
      recruitment_pipelines.create(
        name: "Default #{company_relationship_name}",
        description: "This is default rp of #{company_relationship_name} hiring organization with 
        type #{company_relationship}"
      )
    end

    def generate_initials
      create_initials(HiringOrganization, id, company_relationship_name)
    end
  end
end
