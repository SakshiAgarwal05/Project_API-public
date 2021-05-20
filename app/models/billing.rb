module Billing
  def msp_vms_fee_rate_per_hour
    total_bill_rate.get_fraction(msp_vms_fee_rate)
  end

  # evaluate based on unit if its markup or set.
  def get_value_from_unit(parent_attr, attribute)
    attribute = send attribute
    parent_attr = send parent_attr
    attribute[:markup].is_true? ? parent_attr.get_fraction(attribute[:value]) : attribute[:value]
  end

  def total_bill_rate
    if bill_rate[:markup].is_true?
      suggested_pay_rate['min'].to_f + suggested_pay_rate['min'].get_fraction(bill_rate[:value])
    else
      bill_rate[:value]
    end
  end

  # fully loaded tax
  def calculate_employee_cost
    # MISS(TODO: TEST CASES NOT WRITTEN)
    suggested_pay_rate['min'].to_f * employee_cost * calculate_total_time
  end

  def contract_actual_payment
    # TODO: TEST CASES NOT WRITTEN
    suggested_pay_rate['min'].to_f * employee_cost + total_bill_rate.get_fraction(msp_vms_fee_rate)
  end

  def set_agency_payout
    self.agency_payout = get_value_from_unit(:net_margin, :agency_commission) || 0
  end

  def set_crowdstaffing_profit
    profit = begin
               net_margin - agency_payout
             rescue
               0
             end
    self.crowdstaffing_profit = [profit, 0].max
  end

  def contract_total(total_time = calculate_total_time)
    self.total_net_margin = net_margin.to_f * total_time
    self.total_value_of_contract = total_time * total_bill_rate.to_f
    self.total_msp_vms_fee = total_value_of_contract.get_fraction(msp_vms_fee_rate)
  end

  def total_profit_and_payout(total_time = calculate_total_time)
    self.total_crowdstaffing_profit = total_time * crowdstaffing_profit.to_f
    self.total_agency_payout = total_time * agency_payout.to_f
  end

  # initialize the fields based on the type of job selected.
  # duration for billing (i.e. pay period) must be hourly if type of job is `Contract`
  # duration for billing (i.e. pay period) must be yearly if type of job is `Full Time`
  def init_billing_detail
    [:bill_rate, :placement_commission, :agency_commission].each do |attribute|
      self[attribute]["value"] = self[attribute]["value"].to_f unless self[attribute]["value"].is_a?(Float)
    end
    return unless type_of_job
    return if (changed & %w(type_of_job duration duration_period currency suggested_pay_rate pay_period bill_rate agency_commission placement_commission msp_vms_fee_rate employee_cost)).blank?
    case type_of_job
    when 'Full Time'
      billing_amount_full_time
    when 'Contract'
      billing_amount_contract # MISS(TODO: TEST CASES NOT WRITTEN)
    end
    calculate_total if duration_period && pay_period
  end

  # calculate how much profit recruiter will get for Full Time Calculation
  def billing_amount_full_time
    self.pay_period ||= 'years'
    self.duration = 1 if duration.to_f < 1 && is_a?(Job)
    errors.add(:pay_period, 'must be yearly') unless pay_period == 'years'
    self.agency_commission = { value: 50, markup: true } if agency_commission[:value].to_f.zero?
    self.net_margin = get_value_from_unit(:suggested_pay_rate, :placement_commission)
    set_agency_payout
    set_crowdstaffing_profit
  end

  # calculate how much profit recruiter will get for Contract Calculation
  def billing_amount_contract
    self.pay_period ||= 'hours'
    errors.add(:pay_period, 'must be hourly') if self.pay_period != 'hours'
    self.employee_cost = EmployeeCost.current
    self.placement_commission = { value: 0, markup: true }
    self.agency_commission = { value: 33, markup: true } if agency_commission[:value].to_f.zero?
    return if client.nil?
    self.msp_vms_fee_rate = client.msp_vms_fee_rate if client
    return unless suggested_pay_rate['min'].to_f > 0 || client.msp_vms_fee_rate.to_f > 0
    self.net_margin = begin
                          [(total_bill_rate - contract_actual_payment), 0].max
                        rescue
                          0
                        end
    set_agency_payout
    set_crowdstaffing_profit
  end

  def contract_actual_payment_markup
    (employee_cost + msp_vms_fee_rate / 100 - 1) * 100
  end

  def calculate_total
    total_time = calculate_total_time
    case type_of_job
    when 'Full Time'
      total_time = 1 if total_time >= Job.multiple(pay_period.to_sym, :year)
      self.total_net_margin = net_margin.to_f * total_time
      self.total_value_of_contract = (
        suggested_pay_rate['min'].to_f + total_net_margin.to_f
      ) * total_time

    when 'Contract'
      contract_total(total_time)
    end
    total_profit_and_payout(total_time)
  end
end
