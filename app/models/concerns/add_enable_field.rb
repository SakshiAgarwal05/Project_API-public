module AddEnableField
  def enable
    locked_at.nil?
  end

  def enable=(val)
    val = if val.is_true?
            true
          elsif val.is_false?
            false
          end
    if val && locked_at
      self.locked_at = nil
    elsif !val && locked_at.nil?
      self.locked_at = Time.now
    end
  end

  def disable
    !enable
  end

  alias enabled enable
  alias enabled? enable
  alias enable? enable

  alias disabled disable
  alias disabled? disable
  alias disable? disable

  alias enabled= enable=
end
