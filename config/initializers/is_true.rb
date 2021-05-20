class NilClass
  def is_true?
    false
  end

  def is_false?
    false
  end

  def is_true_or_false?
    false
  end

  def merge(val)
    val
  end

  def [](*)
    nil
  end

  def any?
    false
  end

end


class TrueClass
  def is_true?
    true
  end

  def is_false?
    false
  end

  def is_true_or_false?
    true
  end
end


class FalseClass
  def is_true?
    false
  end

  def is_false?
    true
  end

  def is_true_or_false?
    true
  end
end


class String
  def is_true?
    downcase.eql?('true')
  end

  def is_false?
    downcase.eql?('false')
  end

  def is_true_or_false?
    %w(true false).include?(downcase)
  end
end
