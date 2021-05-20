module Concerns
  module Ability::GroupAbility

    private

    def group_permissions(user)
      permissions = user.all_permissions
      own_groups = permissions['actions own groups']
      if own_groups
        can :index, Group
        can :search, Group
        can :read, Group, hiring_organization_id: user.hiring_organization_id

        if own_groups['add new group']
          can :create, Group, hiring_organization_id: user.hiring_organization_id
        end

        if own_groups['edit a group']
          can :update, Group, hiring_organization_id: user.hiring_organization_id
        end

        if own_groups['enable/disable a group']
          can :enable, Group, hiring_organization_id: user.hiring_organization_id
        end

        if own_groups['delete a group']
          can :destroy, Group, hiring_organization_id: user.hiring_organization_id
        end

        if own_groups['enable/disable a group']
          can :group_members, Group, hiring_organization_id: user.hiring_organization_id
        end
      end
    end
  end
end
