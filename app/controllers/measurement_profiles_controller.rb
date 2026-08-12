class MeasurementProfilesController < ApplicationController
  before_action :set_customer
  before_action :set_profile, only: %i[show destroy]

  def show
    authorize @profile
    history = @profile.measurements.with_attached_photos.includes(:created_by, order_items: :order)
    @pagy, @measurements = pagy(:offset, history, limit: 12)
    previous_versions = @measurements.map { |measurement| measurement.version - 1 }.select(&:positive?)
    @previous_measurements_by_version = @profile.measurements.where(version: previous_versions).index_by(&:version)
  end

  def new
    @profile = @customer.measurement_profiles.new(
      unit: @customer.branch.shop_setting.measurement_unit,
      name: t("measurement_profiles.default_name")
    )
    authorize @profile
    @templates = MeasurementTemplate.active.alphabetical
  end

  def create
    @profile = @customer.measurement_profiles.new(profile_params)
    authorize @profile
    @templates = MeasurementTemplate.active.alphabetical

    if @profile.save
      redirect_to new_customer_measurement_profile_measurement_path(@customer, @profile), notice: t("measurement_profiles.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    authorize @profile
    @profile.update!(active: false)
    redirect_to @customer, notice: t("measurement_profiles.archived")
  end

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:customer_id])
  end

  def set_profile
    @profile = @customer.measurement_profiles.find(params[:id])
  end

  def profile_params
    params.require(:measurement_profile).permit(
      :measurement_template_id, :name, :unit, :fitting_notes, :posture_notes, :preferences
    )
  end
end
