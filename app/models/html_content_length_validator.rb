class HtmlContentLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless record.changed.include?(attribute.to_s)
    value = ActionView::Base.full_sanitizer.sanitize(record[attribute])
    return if value.blank? || value.length <= options[:maximum]
    record.errors.add attribute, (options[:message] || "length can't be more than #{options[:maximum]}")
  end
end
