# frozen_string_literal: true

module Admin
  # BillingTermsController
  class BillingTermsController < Admin::BaseController
    load_and_authorize_resource

    include Concerns::BillingTermsActions
    before_action :find_hiring_organization
    before_action :find_billing_term,
                  only: %I[show update destroy enable exclusive_agencies agencies]

    # List all Billing Terms
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms [GET]
    # ====Parameters
    #   client_id (For specific client)
    #   order_field (sort by fields name)
    #   order (sort order asc/desc)
    #   page (page number)
    #   per_page (records per page)
    def index
      billing_terms_index
    end

    # create a new hiring organization
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms  [POST]
    # ====Parameters
    #   billing_term[client_id]
    #   billing_term[billing_name]
    #   billing_term[type_of_job]
    #   billing_term[category_ids]
    #   billing_term[country_ids]
    #   billing_term[state_ids]
    #   billing_term[msp_available]
    #   billing_term[msp_name][name]
    #   billing_term[platform_type]
    #   billing_term[ats_platform][name]
    #   billing_term[vms_platform][name]
    #   billing_term[proprietary_platform][name]
    #   billing_term[msp_vms_fee_rate]
    #   billing_term[msp_notes]
    #   billing_term[placement_fee] {value, markup}
    #   billing_term[agency_placement_fee] {value, markup}
    #   billing_term[guarantee_period]
    #   billing_term[exclusivity_period]
    #   billing_term[billing_type] [:bill_date, markup]
    #   billing_term[bill_markup] {value, markup}
    #   billing_term[crowdstaffing_margin]
    def create
      @billing_term = @hiring_organization.billing_terms.new(billing_term_params)
      @billing_term.created_by = current_user
      if @billing_term.save
        # TODO: Notification code come.
      else
        render_errors @billing_term
      end
    end

    # Show a hiring organization's detail.
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms/ID  [GET]
    def show; end

    # Edit/Update hiring organization
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms/ID  [PUT]
    # ====Parameters
    #   billing_term[billing_name]
    #   billing_term[guarantee_period]
    #   billing_term[exclusivity_period]
    def update
      @billing_term.agency_value_old_ids = @billing_term.agencies.pluck(:id)
      if @billing_term.update_attributes(billing_term_params)
        render 'show', status: :ok
      else
        render_errors @billing_term
      end
    end

    # Destroy hiring organization
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms/ID  [DELETE]
    def destroy
      if @billing_term.destroy
        render json: { success: true }, status: :ok
      else
        render_errors @billing_term
      end
    end

    # Enable/disable clients
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms/ID1/enable  [PUT]
    # ====PARAMETERS
    #   billing_term[enable] [true, false]
    def enable
      active = params.require(:billing_term).permit([:enable])
      if @billing_term.update_attributes(active)
        render 'show'
      else
        render_errors @billing_term
      end
    end

    # list of all agencies except those in billing terms
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms/ID1/agencies  [GET]
    #  query
    def agencies
      if params[:query].present?
        search = ES::SearchAgency.new(agency_search_params, current_user)
        @agencies, @total_count = search.search_agencies
      else
        agencies = Agency.active
          .where.not(id: @billing_term.agencies.select(:id))
          .sortit(params[:order_field], params[:order])

        @pagy, @agencies = pagy(agencies, items: per_page, page: page_count)
      end
    end

    # list of agencies who have exclusive access to this billing term
    # ====URL
    #   /admin/hiring_organizations/:hiring_organization_id/billing_terms/ID1/exclusive_agencies  [GET]
    #  query
    def exclusive_agencies
      if params[:query].present?
        # Not tested from FE manually as FE is searching internally
        search = ES::SearchAgency.new(agency_search_params, current_user)
        @agencies, @total_count = search.search_agencies
      else
        agencies = @billing_term.agencies.active.sortit(params[:order_field], params[:order])
        @pagy, @agencies = pagy(agencies, items: per_page, page: page_count)
      end
    end

    private

    def find_hiring_organization
      @hiring_organization = HiringOrganization.find params[:hiring_organization_id]
      @hiring_organization.presence || send_403!
    end

    def create_msp_and_vms_platform
      btp = params[:billing_term]
      return if btp.blank?
      create_msp(btp)
      create_platform(btp)
      %i[vms_platform ats_platform msp_name proprietary_name].each { |obj| btp.delete(obj) }
    end

    def create_msp(btp)
      find_hiring_organization
      msp_name = btp.dig(:msp_name, :name)
      if @hiring_organization.msp?
        msp = MspName.find_or_create_by(name: @hiring_organization.company_relationship_name)
        btp[:msp_name_id] = msp.id
        btp[:msp_available] = true
      elsif btp[:msp_available].is_true? && msp_name.present?
        msp = MspName.find_or_create_by(name: msp_name)
        btp[:msp_name_id] = msp.id
      end
    end

    def create_platform(btp)
      vms_name = btp.dig(:vms_platform, :name)
      ats_name = btp.dig(:ats_platform, :name)
      proprietary_name = btp.dig(:proprietary_platform, :name)

      if btp[:platform_type].eql?('Applicant Tracking System') && ats_name.present?
        ats = AtsPlatform.find_or_create_by(name: ats_name)
        btp[:ats_platform_id] = ats.id
      elsif btp[:platform_type].eql?('VMS') && vms_name.present?
        vms = VmsPlatform.find_or_create_by(name: vms_name)
        btp[:vms_platform_id] = vms.id
      elsif btp[:platform_type].eql?('Proprietary System') && proprietary_name.present?
        ps = ProprietaryPlatform.find_or_create_by(name: proprietary_name)
        btp[:proprietary_platform_id] = ps.id
      end
    end

    def billing_term_params
      create_msp_and_vms_platform
      bt = [:billing_name, :crowdstaffing_margin, :msp_name_id, :msp_vms_fee_rate,
            :ats_platform_id, :vms_platform_id, :proprietary_platform_id,
            :guarantee_period, :exclusivity_period, :currency,
            :is_exclusive, :exclusive_access_time, :exclusive_access_period,
            { agency_ids: [] },
            { placement_fee: [:value, :markup] },
            { agency_placement_fee: [:value, :markup] },
            { bill_markup: [:value, :markup] }]
      only_create = [:client_id, :type_of_job, :msp_available, :platform_type,
                     :msp_notes, :billing_type, :crowdstaffing_payroll,
                     category_ids: [], country_ids: [], state_ids: []]
      bt.concat(only_create) # TODO: temp commented if params[:action].eql?('create')
      params.require(:billing_term).permit(bt)
    end

    def agency_search_params
      params[:page] = page_count
      params[:per_page] = per_page

      params.permit(
        :query,
        :order_field,
        :order,
        :page,
        :per_page,
        :my,
        :billing_term_id,
        :billing_term_all_agencies,
      )
    end
  end
end
