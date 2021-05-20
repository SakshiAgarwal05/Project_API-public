if notification.key.eql?('bill_rate_requested') ||
  notification.key.eql?('bill_rate_proposed')
  bill_rate = BillRateNegotiation.find(notification.specific_obj['bill_rate_negotiation'])

  json.accept_bill_rate current_user.can?(:approve, bill_rate)
  json.decline_bill_rate current_user.can?(:decline, bill_rate)
  json.cancel_bill_rate current_user.can?(:cancel, bill_rate)
end
