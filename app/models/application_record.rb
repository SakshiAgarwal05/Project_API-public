require 'thread'
class ApplicationRecord < ActiveRecord::Base
  include ActiveModel::Dirty

  scope :get_order, ->(field, direction) {
    field = Arel.sql(field) if field.is_a?(String)
    field = field.desc if direction.to_s.downcase.eql?("desc")
    order(field)
  }

  self.abstract_class = true

  def self.parallel_import(options = {})
    t = Time.now
    batch_size = 500
    update_only = options[:update_only]
    atts = new.attributes.keys.select { |att| !att.match(/id/) }
    order = atts.include?('created_at') ? :created_at : atts.first
    unless update_only
      __elasticsearch__.create_index! force: true
      __elasticsearch__.refresh_index!
      puts "indexes refreshed\n"
      sleep(3)
    end
    queue = Queue.new
    batch_start = options[:batch_start] || 0
    (batch_start..(count / batch_size)).each { |batch_number| queue << batch_number }
    threads = 5.times.collect do
      Thread.new do
        while queue.length > 0
          # to fix Circular dependency detected while autoloading constant
          Rails.application.reloader.wrap do
            batch = queue.pop(true)
            objects = offset(batch * batch_size).limit(batch_size).order(order => :asc)
            objects = objects.includes(es_includes) if defined?(es_includes)
            body = objects.map do |receiver|
              { index: { _id: receiver.id, data: receiver.__elasticsearch__.as_indexed_json } }
            end
            if body.any?
              begin
                response = __elasticsearch__.client.bulk(
                  index: index_name,
                  type: document_type,
                  body: body
                )
                errors = response['items'].map { |k, v| k.values.first['error'] }.compact
              rescue
              end
              # raise errors if errors.any?

              puts "indexed batch #{batch}"
            end
          end
        end
      end
    end
    threads.each(&:join)
    puts "Took #{Time.now - t} seconds to index #{to_s}"
  end

  def self.alias_for_nested_attributes(attr1, attr2)
    define_method attr1 do |val|
      if val.is_a?(ActionController::Parameters) ||
        (val.is_a?(Array) && (val[0].is_a?(Hash) || val.blank?)) ||
        val.is_a?(Hash)

        association = attr1.to_s.gsub('=', '').to_sym
        if self.class.reflect_on_association(association).
          is_a?(ActiveRecord::Reflection::HasManyReflection) &&
          val.is_a?(Hash)
          val = val.values
          val.uniq!
        end
        self.send(attr2, val)
      else
        super(val)
      end
    end
  end

  def self.import(options={}, &block)
    __elasticsearch__.import(options, &block)
  end

  def self.custom_query_with_association(query, associations)
    results = find_by_sql(query)
    return [] if results.blank?
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload(results, associations)
    results
  end

  def filter_time(stats_by, &block)
    time = {}
    case stats_by
    when 'today'
      time['from_time'] = Time.now.beginning_of_day.utc
      time['to_time'] = Time.now.end_of_day.utc
    when 'week'
      time['from_time'] = Time.now.beginning_of_week.utc
      time['to_time'] = Time.now.end_of_week.utc
    when 'month'
      time['from_time'] = Time.now.beginning_of_month.utc
      time['to_time'] = Time.now.end_of_month.utc
    else
      from_time = block.call
      time['from_time'] = from_time.beginning_of_week.utc
      time['to_time'] = Time.now.end_of_week.utc
    end
    time
  end

end

module ActiveRecord
  class Relation
    def selector
      where_values_hash
    end
  end

  module FinderMethods
    def find(*args)
      return super if block_given?
      begin
        find_with_ids(*args)
      rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid
        nil
      end
    end
  end

  module Core
    module ClassMethods
      def find(*ids)
        begin
          super
        rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid
          nil
        end
      end
    end
  end
end
