json.data do
  json.array! @onboards do |onboard|
    json.call(onboard, :id, :onboarding_document, :action_completed, :status, :file)
    json.rejected_histories onboard.rejected_histories do |rh|
      json.call(rh, :rejected_reason, :rejection_note, :file)
      json.rejected_by(rh.rejected_by, :id, :first_name, :last_name, :email)
    end
  end
end