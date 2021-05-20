module Admin
  class TagsController < Admin::BaseController
    include Concerns::TagsActions
    before_action :add_new_tags
    before_action :set_profile

    # URL
    # /admin/profile_copies/:id/tags [POST]
    # tags[name][]
    def create
      tags_create_action
    end
  end
end
