module Fields
  module FieldsNote
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :user
        belongs_to :parent, class_name: 'Note'
        belongs_to :notable, polymorphic: true

        has_many :media, as: :mediable
        has_many :read_notes_users, dependent: :destroy
        has_many :read_by, through: :read_notes_users, source: :user
        has_many :replies, class_name: 'Note', foreign_key: :parent_id

        has_many :mentioned_notes_users, dependent: :delete_all
        has_many :mentioned, through: :mentioned_notes_users, source: :user

        accepts_nested_attributes_for :media, allow_destroy: true
        alias_for_nested_attributes :media=, :media_attributes=
      end
    end
  end
end
