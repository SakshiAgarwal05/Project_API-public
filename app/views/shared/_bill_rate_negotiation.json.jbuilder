bill_rate = talents_job.rtr.bill_rate_negotiation if talents_job.rtr.present?

if bill_rate
  json.bill_rate_negotiation do
    json.partial! 'shared/bill_rate', bill_rate_negotiation: bill_rate
  end
else
  can_create = talents_job.powers(current_user)[:create_bill_rate]
  json.user_status 'new' if can_create
end
