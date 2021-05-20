module Concerns
  module Ability::EnterpriseUserAbility

    private

    def enterprize_user_permissions(user)
      permissions = user.all_permissions
      user_permissions = permissions['actions enterprise users']

      if user_permissions
        can :read_enterprise_user, User
        can :create_enterprise_user, User, if: user_permissions['create new user']

        [:update_enterprise_user, :send_password_instructions].each do |action|
          can action, User do |obj|
            user_permissions['edit an user'] &&
            user.hiring_organization_id == obj.hiring_organization_id
          end
        end

        can :toggle_enable_enterprise_user, User do |obj|
          user_permissions['enable/disable an user'] &&
          user.id != obj.id &&
          user.hiring_organization_id == obj.hiring_organization_id
        end

        can :destroy_enterprise_user, User do |obj|
          user_permissions['delete an user'] &&
          user.id != obj.id &&
          user.hiring_organization_id == obj.hiring_organization_id
        end

        can :read_enterprise, HiringOrganization do |obj|
          user_permissions['edit an user'] && user == obj.owner
        end

        can :add_update_group, User do |obj|
          user_permissions['edit an user'] &&
          user.hiring_organization_id == obj.hiring_organization_id 
        end
      end

      can :read_update_profile, User do |obj|
        user.id == obj.id &&
        user.hiring_organization_id == obj.hiring_organization_id
      end
      
      can :fixed_steps, HiringOrganization
    end

    def enterprize_user_jobs_permissions(user)
      permissions = user.all_permissions
      my_jobs = permissions['actions my jobs']

      if my_jobs
        can :jobs_listing, Job, hiring_organization_id: user.hiring_organization_id
        can :create, TalentsJob if my_jobs['sourced candidate']
        can :create, Job if my_jobs['add new job']
      end
    end
  end
end
