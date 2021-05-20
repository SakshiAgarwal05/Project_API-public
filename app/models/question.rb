class Question < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESQuestion
  include Constants::ConstantsQuestion
  include Fields::FieldsQuestion
  include Validations::ValidationsQuestion
  include Scopes::ScopesQuestion
end
