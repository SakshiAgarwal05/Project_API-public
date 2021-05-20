json.call(
  bill_rate_negotiation,
  :id,
  :value,
  :rtr_id,
  :proposed_note,
  :reject_note,
  :rejected_by_id,
  :approve_note,
  :approved_by_id,
  :status,
  :last_bill_rate,
  :created_at,
  :updated_at
)

if bill_rate_negotiation.proposed_by
  json.proposed_by do
    json.call(
      bill_rate_negotiation.proposed_by,
      :id,
      :first_name,
      :last_name,
      :username,
      :primary_role
    )
  end
end

if bill_rate_negotiation.approved_by
  json.approved_by do
    json.call(
      bill_rate_negotiation.approved_by,
      :id,
      :first_name,
      :last_name,
      :username,
      :primary_role
    )
  end
end

if bill_rate_negotiation.rejected_by
  json.rejected_by do
    json.call(
      bill_rate_negotiation.rejected_by,
      :id,
      :first_name,
      :last_name,
      :username,
      :primary_role
    )
  end
end

read = bill_rate_negotiation.read_bill_rate_by(current_user)

json.user_status permission_bill_rate_negotiation(current_user, read, bill_rate_negotiation)
json.read read

declined_rate = bill_rate_negotiation.declined_rate
if declined_rate.present?
  json.declined_rate do
    json.call(
      declined_rate,
      :id,
      :value,
      :rtr_id,
      :proposed_note,
      :reject_note,
      :rejected_by_id,
      :approve_note,
      :approved_by_id,
      :status,
      :created_at,
      :updated_at
    )

    if declined_rate.rejected_by
      json.rejected_by do
        json.call(
          declined_rate.rejected_by,
          :id,
          :first_name,
          :last_name,
          :username,
          :primary_role
        )
      end
    end
  end
end
