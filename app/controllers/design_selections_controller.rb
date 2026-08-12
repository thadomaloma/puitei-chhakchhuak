class DesignSelectionsController < ApplicationController
  before_action :set_selection, only: %i[update destroy restore]
  before_action :load_picker_data, only: %i[new create]

  def new
    @design_selection = current_shop.design_selections.new(
      customer: @selected_customer, design: @selected_design, status: :shortlisted
    )
    authorize @design_selection
  end

  def create
    prototype = current_shop.design_selections.new
    authorize prototype
    design_ids = selected_design_ids
    designs = policy_scope(Design).active.where(id: design_ids).order(:id)
    customer = policy_scope(Customer).active.find(selection_params[:customer_id])
    raise ActiveRecord::RecordNotFound unless designs.size == design_ids.size && designs.any?

    new_designs = designs.reject { |design| current_shop.design_selections.active.exists?(customer: customer, design: design) }
    if new_designs.empty?
      redirect_to customer_path(customer, tab: "gallery"), alert: t("design_selections.already_attached")
      return
    end

    created = 0
    DesignSelection.transaction do
      new_designs.each do |design|
        selection = current_shop.design_selections.active.find_or_initialize_by(customer: customer, design: design)
        next unless selection.new_record?

        selection.assign_attributes(selection_attributes.merge(selected_by: current_user))
        selection.save!
        created += 1
      end
    end
    redirect_to customer_path(customer, tab: "gallery"), notice: t("design_selections.created", count: created)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    @design_selection = prototype
    @design_selection.errors.add(:base, error.message)
    render :new, status: :unprocessable_content
  end

  def update
    authorize @design_selection
    if @design_selection.update(selection_update_params)
      redirect_to customer_path(@design_selection.customer, tab: "gallery"), notice: t("design_selections.updated")
    else
      redirect_to customer_path(@design_selection.customer, tab: "gallery"), alert: @design_selection.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @design_selection, :archive?
    customer = @design_selection.customer
    @design_selection.archive!
    redirect_to customer_path(customer, tab: "gallery"), notice: t("design_selections.archived")
  end

  def restore
    authorize @design_selection, :restore?
    customer = @design_selection.customer
    @design_selection.restore!
    redirect_to customer_path(customer, tab: "gallery", selection_status: "archived"), notice: t("design_selections.restored")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    redirect_to customer_path(@design_selection.customer, tab: "gallery", selection_status: "archived"), alert: error.message
  end

  private

  def set_selection
    @design_selection = policy_scope(DesignSelection).find(params[:id])
  end

  def load_picker_data
    @selected_customer = policy_scope(Customer).active.find_by(id: params[:customer_id] || params.dig(:design_selection, :customer_id))
    @selected_design = policy_scope(Design).active.find_by(id: params[:design_id] || params.dig(:design_selection, :design_id))
    @customers = policy_scope(Customer).active.search(params[:query]).order(:full_name).limit(50).to_a
    @customers.unshift(@selected_customer) if @selected_customer && @customers.exclude?(@selected_customer)
    @designs = policy_scope(Design).active.search(params[:design_query]).recent_first.with_attached_images.limit(48).to_a
    @designs.unshift(@selected_design) if @selected_design && @designs.exclude?(@selected_design)
    @selected_design_ids = if @selected_customer
      policy_scope(DesignSelection).active.where(customer: @selected_customer).pluck(:design_id).to_set
    else
      Set.new
    end
  end

  def selected_design_ids
    ids = Array(params[:design_ids]).presence || [ selection_params[:design_id] ]
    ids.filter_map { |id| Integer(id, exception: false) }.uniq
  end

  def selection_params
    permitted = params.require(:design_selection).permit(:customer_id, :design_id, :status, :customer_note, :internal_note)
    permitted.delete(:internal_note) unless current_user.owner? || current_user.manager?
    permitted
  end

  def selection_attributes
    selection_params.except(:customer_id, :design_id).merge(selected_at: Time.current)
  end

  def selection_update_params
    permitted = params.require(:design_selection).permit(:status, :customer_note, :internal_note)
    permitted.delete(:internal_note) unless current_user.owner? || current_user.manager?
    permitted
  end
end
