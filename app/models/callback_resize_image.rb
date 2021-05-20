module CallbackResizeImage
  def self.included(receiver)
    receiver.class_eval do
      after_save :resize_image
    end
  end

  ###########################
  private

  def resize_image
    return unless changed.include?('logo') || changed.include?('avatar')
    update_column(:image_resized, false)
    RenameFileJob.set(wait: 10.seconds).perform_later(self.class.to_s, id)
  end
end
