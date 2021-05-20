# Load the Rails application.
require_relative 'application'

ActiveRecord::SchemaDumper.ignore_tables = ['spatial_ref_sys']

# Initialize the Rails application.
Rails.application.initialize!
