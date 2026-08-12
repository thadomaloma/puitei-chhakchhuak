class MeasurementsController < ApplicationController
  before_action :set_customer_and_profile, except: :index

  def index
    authorize MeasurementProfile

    base_scope = policy_scope(MeasurementProfile)
    profiles = base_scope
      .includes(:measurement_template, :measurements, customer: :branch)
      .order(updated_at: :desc, id: :desc)

    profiles = profiles.active unless params[:archived] == "1"
    profiles = profiles.where(measurement_template_id: params[:template_id]) if params[:template_id].present?
    profiles = search(profiles, params[:query])

    @measurement_templates = MeasurementTemplate
      .where(id: base_scope.select(:measurement_template_id))
      .alphabetical
    @summary = measurement_summary(base_scope)
    @pagy, @profiles = pagy(:offset, profiles, limit: 20)
  end

  def show
    @measurement = @profile.measurements.with_attached_photos.find(params[:id])
    authorize @measurement
    @previous_measurement = @profile.measurements.where("version < ?", @measurement.version).order(version: :desc).first
    @value_changes = helpers.measurement_value_changes(@measurement, @previous_measurement)
    @associated_order_items = @measurement.order_items.includes(:order)
    @history = @profile.measurements.includes(:created_by).limit(8)
  end

  def new
    copy = @profile.measurements.find_by(id: params[:copy_from_id])
    @measurement = @profile.measurements.new(
      measured_on: Date.current,
      values: copy&.values || {},
      notes: copy&.notes,
      copied_from: copy
    )
    authorize @measurement
    @source_measurement = copy
  end

  def create
    authorize @profile, :create?
    @measurement = @profile.record_measurement(measurement_params.merge(created_by: current_user))
    redirect_to customer_measurement_profile_path(@customer, @profile), notice: t("measurements.created")
  rescue ActiveRecord::RecordInvalid => error
    @measurement = error.record
    authorize @measurement
    @source_measurement = @measurement.copied_from
    render :new, status: :unprocessable_content
  end

  private

  def search(profiles, query)
    term = MeasurementProfile.sanitize_sql_like(query.to_s.strip)
    return profiles if term.blank?

    profiles.joins(:customer, :measurement_template).where(
      <<~SQL.squish,
        measurement_profiles.name ILIKE :term OR
        customers.full_name ILIKE :term OR
        customers.phone_number ILIKE :term OR
        customers.customer_code ILIKE :term OR
        measurement_templates.name ILIKE :term
      SQL
      term: "%#{term}%"
    )
  end

  def measurement_summary(base_scope)
    active_scope = base_scope.active
    measurements = policy_scope(Measurement).where(measurement_profile_id: base_scope.select(:id))

    {
      active_profiles: active_scope.count,
      measured_customers: active_scope.distinct.count(:customer_id),
      versions: measurements.count,
      updated_this_month: measurements.where(measured_on: Date.current.all_month).count
    }
  end

  def set_customer_and_profile
    @customer = policy_scope(Customer).find(params[:customer_id])
    @profile = @customer.measurement_profiles.includes(measurement_template: :measurement_fields).find(params[:measurement_profile_id])
  end

  def measurement_params
    permitted = params.require(:measurement).permit(:measured_on, :notes, :copied_from_id, photos: [], values: {})
    if permitted[:copied_from_id].present?
      permitted[:copied_from] = @profile.measurements.find(permitted.delete(:copied_from_id))
    end
    permitted
  end
end
