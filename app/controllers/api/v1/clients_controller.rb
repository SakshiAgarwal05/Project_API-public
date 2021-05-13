#TODO: TEST CASES NOT WRITTEN
class ClientsController < ApplicationController

  # List all active clients.
  # ====URL
  #   /clients [GET]
  # ====Parameters
  #   order_field (sort by fields name)
  #   order (sort order asc/desc)
  #   page (page number)
  #   per_page (records per page)
  def index
    @clients = Buyer.active.sortit(params[:order_field], params[:order], nil)
    @clients = @clients.page(page_count).per(per_page)
  end

  # Show a client's detail.
  # ====URL
  #   /admin/clients/ID  [GET]
  def show
    @client = Buyer.find(params[:id]) || send_403!
  end
end
