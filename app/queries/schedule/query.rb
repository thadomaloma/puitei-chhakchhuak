module Schedule
  # Fitting/delivery appointments are derived from Order#trial_date and
  # Order#delivery_date at read time. There is no persisted schedule/event
  # record, so a date changed on an Order is reflected here automatically.
  class Query
    TYPES = %w[fitting delivery].freeze

    def initialize(orders:, from:, to:, type: nil, staff_id: nil, search: nil)
      @from = from
      @to = to
      @type = TYPES.include?(type) ? type : nil
      @staff_id = staff_id
      @base = orders.confirmed.includes(:customer, order_items: :production_tasks)
      @base = @base.search(search) if search.present?
      @base = staff_scoped(@base) if staff_id.present?
    end

    def fitting_entries
      @fitting_entries ||= fittings? ? build_entries(@base.where(trial_date: @from..@to), :trial_date, :fitting, false) : []
    end

    def delivery_entries
      @delivery_entries ||= deliveries? ? build_entries(@base.where(delivery_date: @from..@to), :delivery_date, :delivery, false) : []
    end

    def entries
      @entries ||= (fitting_entries + delivery_entries).sort_by { |entry| [ entry.date, entry.fitting? ? 0 : 1 ] }
    end

    def grouped_by_date
      entries.group_by(&:date).sort.to_h
    end

    def overdue_entries
      @overdue_entries ||= (overdue_fitting_entries + overdue_delivery_entries).sort_by(&:date)
    end

    private

    def fittings?
      @type != "delivery"
    end

    def deliveries?
      @type != "fitting"
    end

    def overdue_fitting_entries
      return [] unless fittings?

      build_entries(@base.where.not(trial_date: nil).where("trial_date < ?", Date.current), :trial_date, :fitting, true)
    end

    def overdue_delivery_entries
      return [] unless deliveries?

      build_entries(@base.merge(Order.overdue), :delivery_date, :delivery, true)
    end

    def build_entries(relation, date_attribute, type, overdue)
      relation.map { |order| Entry.new(type: type, date: order.public_send(date_attribute), order: order, overdue: overdue) }
    end

    def staff_scoped(relation)
      relation.joins(order_items: :production_tasks).where(production_tasks: { assigned_to_id: @staff_id }).distinct
    end
  end
end
